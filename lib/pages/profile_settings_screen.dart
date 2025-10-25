import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/theme_provider.dart';
import '../global/toast.dart';
import 'login_screen.dart';
import 'user_service.dart'; // Updated path

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  String? _selectedGender;
  List<String> _selectedDietaryPreferences = [];
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  String? _profileImagePath;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final FlutterTts _tts = FlutterTts();
  final UserService _userService = UserService(); // Add UserService
  
  final List<String> _dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Keto',
    'Paleo',
    'Halal',
    'Kosher',
  ];
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _languageOptions = ['English', 'Spanish', 'French'];
  final Map<String, String> _languageCodes = {
    'English': 'en-US',
    'Spanish': 'es-ES',
    'French': 'fr-FR',
  };

  @override
  void initState() {
    super.initState();
    _loadProfileAndSettings();
  }

  Future<void> _loadProfileAndSettings() async {
    setState(() => _isLoading = true);
    
    // First try to load from Firestore
    final firestoreData = await _userService.loadUserPreferences();
    
    if (firestoreData != null) {
  setState(() {
    _nameController.text = firestoreData['name'] ?? '';
    _ageController.text = firestoreData['age'] ?? '';

    // ✅ Gender fix: only accept valid options
    final genderValue = firestoreData['gender'];
    if (genderValue != null && _genderOptions.contains(genderValue)) {
      _selectedGender = genderValue;
    } else {
      _selectedGender = null;
    }

    _selectedDietaryPreferences =
        List<String>.from(firestoreData['dietaryPreferences'] ?? []);
    _ingredientsController.text =
        (firestoreData['availableIngredients'] as List?)?.join(', ') ?? '';
    _allergiesController.text =
        (firestoreData['allergies'] as List?)?.join(', ') ?? '';
    _profileImagePath = firestoreData['profileImagePath'];

    // ✅ Language fix (for Voice Assistant)
    final langValue = firestoreData['language'];
    if (langValue != null && _languageOptions.contains(langValue)) {
      _selectedLanguage = langValue;
    } else {
      _selectedLanguage = 'English';
    }
  });
}

    
    // Also load local SharedPreferences for settings (theme, language, etc.)
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _isLoading = false;
    });
    
    await _tts.setLanguage(_languageCodes[_selectedLanguage] ?? 'en-US');
  }

  Future<void> _saveProfileAndSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final ingredients = _ingredientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final allergies = _allergiesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    try {
      // Save profile data to Firestore
      await _userService.saveUserPreferences(
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _selectedGender ?? '',
        dietaryPreferences: _selectedDietaryPreferences,
        availableIngredients: ingredients,
        allergies: allergies,
        profileImagePath: _profileImagePath,
      );

      // Save app settings locally (these don't need to sync)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setBool('notificationsEnabled', _notificationsEnabled);
      await prefs.setString('language', _selectedLanguage);

      await _tts.setLanguage(_languageCodes[_selectedLanguage] ?? 'en-US');
      
      showToast(message: 'Profile and settings saved!');
    } catch (e) {
      showToast(message: 'Error saving profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    final themeProvider = Get.find<ThemeProvider>();
    themeProvider.toggleTheme(value);
    await _saveProfileAndSettings();
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _saveProfileAndSettings();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImagePath = pickedFile.path;
      });
      await _saveProfileAndSettings();
    }
  }

  Future<String> _loadTermsFromFile() async {
    return await rootBundle.loadString('lib/assets/terms_and_conditions.txt');
  }

  Future<void> _showTermsDialog() async {
    final termsText = await _loadTermsFromFile();
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Terms & Conditions"),
            content: SizedBox(
              height: 300,
              child: SingleChildScrollView(child: Text(termsText)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  Future<void> _clearData() async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Clear Data"),
            content: const Text(
              "Are you sure you want to clear all data? This cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Clear", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        // Clear Firestore data
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await _userService.clearUserData();
        }
        
        // Clear local data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        showToast(message: "All data cleared.");
      } catch (e) {
        showToast(message: "Error clearing data: $e");
      } finally {
        setState(() => _isLoading = false);
      }
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() => _isLoading = false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Delete Account"),
            content: const Text(
              "Are you sure you want to delete your account? This will remove all your data and cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Delete Firestore data
          await _userService.clearUserData();
          
          // Delete Firebase Auth account
          await user.delete();
          
          // Clear local data
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          
          showToast(message: "Account deleted successfully.");
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        showToast(message: e.message ?? "Failed to delete account.");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            _profileImagePath != null
                                ? FileImage(File(_profileImagePath!))
                                : const AssetImage('lib/images/genie.png')
                                    as ImageProvider,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLength: 50,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        if (value.length > 50) {
                          return 'Name must be 50 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _ageController,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Age is required';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age <= 0 || age > 150) {
                          return 'Enter a valid age (1-150)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          _genderOptions.map((gender) {
                            return DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            );
                          }).toList(),
                      onChanged:
                          (value) => setState(() => _selectedGender = value),
                    ),
                    const SizedBox(height: 10),
                    MultiSelectDialogField(
                      items:
                          _dietaryOptions
                              .map((option) => MultiSelectItem(option, option))
                              .toList(),
                      initialValue: _selectedDietaryPreferences,
                      title: const Text('Dietary Preferences'),
                      buttonText: const Text('Dietary Preferences'),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onConfirm: (values) {
                        setState(
                          () =>
                              _selectedDietaryPreferences =
                                  values.cast<String>(),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _allergiesController,
                      decoration: InputDecoration(
                        labelText: 'Allergies (comma-separated)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await _saveProfileAndSettings();
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _showVoiceAssistantDialog() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('AI Voice Assistant'),
            content: ListTile(
              title: const Text('Language'),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                items:
                    _languageOptions.map((value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLanguage = value!);
                  _saveProfileAndSettings();
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _showPrivacyDialog() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Privacy & Security'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Terms & Conditions'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTermsDialog();
                    },
                  ),
                  ListTile(
                    title: const Text('Clear All Data'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _clearData();
                    },
                  ),
                  ListTile(
                    title: const Text('Delete Account'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteAccount();
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _showAboutDialog() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('About & App Info'),
            content: const Text(
              'Cook v1.0\nPowered by AI Cooking Intelligence',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _showHelpDialog() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Help & Support'),
            content: const Text(
              'Contact support@cookgenie.com for assistance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _ingredientsController.dispose();
    _allergiesController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        _nameController.text.isEmpty ? 'John Doe' : _nameController.text;
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'john@example.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          _profileImagePath != null
                              ? FileImage(File(_profileImagePath!))
                              : const AssetImage('lib/images/genie.png')
                                  as ImageProvider,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(email),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _showEditProfileDialog,
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.mic),
                    title: const Text('AI Voice Assistant'),
                    onTap: _showVoiceAssistantDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Theme Mode'),
                    trailing: Switch(
                      value: _isDarkMode,
                      onChanged: _toggleTheme,
                      activeColor: Colors.green,
                      activeTrackColor: Colors.green.withOpacity(0.5),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Privacy & Security'),
                    onTap: _showPrivacyDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About & App Info'),
                    onTap: _showAboutDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    onTap: _showHelpDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notifications'),
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeColor: Colors.green,
                      activeTrackColor: Colors.green.withOpacity(0.5),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: _logout,
                  ),
                ],
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Cook v1.0 - Powered by AI Cooking Intelligence',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
    );
  }
}
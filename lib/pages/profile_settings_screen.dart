import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../theme/theme_provider.dart';
import '../global/toast.dart';
import 'login_screen.dart';
import 'user_service.dart';

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
  final UserService _userService = UserService();

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
  final List<String> _languageOptions = ['English'];
  final Map<String, String> _languageCodes = {'English': 'en-US'};

  // Theme constants (match your other screens)
  static const Color _bgTop = Color(0xFF0B0615);
  static const Color _bgMid = Color(0xFF130A26);
  static const Color _bgBottom = Color(0xFF1C0B33);
  static const Color _accent = Color(0xFFB57BFF);
  static const Color _accent2 = Color(0xFF7E3FF2);
  static const Color _cardBase = Color(0xFF120A22);

  @override
  void initState() {
    super.initState();
    _loadProfileAndSettings();
  }

  Future<void> _loadProfileAndSettings() async {
    setState(() => _isLoading = true);

    // Firestore first
    final firestoreData = await _userService.loadUserPreferences();

    if (firestoreData != null && mounted) {
      setState(() {
        _nameController.text = (firestoreData['name'] ?? '').toString();
        _ageController.text = (firestoreData['age'] ?? '').toString();

        final genderValue = firestoreData['gender'];
        if (genderValue != null && _genderOptions.contains(genderValue)) {
          _selectedGender = genderValue;
        } else {
          _selectedGender = null;
        }

        _selectedDietaryPreferences = List<String>.from(
          firestoreData['dietaryPreferences'] ?? [],
        );

        _ingredientsController.text =
            (firestoreData['availableIngredients'] as List?)?.join(', ') ?? '';

        _allergiesController.text =
            (firestoreData['allergies'] as List?)?.join(', ') ?? '';

        _profileImagePath = firestoreData['profileImagePath'];

        final langValue = firestoreData['language'];
        if (langValue != null && _languageOptions.contains(langValue)) {
          _selectedLanguage = langValue;
        } else {
          _selectedLanguage = 'English';
        }
      });
    }

    // Local prefs for app settings
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _selectedLanguage = prefs.getString('language') ?? _selectedLanguage;
      _isLoading = false;
    });

    await _tts.setLanguage(_languageCodes[_selectedLanguage] ?? 'en-US');
  }

  Future<void> _saveProfileAndSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final ingredients =
        _ingredientsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

    final allergies =
        _allergiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

    try {
      await _userService.saveUserPreferences(
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _selectedGender ?? '',
        dietaryPreferences: _selectedDietaryPreferences,
        availableIngredients: ingredients,
        allergies: allergies,
        profileImagePath: _profileImagePath,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setBool('notificationsEnabled', _notificationsEnabled);
      await prefs.setString('language', _selectedLanguage);

      await _tts.setLanguage(_languageCodes[_selectedLanguage] ?? 'en-US');

      showToast(message: 'Saved!');
    } catch (e) {
      showToast(message: 'Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      setState(() => _profileImagePath = pickedFile.path);
      await _saveProfileAndSettings();
    }
  }

  Future<String> _loadTermsFromFile() async {
    return rootBundle.loadString('lib/assets/terms_and_conditions.txt');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2A1246),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---------- DIALOGS (THEMED) ----------

  Future<void> _showTermsDialog() async {
    final termsText = await _loadTermsFromFile();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder:
          (_) => _ThemedDialog(
            title: "Terms & Conditions",
            child: SizedBox(
              height: 320,
              child: SingleChildScrollView(
                child: Text(
                  termsText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    height: 1.3,
                  ),
                ),
              ),
            ),
            actions: [
              _dialogButton(text: "Close", onTap: () => Navigator.pop(context)),
            ],
          ),
    );
  }

  Future<void> _showVoiceAssistantDialog() async {
    await showDialog(
      context: context,
      builder:
          (_) => _ThemedDialog(
            title: "AI Voice Assistant",
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Language",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                    color: Colors.white.withOpacity(0.06),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: _cardBase,
                    underline: const SizedBox.shrink(),
                    iconEnabledColor: Colors.white.withOpacity(0.8),
                    style: const TextStyle(color: Colors.white),
                    items:
                        _languageOptions
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedLanguage = value);
                      await _saveProfileAndSettings();
                      if (mounted) _snack("Language set to $value");
                    },
                  ),
                ),
              ],
            ),
            actions: [
              _dialogButton(text: "Close", onTap: () => Navigator.pop(context)),
            ],
          ),
    );
  }

  Future<void> _showPrivacyDialog() async {
    await showDialog(
      context: context,
      builder:
          (_) => _ThemedDialog(
            title: "Privacy & Security",
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionTile(
                  icon: Icons.description_rounded,
                  title: "Terms & Conditions",
                  onTap: () {
                    Navigator.pop(context);
                    _showTermsDialog();
                  },
                ),
                const SizedBox(height: 10),
                _actionTile(
                  icon: Icons.delete_sweep_rounded,
                  title: "Clear All Data",
                  destructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _clearData();
                  },
                ),
                const SizedBox(height: 10),
                _actionTile(
                  icon: Icons.person_off_rounded,
                  title: "Delete Account",
                  destructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteAccount();
                  },
                ),
              ],
            ),
            actions: [
              _dialogButton(text: "Close", onTap: () => Navigator.pop(context)),
            ],
          ),
    );
  }

  Future<void> _showAboutDialog() async {
    await showDialog(
      context: context,
      builder:
          (_) => _ThemedDialog(
            title: "About",
            child: Text(
              "CookGenie v1.0\nPowered by AI Cooking Intelligence",
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                height: 1.3,
              ),
            ),
            actions: [
              _dialogButton(text: "Close", onTap: () => Navigator.pop(context)),
            ],
          ),
    );
  }

  Future<void> _showHelpDialog() async {
    await showDialog(
      context: context,
      builder:
          (_) => _ThemedDialog(
            title: "Help & Support",
            child: Text(
              "Contact support@cookgenie.com for assistance.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                height: 1.3,
              ),
            ),
            actions: [
              _dialogButton(text: "Close", onTap: () => Navigator.pop(context)),
            ],
          ),
    );
  }

  // ---------- ACTIONS ----------

  Future<void> _clearData() async {
    final confirm = await _confirmDialog(
      title: "Clear Data",
      message:
          "Are you sure you want to clear all data? This cannot be undone.",
      confirmText: "Clear",
      destructive: true,
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _userService.clearUserData();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      showToast(message: "All data cleared.");
    } catch (e) {
      showToast(message: "Error clearing data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    final confirm = await _confirmDialog(
      title: "Logout",
      message: "Do you want to logout?",
      confirmText: "Logout",
      destructive: true,
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await _confirmDialog(
      title: "Delete Account",
      message:
          "Are you sure you want to delete your account?\nThis removes all your data and cannot be undone.",
      confirmText: "Delete",
      destructive: true,
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _userService.clearUserData();
        await user.delete();

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        showToast(message: "Account deleted.");
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      showToast(message: e.message ?? "Failed to delete account.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => _ThemedDialog(
            title: title,
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                height: 1.3,
              ),
            ),
            actions: [
              _dialogButton(
                text: "Cancel",
                onTap: () => Navigator.pop(context, false),
              ),
              _dialogButton(
                text: confirmText,
                destructive: destructive,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );
  }

  // ---------- EDIT PROFILE (THEMED) ----------

  Future<void> _showEditProfileDialog() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => _ThemedDialog(
            title: "Edit Profile",
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            backgroundImage:
                                _profileImagePath != null
                                    ? FileImage(File(_profileImagePath!))
                                    : const AssetImage('lib/images/genie.png')
                                        as ImageProvider,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _field(
                      controller: _nameController,
                      label: "Name",
                      maxLength: 50,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Name is required';
                        if (value.length > 50)
                          return 'Name must be 50 characters or less';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    _field(
                      controller: _ageController,
                      label: "Age",
                      maxLength: 3,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Age is required';
                        final age = int.tryParse(value);
                        if (age == null || age <= 0 || age > 150)
                          return 'Enter a valid age (1-150)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      dropdownColor: _cardBase,
                      decoration: _inputDecoration("Gender"),
                      style: const TextStyle(color: Colors.white),
                      items:
                          _genderOptions
                              .map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(() => _selectedGender = value),
                    ),
                    const SizedBox(height: 10),

                    MultiSelectDialogField(
                      items:
                          _dietaryOptions
                              .map((o) => MultiSelectItem(o, o))
                              .toList(),
                      initialValue: _selectedDietaryPreferences,
                      title: const Text('Dietary Preferences'),
                      buttonText: Text(
                        'Dietary Preferences',
                        style: TextStyle(color: Colors.white.withOpacity(0.78)),
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withOpacity(0.06),
                      ),
                      selectedColor: _accent,
                      backgroundColor: _cardBase,
                      itemsTextStyle: const TextStyle(color: Colors.white),
                      selectedItemsTextStyle: const TextStyle(
                        color: Colors.white,
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

                    _field(
                      controller: _allergiesController,
                      label: "Allergies (comma-separated)",
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              _dialogButton(text: "Cancel", onTap: () => Navigator.pop(ctx)),
              _dialogButton(
                text: "Save",
                primary: true,
                onTap: () async {
                  if (_formKey.currentState!.validate()) {
                    await _saveProfileAndSettings();
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  }
                },
              ),
            ],
          ),
    );
  }

  // ---------- WIDGET HELPERS ----------

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 200,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      cursorColor: _accent,
      decoration: _inputDecoration(label),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              _accent2.withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    destructive
                        ? const Color(0xFFE74C3C).withOpacity(0.18)
                        : _accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                icon,
                color: destructive ? const Color(0xFFE74C3C) : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color:
                      destructive
                          ? const Color(0xFFFFB4B4)
                          : Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogButton({
    required String text,
    required VoidCallback onTap,
    bool primary = false,
    bool destructive = false,
  }) {
    final Color bg =
        destructive
            ? const Color(0xFFE74C3C).withOpacity(0.18)
            : primary
            ? _accent.withOpacity(0.22)
            : Colors.white.withOpacity(0.06);

    final Color fg =
        destructive
            ? const Color(0xFFFFB4B4)
            : primary
            ? _accent
            : Colors.white.withOpacity(0.85);

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  // ---------- BG ----------

  Widget _bgGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgMid, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _bgStars() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 110,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white.withOpacity(0.06),
              size: 28,
            ),
          ),
          Positioned(
            right: 18,
            top: 160,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white.withOpacity(0.05),
              size: 34,
            ),
          ),
          Positioned(
            right: 60,
            top: 380,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white.withOpacity(0.05),
              size: 26,
            ),
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
    final name =
        _nameController.text.isEmpty ? 'John Doe' : _nameController.text;
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'john@example.com';

    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF120A22),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _bgGradient(),
          _bgStars(),
          SafeArea(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      children: [
                        // Profile header card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.06),
                                _accent2.withOpacity(0.14),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                backgroundImage:
                                    _profileImagePath != null
                                        ? FileImage(File(_profileImagePath!))
                                        : const AssetImage(
                                              'lib/images/genie.png',
                                            )
                                            as ImageProvider,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.62),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _showEditProfileDialog,
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: 'Edit Profile',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Settings section
                        _sectionTitle("Preferences"),
                        const SizedBox(height: 10),

                        _actionTile(
                          icon: Icons.mic_rounded,
                          title: 'AI Voice Assistant',
                          onTap: _showVoiceAssistantDialog,
                        ),
                        // const SizedBox(height: 10),

                        // _switchTile(
                        //   icon: Icons.palette_rounded,
                        //   title: "Theme Mode",
                        //   subtitle: _isDarkMode ? "Dark" : "Light",
                        //   value: _isDarkMode,
                        //   onChanged: _toggleTheme,
                        // ),
                        const SizedBox(height: 10),

                        _switchTile(
                          icon: Icons.notifications_rounded,
                          title: "Notifications",
                          subtitle:
                              _notificationsEnabled ? "Enabled" : "Disabled",
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                        ),

                        const SizedBox(height: 18),
                        _sectionTitle("Security"),
                        const SizedBox(height: 10),

                        _actionTile(
                          icon: Icons.security_rounded,
                          title: 'Privacy & Security',
                          onTap: _showPrivacyDialog,
                        ),
                        const SizedBox(height: 10),

                        _actionTile(
                          icon: Icons.info_rounded,
                          title: 'About & App Info',
                          onTap: _showAboutDialog,
                        ),
                        const SizedBox(height: 10),

                        _actionTile(
                          icon: Icons.help_rounded,
                          title: 'Help & Support',
                          onTap: _showHelpDialog,
                        ),

                        const SizedBox(height: 18),
                        _sectionTitle("Account"),
                        const SizedBox(height: 10),

                        _actionTile(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          destructive: true,
                          onTap: _logout,
                        ),

                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'CookGenie v1.0 • Powered by AI',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.88),
        fontWeight: FontWeight.w900,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.06), _accent2.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) => onChanged(v),
            activeColor: _accent,
            activeTrackColor: _accent.withOpacity(0.35),
            inactiveThumbColor: Colors.white.withOpacity(0.55),
            inactiveTrackColor: Colors.white.withOpacity(0.12),
          ),
        ],
      ),
    );
  }
}

// ---------- THEMED DIALOG WRAPPER ----------
class _ThemedDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const _ThemedDialog({
    required this.title,
    required this.child,
    required this.actions,
  });

  static const Color _accent = Color(0xFFB57BFF);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF120A22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: child,
      actions: actions,
    );
  }
}

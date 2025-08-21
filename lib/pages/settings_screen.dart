import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _notificationsEnabled = false;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _selectedLanguage = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setString('language', _selectedLanguage);
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    await _saveSettings();
    final themeProvider =
        Get.isRegistered<ThemeProvider>()
            ? Get.find<ThemeProvider>()
            : Get.put(ThemeProvider());
    themeProvider.toggleTheme(value);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _saveSettings();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showTermsDialog() async {
    const termsText =
        "Terms & Conditions: [Placeholder text for terms and conditions]";
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
              "Are you sure you want to clear all app data? This cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      setState(() {
        _isDarkMode = false;
        _notificationsEnabled = true;
        _selectedLanguage = 'English';
      });
      final themeProvider = Get.find<ThemeProvider>();
      themeProvider.toggleTheme(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All data cleared")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode ? Colors.black : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.grey[200],
        // light appbar fordark mode
        foregroundColor: _isDarkMode ? Colors.white : Colors.black,
      ),
      backgroundColor: backgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text('Dark Mode', style: TextStyle(color: textColor)),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.5),
          ),
          SwitchListTile(
            title: Text('Notifications', style: TextStyle(color: textColor)),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.5),
          ),
          ListTile(
            title: Text('Language', style: TextStyle(color: textColor)),
            trailing: DropdownButton<String>(
              value: _selectedLanguage,
              items:
                  ['English', 'Spanish', 'French'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: textColor)),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => _selectedLanguage = value!);
                _saveSettings();
              },
              dropdownColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text('Edit Profile', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(
              'Terms & Conditions',
              style: TextStyle(color: textColor),
            ),
            onTap: _showTermsDialog,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text('Clear All Data', style: TextStyle(color: textColor)),
            onTap: _clearData,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text('Logout', style: TextStyle(color: textColor)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

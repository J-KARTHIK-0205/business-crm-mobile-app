import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final businessNameController = TextEditingController();
  final businessAddressController = TextEditingController();

  bool notificationsEnabled = true;
  bool emailNotifications = true;
  bool darkModeEnabled = false;

  bool isLoading = true;
  bool isSaving = false;
  bool loggingOut = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> get userProfileRef {
    final user = currentUser;

    if (user == null) {
      throw Exception('No logged-in user found.');
    }

    return firestore.collection('users').doc(user.uid);
  }

  DocumentReference<Map<String, dynamic>> get businessRef =>
      firestore.collection('app_settings').doc('business');

  DocumentReference<Map<String, dynamic>> get preferencesRef =>
      firestore.collection('app_settings').doc('preferences');

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    businessNameController.dispose();
    businessAddressController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // LOAD SETTINGS
  // --------------------------------------------------

  Future<void> loadSettings() async {
    try {
      final user = currentUser;

      if (user == null) {
        throw Exception('Please log in again.');
      }

      final results = await Future.wait([
        userProfileRef.get(),
        businessRef.get(),
        preferencesRef.get(),
      ]);

      final profile = results[0].data() ?? {};
      final business = results[1].data() ?? {};
      final preferences = results[2].data() ?? {};

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      setState(() {
        nameController.text =
            refreshedUser?.displayName ??
            profile['name'] ??
            '';

        emailController.text =
            refreshedUser?.email ??
            profile['email'] ??
            '';

        phoneController.text = profile['phone'] ?? '';

        businessNameController.text =
            business['businessName'] ?? '';

        businessAddressController.text =
            business['businessAddress'] ?? '';

        notificationsEnabled =
            preferences['notificationsEnabled'] ?? true;

        emailNotifications =
            preferences['emailNotifications'] ?? true;

        final savedDarkMode = preferences['darkModeEnabled'];

        darkModeEnabled = savedDarkMode is bool
            ? savedDarkMode
            : preferences['theme'] == 'Dark';

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: $e'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // SAVE SETTINGS
  // --------------------------------------------------

  Future<void> saveSettings() async {
    if (isSaving) return;

    final user = currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final updatedName = nameController.text.trim();

      if (updatedName.isNotEmpty &&
          updatedName != (user.displayName ?? '')) {
        await user.updateDisplayName(updatedName);
        await user.reload();
      }

      await Future.wait([
        userProfileRef.set({
          'uid': user.uid,
          'name': updatedName,
          'email': user.email,
          'phone': phoneController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),

        businessRef.set({
          'businessName': businessNameController.text.trim(),
          'businessAddress': businessAddressController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),

        preferencesRef.set({
          'notificationsEnabled': notificationsEnabled,
          'emailNotifications': emailNotifications,
          'darkModeEnabled': darkModeEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------

  Future<void> logout() async {
    if (loggingOut) return;

    setState(() {
      loggingOut = true;
    });

    try {
      await AuthService().logout();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loggingOut = false;
        });
      }
    }
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      await logout();
    }
  }

  // --------------------------------------------------
  // REUSABLE WIDGETS
  // --------------------------------------------------

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 12,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget inputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline)
              : null,
        ),
      ),
    );
  }

  Widget settingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  // --------------------------------------------------
  // DARK MODE UPDATE
  // --------------------------------------------------

  Future<void> updateDarkMode(bool value) async {
    final previousValue = darkModeEnabled;

    setState(() {
      darkModeEnabled = value;
    });

    try {
      await preferencesRef.set({
        'darkModeEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        darkModeEnabled = previousValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update theme: $e'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // SETTINGS SCREEN UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          // PROFILE INFORMATION

          sectionTitle('Profile Information'),

          inputField(
            label: 'Full Name',
            controller: nameController,
          ),

          inputField(
            label: 'Email Address',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
          ),

          inputField(
            label: 'Phone Number',
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),

          // BUSINESS INFORMATION

          sectionTitle('Business Information'),

          inputField(
            label: 'Business Name',
            controller: businessNameController,
          ),

          inputField(
            label: 'Business Address',
            controller: businessAddressController,
          ),

          // PREFERENCES

          sectionTitle('Preferences'),

          settingSwitch(
            title: 'Push Notifications',
            subtitle: 'Receive app notifications',
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() {
                notificationsEnabled = value;
              });
            },
          ),

          settingSwitch(
            title: 'Email Notifications',
            subtitle: 'Receive updates through email',
            value: emailNotifications,
            onChanged: (value) {
              setState(() {
                emailNotifications = value;
              });
            },
          ),

          settingSwitch(
            title: 'Dark Mode',
            subtitle: 'Enable dark theme',
            value: darkModeEnabled,
            onChanged: updateDarkMode,
          ),

          const SizedBox(height: 24),

          // SAVE BUTTON

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveSettings,
              icon: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                isSaving ? 'Saving...' : 'Save Settings',
              ),
            ),
          ),

          // ACCOUNT SETTINGS

          sectionTitle('Account Settings'),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              title: const Text('Logout'),
              subtitle: const Text(
                'Sign out from your account',
              ),
              trailing: loggingOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_ios,
                    ),
              onTap: loggingOut ? null : confirmLogout,
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
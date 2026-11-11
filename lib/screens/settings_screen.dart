
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
  final firestore = FirebaseFirestore.instance;

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

  static const green = Color(0xFF00C853);
  static const muted = Color(0xFF9AA69D);
  static const card = Color(0xFF121A15);

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

      final profile = results[0].data() ?? <String, dynamic>{};
      final business = results[1].data() ?? <String, dynamic>{};
      final preferences = results[2].data() ?? <String, dynamic>{};

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      setState(() {
        nameController.text =
            refreshedUser?.displayName ?? profile['name']?.toString() ?? '';

        emailController.text =
            refreshedUser?.email ?? profile['email']?.toString() ?? '';

        phoneController.text = profile['phone']?.toString() ?? '';

        businessNameController.text =
            business['businessName']?.toString() ?? '';

        businessAddressController.text =
            business['businessAddress']?.toString() ?? '';

        notificationsEnabled =
            preferences['notificationsEnabled'] is bool
                ? preferences['notificationsEnabled'] as bool
                : true;

        emailNotifications =
            preferences['emailNotifications'] is bool
                ? preferences['emailNotifications'] as bool
                : true;

        final savedDarkMode = preferences['darkModeEnabled'];

        darkModeEnabled = savedDarkMode is bool
            ? savedDarkMode
            : preferences['theme'] == 'Dark';

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $error')),
      );
    }
  }

  Future<void> saveSettings() async {
    if (isSaving) return;

    final user = currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final updatedName = nameController.text.trim();

      if (updatedName.isNotEmpty &&
          updatedName != (user.displayName ?? '')) {
        await user.updateDisplayName(updatedName);
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
        const SnackBar(content: Text('Settings saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $error')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> updateDarkMode(bool value) async {
    final previous = darkModeEnabled;

    setState(() => darkModeEnabled = value);

    try {
      await preferencesRef.set({
        'darkModeEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;

      setState(() => darkModeEnabled = previous);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update theme: $error')),
      );
    }
  }

  Future<void> logout() async {
    if (loggingOut) return;

    setState(() => loggingOut = true);

    try {
      await AuthService().logout();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $error')),
      );
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  Future<void> confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await logout();
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 23, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: muted),
          prefixIcon: Icon(icon, color: green),
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline, color: muted)
              : null,
          filled: true,
          fillColor: const Color(0xFF1A241D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: green,
        secondary: Icon(icon, color: green),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage your profile, workspace and preferences.',
            style: TextStyle(color: muted, fontSize: 13),
          ),

          _sectionTitle(
            'Profile Information',
            'Your personal account details',
          ),
          _input(
            label: 'Full Name',
            controller: nameController,
            icon: Icons.person_outline,
          ),
          _input(
            label: 'Email Address',
            controller: emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
          ),
          _input(
            label: 'Phone Number',
            controller: phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          _sectionTitle(
            'Business Information',
            'Details about your workspace',
          ),
          _input(
            label: 'Business Name',
            controller: businessNameController,
            icon: Icons.business_outlined,
          ),
          _input(
            label: 'Business Address',
            controller: businessAddressController,
            icon: Icons.location_on_outlined,
          ),

          _sectionTitle(
            'Preferences',
            'Customize your CRM experience',
          ),
          _switchCard(
            title: 'Push Notifications',
            subtitle: 'Receive app notifications',
            icon: Icons.notifications_active_outlined,
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
            },
          ),
          _switchCard(
            title: 'Email Notifications',
            subtitle: 'Receive updates through email',
            icon: Icons.mark_email_unread_outlined,
            value: emailNotifications,
            onChanged: (value) {
              setState(() => emailNotifications = value);
            },
          ),
          _switchCard(
            title: 'Dark Mode',
            subtitle: 'Use the dark CRM appearance',
            icon: Icons.dark_mode_outlined,
            value: darkModeEnabled,
            onChanged: updateDarkMode,
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving ? null : saveSettings,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Saving...' : 'Save Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),

          _sectionTitle(
            'Account',
            'Manage your current session',
          ),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Sign out from your account',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: loggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: green,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_ios,
                      color: muted,
                      size: 16,
                    ),
              onTap: loggingOut ? null : confirmLogout,
            ),
          ),
        ],
      ),
    );
  }
}

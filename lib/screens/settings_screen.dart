
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String userName = '';
  String email = '';
  String phone = '';

  String businessName = 'My Business';
  String businessEmail = '';

  bool emailNotifications = true;
  bool taskReminders = true;
  bool leadNotifications = false;

  String selectedTheme = 'Light';

  bool isLoading = true;

  String get uid => auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get profileRef =>
      firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('details');

  DocumentReference<Map<String, dynamic>> get businessRef =>
      firestore
          .collection('users')
          .doc(uid)
          .collection('business')
          .doc('details');

  DocumentReference<Map<String, dynamic>> get preferencesRef =>
      firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences');

  bool get isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get pageBackground =>
      isDark ? const Color(0xFF080C09) : const Color(0xFFF5F7FA);

  Color get cardBackground =>
      isDark ? const Color(0xFF121A15) : Colors.white;

  Color get primaryText =>
      isDark ? Colors.white : const Color(0xFF17211B);

  Color get secondaryText =>
      isDark ? const Color(0xFF9AA69D) : const Color(0xFF65736A);

  Color get borderColor =>
      isDark ? Colors.white12 : const Color(0xFFE1E8E3);

  Color get accentColor =>
      isDark ? const Color(0xFF69F0AE) : const Color(0xFF00A843);

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  // LOAD SETTINGS FOR THE CURRENTLY SIGNED-IN USER
  Future<void> loadSettings() async {
    try {
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      final results = await Future.wait([
        profileRef.get(),
        businessRef.get(),
        preferencesRef.get(),
      ]);

      final profileData =
          results[0].data() ?? <String, dynamic>{};

      final businessData =
          results[1].data() ?? <String, dynamic>{};

      final preferenceData =
          results[2].data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        final savedName = profileData['name'] as String?;

        if (savedName != null && savedName.trim().isNotEmpty) {
          userName = savedName.trim();
        } else if (currentUser.displayName != null &&
            currentUser.displayName!.trim().isNotEmpty) {
          userName = currentUser.displayName!.trim();
        } else {
          userName = currentUser.email?.split('@').first ?? 'User';
        }

        // Always display the currently authenticated email.
        email = currentUser.email ?? '';

        phone = profileData['phone'] as String? ?? '';

        businessName =
            businessData['name'] as String? ?? 'My Business';

        businessEmail =
            businessData['email'] as String? ?? '';

        emailNotifications =
            preferenceData['emailNotifications'] as bool? ?? true;

        taskReminders =
            preferenceData['taskReminders'] as bool? ?? true;

        leadNotifications =
            preferenceData['leadNotifications'] as bool? ?? false;

        final savedDarkMode =
            preferenceData['darkModeEnabled'];

        selectedTheme = savedDarkMode is bool
            ? (savedDarkMode ? 'Dark' : 'Light')
            : (preferenceData['theme'] as String? ?? 'Light');

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Unable to load settings: $e');
    }
  }

  // DISPLAY MESSAGE
  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // SAVE PROFILE FOR CURRENT USER
  Future<void> saveProfile(
    String name,
    String emailAddress,
    String phoneNumber,
  ) async {
    try {
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        showMessage('Please sign in again.');
        return;
      }

      await profileRef.set({
        'name': name,
        'email': currentUser.email ?? emailAddress,
        'phone': phoneNumber,
        'uid': currentUser.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await currentUser.updateDisplayName(name);

      if (!mounted) return;

      setState(() {
        userName = name;
        email = currentUser.email ?? emailAddress;
        phone = phoneNumber;
      });

      showMessage('Profile updated successfully.');
    } catch (e) {
      showMessage('Unable to save profile: $e');
    }
  }

  // SAVE BUSINESS INFORMATION FOR CURRENT USER
  Future<void> saveBusiness(
    String name,
    String emailAddress,
  ) async {
    try {
      await businessRef.set({
        'name': name,
        'email': emailAddress,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        businessName = name;
        businessEmail = emailAddress;
      });

      showMessage('Business information saved.');
    } catch (e) {
      showMessage('Unable to save business information: $e');
    }
  }

  // SAVE NOTIFICATION AND THEME PREFERENCES
  // This is the same document read by main.dart.
  Future<void> savePreferences({
    bool? emailValue,
    bool? taskValue,
    bool? leadValue,
    String? themeValue,
  }) async {
    final oldEmail = emailNotifications;
    final oldTask = taskReminders;
    final oldLead = leadNotifications;
    final oldTheme = selectedTheme;

    setState(() {
      if (emailValue != null) {
        emailNotifications = emailValue;
      }

      if (taskValue != null) {
        taskReminders = taskValue;
      }

      if (leadValue != null) {
        leadNotifications = leadValue;
      }

      if (themeValue != null) {
        selectedTheme = themeValue;
      }
    });

    try {
      await preferencesRef.set({
        'emailNotifications': emailNotifications,
        'taskReminders': taskReminders,
        'leadNotifications': leadNotifications,
        'theme': selectedTheme,
        'darkModeEnabled': selectedTheme == 'Dark',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (themeValue != null) {
        showMessage('$themeValue Mode enabled.');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        emailNotifications = oldEmail;
        taskReminders = oldTask;
        leadNotifications = oldLead;
        selectedTheme = oldTheme;
      });

      showMessage('Unable to save preferences: $e');
    }
  }

  // EDIT PROFILE DIALOG
  void showProfileDialog() {
    final nameController =
        TextEditingController(text: userName);

    final emailController =
        TextEditingController(text: email);

    final phoneController =
        TextEditingController(text: phone);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBackground,
        title: Text(
          'Edit Profile',
          style: TextStyle(color: primaryText),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: primaryText),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: primaryText),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: primaryText),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final emailAddress =
                  emailController.text.trim();
              final phoneNumber =
                  phoneController.text.trim();

              if (name.isEmpty || emailAddress.isEmpty) {
                showMessage('Name and email are required.');
                return;
              }

              if (!emailAddress.contains('@')) {
                showMessage('Enter a valid email address.');
                return;
              }

              Navigator.pop(dialogContext);

              await saveProfile(
                name,
                emailAddress,
                phoneNumber,
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    });
  }

  // EDIT BUSINESS DIALOG
  void showBusinessDialog() {
    final nameController =
        TextEditingController(text: businessName);

    final emailController =
        TextEditingController(text: businessEmail);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBackground,
        title: Text(
          'Business Information',
          style: TextStyle(color: primaryText),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: primaryText),
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: primaryText),
                decoration: const InputDecoration(
                  labelText: 'Business Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final emailAddress =
                  emailController.text.trim();

              if (name.isEmpty) {
                showMessage('Business name is required.');
                return;
              }

              Navigator.pop(dialogContext);

              await saveBusiness(name, emailAddress);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      emailController.dispose();
    });
  }

  // SECTION TITLE
  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 25,
        bottom: 12,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: primaryText,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // SETTINGS CARD
  Widget settingsCard({required Widget child}) {
    return Card(
      color: cardBackground,
      elevation: isDark ? 0 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  // INFORMATION ROW
  Widget informationRow(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDark
                ? const Color(0xFF183B2A)
                : Colors.blue.shade50,
            child: Icon(
              icon,
              color: isDark
                  ? const Color(0xFF69F0AE)
                  : Colors.blue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOTIFICATION SWITCH
  Widget notificationSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: secondaryText),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: accentColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: pageBackground,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: primaryText,
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Manage your profile, business and application preferences.',
              style: TextStyle(color: secondaryText),
            ),

            // PROFILE SETTINGS
            sectionTitle('Profile Settings'),

            settingsCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: isDark
                            ? const Color(0xFF183B2A)
                            : Colors.blue.shade50,
                        child: Icon(
                          Icons.person,
                          size: 35,
                          color: isDark
                              ? const Color(0xFF69F0AE)
                              : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              email,
                              style: TextStyle(
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: showProfileDialog,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                  Divider(height: 30, color: borderColor),
                  informationRow(
                    Icons.phone,
                    'Phone Number',
                    phone,
                  ),
                  informationRow(
                    Icons.email,
                    'Email Address',
                    email,
                  ),
                ],
              ),
            ),

            // BUSINESS INFORMATION
            sectionTitle('Business Information'),

            settingsCard(
              child: Column(
                children: [
                  informationRow(
                    Icons.business,
                    'Business Name',
                    businessName,
                  ),
                  informationRow(
                    Icons.alternate_email,
                    'Business Email',
                    businessEmail,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: showBusinessDialog,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Business Details'),
                    ),
                  ),
                ],
              ),
            ),

            // NOTIFICATION PREFERENCES
            sectionTitle('Notification Preferences'),

            settingsCard(
              child: Column(
                children: [
                  notificationSwitch(
                    'Email Notifications',
                    'Receive updates through email.',
                    emailNotifications,
                    (value) {
                      savePreferences(emailValue: value);
                    },
                  ),
                  Divider(color: borderColor),
                  notificationSwitch(
                    'Task Reminders',
                    'Get reminders about pending tasks.',
                    taskReminders,
                    (value) {
                      savePreferences(taskValue: value);
                    },
                  ),
                  Divider(color: borderColor),
                  notificationSwitch(
                    'Lead Notifications',
                    'Receive alerts about new leads.',
                    leadNotifications,
                    (value) {
                      savePreferences(leadValue: value);
                    },
                  ),
                ],
              ),
            ),

            // APPEARANCE
            sectionTitle('Appearance'),

            settingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Application Theme',
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  RadioGroup<String>(
                    groupValue: selectedTheme,
                    onChanged: (value) {
                      if (value != null) {
                        savePreferences(themeValue: value);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'Light',
                          title: Text(
                            'Light Mode',
                            style: TextStyle(color: primaryText),
                          ),
                          secondary: Icon(
                            Icons.light_mode,
                            color: accentColor,
                          ),
                        ),
                        RadioListTile<String>(
                          value: 'Dark',
                          title: Text(
                            'Dark Mode',
                            style: TextStyle(color: primaryText),
                          ),
                          secondary: Icon(
                            Icons.dark_mode,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ACCOUNT SETTINGS
            sectionTitle('Account Settings'),

            settingsCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_outline,
                      color: accentColor,
                    ),
                    title: Text(
                      'Change Password',
                      style: TextStyle(color: primaryText),
                    ),
                    subtitle: Text(
                      'Send a password reset link to your email.',
                      style: TextStyle(color: secondaryText),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: secondaryText,
                    ),
                    onTap: () async {
                      final currentEmail = auth.currentUser?.email;

                      if (currentEmail == null) {
                        showMessage('No authenticated email found.');
                        return;
                      }

                      try {
                        await auth.sendPasswordResetEmail(
                          email: currentEmail,
                        );
                        showMessage(
                          'Password reset link sent to $currentEmail.',
                        );
                      } catch (e) {
                        showMessage('Unable to send reset email: $e');
                      }
                    },
                  ),
                  Divider(color: borderColor),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: Text(
                      'Sign out of your account.',
                      style: TextStyle(color: secondaryText),
                    ),
                    onTap: () async {
                      try {
                        await auth.signOut();
                      } catch (e) {
                        showMessage('Unable to log out: $e');
                      }
                    },
                  ),
                ],
              ),
            ),

            // ABOUT APPLICATION
            sectionTitle('About Application'),

            settingsCard(
              child: Column(
                children: [
                  informationRow(
                    Icons.apps,
                    'Application Name',
                    'Business CRM',
                  ),
                  informationRow(
                    Icons.info_outline,
                    'Version',
                    '1.0.0',
                  ),
                  informationRow(
                    Icons.developer_mode,
                    'Developed Using',
                    'Flutter & Dart',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Center(
              child: Text(
                'Business CRM © 2026',
                style: TextStyle(color: secondaryText),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

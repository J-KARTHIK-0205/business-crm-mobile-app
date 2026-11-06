import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final db = FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final businessController = TextEditingController();
  final businessEmailController = TextEditingController();

  bool emailNotifications = true;
  bool taskReminders = true;
  bool leadNotifications = true;
  String theme = 'Light';

  bool loading = true;
  bool saving = false;

  DocumentReference<Map<String, dynamic>> get profileRef =>
      db.collection('app_settings').doc('profile');

  DocumentReference<Map<String, dynamic>> get businessRef =>
      db.collection('app_settings').doc('business');

  DocumentReference<Map<String, dynamic>> get preferencesRef =>
      db.collection('app_settings').doc('preferences');

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
    businessController.dispose();
    businessEmailController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    try {
      final results = await Future.wait([
        profileRef.get(),
        businessRef.get(),
        preferencesRef.get(),
      ]);

      final profile = results[0].data() ?? {};
      final business = results[1].data() ?? {};
      final preferences = results[2].data() ?? {};

      nameController.text = profile['name'] ?? 'J Karthik';
      emailController.text = profile['email'] ?? 'karthik@gmail.com';
      phoneController.text = profile['phone'] ?? '9876543210';

      businessController.text = business['businessName'] ?? 'My Business';
      businessEmailController.text = business['businessEmail'] ?? 'business@gmail.com';

      emailNotifications = preferences['emailNotifications'] ?? true;
      taskReminders = preferences['taskReminders'] ?? true;
      leadNotifications = preferences['leadNotifications'] ?? true;
      theme = preferences['theme'] ?? 'Light';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveSettings() async {
    setState(() => saving = true);

    try {
      await Future.wait([
        profileRef.set({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        businessRef.set({
          'businessName': businessController.text.trim(),
          'businessEmail': businessEmailController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        preferencesRef.set({
          'emailNotifications': emailNotifications,
          'taskReminders': taskReminders,
          'leadNotifications': leadNotifications,
          'theme': theme,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    );
  }

  Widget inputField(String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text('Manage your profile, business and preferences.',
              style: TextStyle(color: colors.onSurfaceVariant)),

          sectionTitle('Profile Information'),
          Card(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(Icons.person, size: 35, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(height: 18),
                  inputField('Full Name', nameController, Icons.person_outline),
                  inputField('Email Address', emailController, Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  inputField('Phone Number', phoneController, Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                ],
              ),
            ),
          ),

          sectionTitle('Business Information'),
          Card(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  inputField('Business Name', businessController, Icons.business_outlined),
                  inputField('Business Email', businessEmailController, Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress),
                ],
              ),
            ),
          ),

          sectionTitle('App Preferences'),
          Card(
            color: colors.surface,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive updates through email'),
                  value: emailNotifications,
                  onChanged: (v) => setState(() => emailNotifications = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Task Reminders'),
                  subtitle: const Text('Get reminders about upcoming tasks'),
                  value: taskReminders,
                  onChanged: (v) => setState(() => taskReminders = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Lead Notifications'),
                  subtitle: const Text('Receive updates about leads'),
                  value: leadNotifications,
                  onChanged: (v) => setState(() => leadNotifications = v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('App Theme'),
                  subtitle: const Text('Choose light or dark appearance'),
                  trailing: DropdownButton<String>(
                    value: theme,
                    items: const [
                      DropdownMenuItem(value: 'Light', child: Text('Light')),
                      DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => theme = v);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saving ? null : saveSettings,
              icon: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
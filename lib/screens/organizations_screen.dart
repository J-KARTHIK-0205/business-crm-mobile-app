import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final searchController = TextEditingController();

  static const green = Color(0xFF00C853);
  static const muted = Color(0xFF9AA69D);
  static const card = Color(0xFF121A15);

  final types = ['All', 'Company', 'College', 'Sponsor'];

  List<Map<String, dynamic>> organizations = [];
  bool isLoading = true;
  String? loadError;
  String searchQuery = '';
  String selectedType = 'All';

  User? get user => FirebaseAuth.instance.currentUser;

  String get apiUrl {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost/business_crm_api/api/organizations/index.php';
    }

    return 'http://10.0.2.2/business_crm_api/api/organizations/index.php';
  }

  @override
  void initState() {
    super.initState();
    loadOrganizations();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> getHeaders() async {
    final current = user;

    if (current == null) {
      throw Exception('Please log in to continue.');
    }

    final token = await current.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase authentication token.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> decodeResponse(http.Response response) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from server.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected server response.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'Request failed.',
      );
    }

    return decoded;
  }

  Map<String, dynamic> mapOrganization(Map<String, dynamic> row) {
    return {
      'id': int.parse(row['id'].toString()),
      'name': row['organization_name'] ?? '',
      'type': row['organization_type'] ?? 'Company',
      'industry': row['industry'] ?? '',
      'website': row['website'] ?? '',
      'email': row['email'] ?? '',
      'phone': row['phone'] ?? '',
      'address': row['address'] ?? '',
      'contactPerson': row['contact_person'] ?? '',
      'notes': row['notes'] ?? '',
    };
  }

  Map<String, dynamic> toApiData(Map<String, dynamic> data) {
    return {
      'organization_name': data['name'] ?? '',
      'organization_type': data['type'] ?? 'Company',
      'industry': data['industry'] ?? '',
      'website': data['website'] ?? '',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'address': data['address'] ?? '',
      'contact_person': data['contactPerson'] ?? '',
      'notes': data['notes'] ?? '',
    };
  }

  Future<void> loadOrganizations() async {
    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'Please log in to continue.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(const Duration(seconds: 20));

      final result = decodeResponse(response);
      final rows = result['data'];

      if (rows is! List) {
        throw Exception('Organization data was not returned correctly.');
      }

      final loaded = rows
          .whereType<Map>()
          .map((row) => mapOrganization(
                Map<String, dynamic>.from(row),
              ))
          .toList();

      if (!mounted) return;

      setState(() {
        organizations = loaded;
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<String?> saveOrganization(
    Map<String, dynamic> organization, {
    int? id,
  }) async {
    try {
      final headers = await getHeaders();
      final apiData = toApiData(organization);

      final http.Response response;

      if (id == null) {
        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: headers,
              body: jsonEncode(apiData),
            )
            .timeout(const Duration(seconds: 20));
      } else {
        apiData['id'] = id;

        response = await http
            .put(
              Uri.parse(apiUrl),
              headers: headers,
              body: jsonEncode(apiData),
            )
            .timeout(const Duration(seconds: 20));
      }

      decodeResponse(response);

      await loadOrganizations();

      if (loadError != null) {
        return 'Saved successfully, but the list could not refresh: $loadError';
      }

      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> showOrganizationDialog({
    int? id,
    Map<String, dynamic>? data,
  }) async {
    if (user == null) {
      showMessage('Please log in to continue.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _OrganizationDialog(
        data: data ?? {},
        onSave: (organization) {
          return saveOrganization(organization, id: id);
        },
      ),
    );
  }

  Future<void> deleteOrganization(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Delete Organization?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete $name? This cannot be undone.',
          style: const TextStyle(color: muted),
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final headers = await getHeaders();

      final response = await http
          .delete(
            Uri.parse('$apiUrl?id=$id'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      decodeResponse(response);

      await loadOrganizations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization deleted successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      showMessage(
        'Delete failed: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData typeIcon(String type) {
    switch (type) {
      case 'College':
        return Icons.school_outlined;
      case 'Sponsor':
        return Icons.handshake_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  List<Map<String, dynamic>> get filteredOrganizations {
    final query = searchQuery.toLowerCase();

    return organizations.where((data) {
      final name = (data['name'] ?? '').toString().toLowerCase();
      final industry = (data['industry'] ?? '').toString().toLowerCase();
      final type = (data['type'] ?? 'Company').toString();

      return (name.contains(query) || industry.contains(query)) &&
          (selectedType == 'All' || selectedType == type);
    }).toList();
  }

  Widget organizationCard(Map<String, dynamic> data) {
    final id = int.parse(data['id'].toString());
    final name = (data['name'] ?? 'Unnamed Organization').toString();
    final type = (data['type'] ?? 'Company').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              typeIcon(type),
              color: const Color(0xFF69F0AE),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                _tag(type),
                if ((data['industry'] ?? '').toString().isNotEmpty)
                  _info(
                    Icons.category_outlined,
                    data['industry'].toString(),
                  ),
                if ((data['contactPerson'] ?? '').toString().isNotEmpty)
                  _info(
                    Icons.person_outline,
                    data['contactPerson'].toString(),
                  ),
                if ((data['phone'] ?? '').toString().isNotEmpty)
                  _info(
                    Icons.phone_outlined,
                    data['phone'].toString(),
                  ),
                if ((data['email'] ?? '').toString().isNotEmpty)
                  _info(
                    Icons.email_outlined,
                    data['email'].toString(),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: card,
            icon: const Icon(Icons.more_vert, color: muted),
            onSelected: (value) {
              if (value == 'edit') {
                showOrganizationDialog(id: id, data: data);
              } else if (value == 'delete') {
                deleteOrganization(id, name);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF69F0AE),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _info(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: muted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(String label, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to continue.',
          style: TextStyle(color: muted),
        ),
      );
    }

    if (isLoading && organizations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    if (loadError != null && organizations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: muted,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: loadOrganizations,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = filteredOrganizations;

    final companyCount = organizations
        .where((item) => item['type'] == 'Company')
        .length;

    final collegeCount = organizations
        .where((item) => item['type'] == 'College')
        .length;

    return RefreshIndicator(
      color: green,
      onRefresh: loadOrganizations,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organizations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage companies, colleges and sponsors.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _summary('Total', organizations.length),
                const SizedBox(width: 10),
                _summary('Companies', companyCount),
                const SizedBox(width: 10),
                _summary('Colleges', collegeCount),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() => searchQuery = value.trim());
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                hintStyle: const TextStyle(color: muted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: green),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                        icon: const Icon(Icons.close, color: muted),
                      ),
                filled: true,
                fillColor: card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              dropdownColor: card,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Organization type',
                labelStyle: const TextStyle(color: muted),
                filled: true,
                fillColor: card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
              items: types.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showOrganizationDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Organization'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'All Organizations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${filtered.length} records',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Refresh failed: $loadError',
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(
                  child: Text(
                    'No organizations found. Add one to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                ),
              )
            else
              ...filtered.map(organizationCard),
          ],
        ),
      ),
    );
  }
}

class _OrganizationDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  const _OrganizationDialog({
    required this.data,
    required this.onSave,
  });

  @override
  State<_OrganizationDialog> createState() => _OrganizationDialogState();
}

class _OrganizationDialogState extends State<_OrganizationDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController industryController;
  late final TextEditingController websiteController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController contactController;
  late final TextEditingController notesController;

  String selectedType = 'Company';
  bool saving = false;

  static const green = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();

    final data = widget.data;

    nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );
    industryController = TextEditingController(
      text: data['industry']?.toString() ?? '',
    );
    websiteController = TextEditingController(
      text: data['website']?.toString() ?? '',
    );
    emailController = TextEditingController(
      text: data['email']?.toString() ?? '',
    );
    phoneController = TextEditingController(
      text: data['phone']?.toString() ?? '',
    );
    addressController = TextEditingController(
      text: data['address']?.toString() ?? '',
    );
    contactController = TextEditingController(
      text: data['contactPerson']?.toString() ?? '',
    );
    notesController = TextEditingController(
      text: data['notes']?.toString() ?? '',
    );

    const allowed = ['Company', 'College', 'Sponsor'];

    selectedType = allowed.contains(data['type'])
        ? data['type'].toString()
        : 'Company';
  }

  @override
  void dispose() {
    nameController.dispose();
    industryController.dispose();
    websiteController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    contactController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      final error = await widget.onSave({
        'name': nameController.text.trim(),
        'type': selectedType,
        'industry': industryController.text.trim(),
        'website': websiteController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'contactPerson': contactController.text.trim(),
        'notes': notesController.text.trim(),
      });

      if (!mounted) return;

      if (error == null) {
        Navigator.pop(context);
      } else {
        setState(() => saving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save: $error')),
      );
    }
  }

  Widget field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: green),
          filled: true,
          fillColor: const Color(0xFF1A241D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.data.isNotEmpty;

    return AlertDialog(
      backgroundColor: const Color(0xFF121A15),
      title: Text(
        editing ? 'Edit Organization' : 'Add Organization',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(
                  nameController,
                  'Organization Name *',
                  Icons.business_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Organization name is required.';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  dropdownColor: const Color(0xFF1A241D),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Organization Type',
                    filled: true,
                    fillColor: Color(0xFF1A241D),
                    border: OutlineInputBorder(),
                  ),
                  items: const ['Company', 'College', 'Sponsor'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => selectedType = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                field(
                  industryController,
                  'Industry',
                  Icons.category_outlined,
                ),
                field(
                  websiteController,
                  'Website',
                  Icons.language_outlined,
                ),
                field(
                  emailController,
                  'Email',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isNotEmpty &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                      return 'Enter a valid email address.';
                    }

                    return null;
                  },
                ),
                field(
                  phoneController,
                  'Phone',
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                field(
                  addressController,
                  'Address',
                  Icons.location_on_outlined,
                ),
                field(
                  contactController,
                  'Contact Person',
                  Icons.person_outline,
                ),
                field(
                  notesController,
                  'Notes',
                  Icons.notes_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.black,
          ),
          child: saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(editing ? 'Update' : 'Save Organization'),
        ),
      ],
    );
  }
}
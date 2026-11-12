
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// =====================================================
// CUSTOMER MODEL
// =====================================================

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String company;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.company,
  });

  // MySQL / PHP API response
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: (json['id'] ?? '').toString(),
      name: (json['customer_name'] ?? json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
    );
  }

  // Compatibility with the existing Firestore Leads screen
  factory Customer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return Customer(
      id: document.id,
      name: (data['name'] ?? data['customer_name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      company: (data['company'] ?? '').toString(),
    );
  }
}

// =====================================================
// CUSTOMERS SCREEN
// =====================================================

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController searchController = TextEditingController();

  static const Color backgroundColor = Color(0xFF080C09);
  static const Color cardColor = Color(0xFF121A15);
  static const Color emerald = Color(0xFF00C853);
  static const Color emeraldLight = Color(0xFF69F0AE);
  static const Color mutedColor = Color(0xFF9AA69D);

  String searchText = '';
  List<Customer> customers = [];

  bool isLoading = true;
  String? loadError;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // API URL
  String get apiUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/business_crm_api/api/customers/index.php';
    }

    return 'http://localhost/business_crm_api/api/customers/index.php';
  }

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // API HEADERS
  // =====================================================

  Future<Map<String, String>> getHeaders() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Please log in to continue.');
    }

    final token = await user.getIdToken(true);

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase authentication token.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =====================================================
  // API RESPONSE HANDLING
  // =====================================================

  Map<String, dynamic> decodeResponse(http.Response response) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response received from the server.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected server response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ??
            'Server error: ${response.statusCode}',
      );
    }

    if (decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ?? 'Request failed.',
      );
    }

    return decoded;
  }

  // =====================================================
  // LOAD CUSTOMERS FROM MYSQL
  // =====================================================

  Future<void> loadCustomers() async {
    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Please log in to view customers.';
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
      final dynamic data = result['data'];

      if (data is! List) {
        throw Exception('Customer list was not returned by the server.');
      }

      final loadedCustomers = data
          .whereType<Map>()
          .map(
            (item) => Customer.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        customers = loadedCustomers;
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

  // =====================================================
  // ADD CUSTOMER
  // =====================================================

  Future<void> addCustomer(Map<String, dynamic> customerData) async {
    final headers = await getHeaders();

    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: headers,
          body: jsonEncode(customerData),
        )
        .timeout(const Duration(seconds: 20));

    decodeResponse(response);

    await loadCustomers();

    if (loadError != null) {
      throw Exception('Customer saved, but refreshing the list failed: $loadError');
    }
  }

  // =====================================================
  // UPDATE CUSTOMER
  // =====================================================

  Future<void> updateCustomer(
    Customer customer,
    Map<String, dynamic> customerData,
  ) async {
    final headers = await getHeaders();

    final response = await http
        .put(
          Uri.parse(apiUrl),
          headers: headers,
          body: jsonEncode({
            'id': customer.id,
            ...customerData,
          }),
        )
        .timeout(const Duration(seconds: 20));

    decodeResponse(response);

    await loadCustomers();

    if (loadError != null) {
      throw Exception('Customer updated, but refreshing the list failed: $loadError');
    }
  }

  // =====================================================
  // ADD / EDIT CUSTOMER DIALOG
  // =====================================================

  Future<void> showCustomerDialog({Customer? customer}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CustomerDialog(
          customer: customer,
          onSave: (customerData) async {
            if (customer == null) {
              await addCustomer(customerData);
            } else {
              await updateCustomer(customer, customerData);
            }
          },
        );
      },
    );

    if (!mounted || result != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          customer == null
              ? 'Customer added successfully.'
              : 'Customer updated successfully.',
        ),
      ),
    );
  }

  // =====================================================
  // DELETE CUSTOMER
  // =====================================================

  Future<void> deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text(
            'Delete Customer?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete ${customer.name}?',
            style: const TextStyle(color: mutedColor),
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
        );
      },
    );

    if (confirm != true) return;

    try {
      final headers = await getHeaders();

      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {'id': customer.id},
      );

      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

      decodeResponse(response);

      await loadCustomers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deleted successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $error'),
        ),
      );
    }
  }

  // =====================================================
  // SUMMARY CARD
  // =====================================================

  Widget summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: emerald.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: emeraldLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // CUSTOMER INFORMATION ROW
  // =====================================================

  Widget infoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: mutedColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // CUSTOMER CARD
  // =====================================================

  Widget customerCard(Customer customer) {
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: emeraldLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (customer.company.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    infoRow(Icons.business_outlined, customer.company),
                  ],
                  if (customer.phone.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    infoRow(Icons.phone_outlined, customer.phone),
                  ],
                  if (customer.email.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    infoRow(Icons.email_outlined, customer.email),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: mutedColor),
              color: cardColor,
              onSelected: (value) {
                if (value == 'edit') {
                  showCustomerDialog(customer: customer);
                } else if (value == 'delete') {
                  deleteCustomer(customer);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 19),
                      SizedBox(width: 9),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // EMPTY STATE
  // =====================================================

  Widget emptyState({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                color: emeraldLight,
                size: 38,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mutedColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // MAIN SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final query = searchText.toLowerCase().trim();

    final filteredCustomers = customers.where((customer) {
      return customer.name.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query) ||
          customer.email.toLowerCase().contains(query) ||
          customer.company.toLowerCase().contains(query);
    }).toList();

    return RefreshIndicator(
      color: emerald,
      onRefresh: loadCustomers,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 430;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage your business relationships in one place.',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                if (isNarrow)
                  Column(
                    children: [
                      summaryCard(
                        title: 'Total Customers',
                        value: '${customers.length}',
                        icon: Icons.people_outline,
                      ),
                      const SizedBox(height: 10),
                      summaryCard(
                        title: 'Search Results',
                        value: '${filteredCustomers.length}',
                        icon: Icons.manage_search,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: summaryCard(
                          title: 'Total Customers',
                          value: '${customers.length}',
                          icon: Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: summaryCard(
                          title: 'Search Results',
                          value: '${filteredCustomers.length}',
                          icon: Icons.manage_search,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 22),

                TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      searchText = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle: const TextStyle(
                      color: mutedColor,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: emeraldLight,
                    ),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchText = '';
                              });
                            },
                            icon: const Icon(
                              Icons.close,
                              color: mutedColor,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showCustomerDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Customer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: emerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All Customers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${filteredCustomers.length} records',
                      style: const TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: emerald),
                    ),
                  )
                else if (loadError != null)
                  emptyState(
                    title: 'Unable to load customers',
                    subtitle: loadError!,
                  )
                else if (filteredCustomers.isEmpty)
                  emptyState(
                    title: searchText.isEmpty
                        ? 'No customers yet'
                        : 'No matching customers',
                    subtitle: searchText.isEmpty
                        ? 'Add your first customer to get started.'
                        : 'Try another name, phone, email or company.',
                  )
                else
                  ...filteredCustomers.map(customerCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =====================================================
// ADD / EDIT CUSTOMER DIALOG
// =====================================================

class CustomerDialog extends StatefulWidget {
  final Customer? customer;

  final Future<void> Function(
    Map<String, dynamic> customerData,
  ) onSave;

  const CustomerDialog({
    super.key,
    this.customer,
    required this.onSave,
  });

  @override
  State<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<CustomerDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController companyController;

  bool isSaving = false;

  static const Color emerald = Color(0xFF00C853);
  static const Color mutedColor = Color(0xFF9AA69D);

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.customer?.name ?? '',
    );
    phoneController = TextEditingController(
      text: widget.customer?.phone ?? '',
    );
    emailController = TextEditingController(
      text: widget.customer?.email ?? '',
    );
    companyController = TextEditingController(
      text: widget.customer?.company ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    companyController.dispose();
    super.dispose();
  }

  // SAVE CUSTOMER

  Future<void> saveCustomer() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      await widget.onSave({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'company': companyController.text.trim(),
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save customer: $error',
          ),
        ),
      );
    }
  }

  // INPUT FIELD

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: mutedColor),
          prefixIcon: Icon(icon, color: emerald),
          filled: true,
          fillColor: const Color(0xFF1A241D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: emerald,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF121A15),
      title: Text(
        isEditing ? 'Edit Customer' : 'Add Customer',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                inputField(
                  controller: nameController,
                  label: 'Customer Name *',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Customer name is required.';
                    }
                    return null;
                  },
                ),
                inputField(
                  controller: phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                inputField(
                  controller: emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
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
                inputField(
                  controller: companyController,
                  label: 'Company',
                  icon: Icons.business_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving
              ? null
              : () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: mutedColor),
          ),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : saveCustomer,
          style: FilledButton.styleFrom(
            backgroundColor: emerald,
            foregroundColor: Colors.black,
          ),
          icon: isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isSaving ? 'Saving...' : 'Save Customer'),
        ),
      ],
    );
  }
}

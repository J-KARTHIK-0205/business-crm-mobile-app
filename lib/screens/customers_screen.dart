
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  factory Customer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return Customer(
      id: document.id,
      name: (data['name'] ?? '').toString(),
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
  final CollectionReference<Map<String, dynamic>> customersCollection =
      FirebaseFirestore.instance.collection('customers');

  final TextEditingController searchController = TextEditingController();

  String searchText = '';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  static const Color emerald = Color(0xFF00C853);
  static const Color emeraldLight = Color(0xFF69F0AE);
  static const Color cardColor = Color(0xFF121A15);
  static const Color mutedColor = Color(0xFF9AA69D);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =====================================================
  // ADD / EDIT CUSTOMER
  // =====================================================

  Future<void> showCustomerDialog({Customer? customer}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CustomerDialog(
          customer: customer,
          onSave: (customerData) async {
            final user = currentUser;

            if (user == null) {
              throw Exception('Please log in to continue.');
            }

            if (customer == null) {
              customerData['userId'] = user.uid;
              customerData['createdAt'] =
                  FieldValue.serverTimestamp();
              customerData['updatedAt'] =
                  FieldValue.serverTimestamp();

              await customersCollection.add(customerData);
            } else {
              final customerRef =
                  customersCollection.doc(customer.id);

              final existing = await customerRef.get();

              if (!existing.exists ||
                  existing.data()?['userId'] != user.uid) {
                throw Exception(
                  'You cannot edit a customer you do not own.',
                );
              }

              await customerRef.update({
                ...customerData,
                'updatedAt': FieldValue.serverTimestamp(),
              });
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
    final user = currentUser;

    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
          'Are you sure you want to delete ${customer.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final reference =
          customersCollection.doc(customer.id);

      final document = await reference.get();

      if (!document.exists ||
          document.data()?['userId'] != user.uid) {
        throw Exception(
          'You cannot delete a customer you do not own.',
        );
      }

      await reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deleted successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
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
                    _infoRow(
                      Icons.business_outlined,
                      customer.company,
                    ),
                  ],
                  if (customer.phone.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _infoRow(
                      Icons.phone_outlined,
                      customer.phone,
                    ),
                  ],
                  if (customer.email.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _infoRow(
                      Icons.email_outlined,
                      customer.email,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: mutedColor,
              ),
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

  Widget _infoRow(IconData icon, String value) {
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
    final user = currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please log in to view customers.'),
      );
    }

    final customerStream = customersCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: customerStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load customers: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: emerald,
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final allCustomers =
            documents.map(Customer.fromFirestore).toList();

        final query = searchText.toLowerCase().trim();

        final filteredCustomers = allCustomers.where((customer) {
          return customer.name.toLowerCase().contains(query) ||
              customer.phone.contains(searchText.trim()) ||
              customer.email.toLowerCase().contains(query) ||
              customer.company.toLowerCase().contains(query);
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 430;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PAGE HEADING
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

                  // SUMMARY
                  if (isNarrow)
                    Column(
                      children: [
                        summaryCard(
                          title: 'Total Customers',
                          value: '${allCustomers.length}',
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
                            value: '${allCustomers.length}',
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

                  // SEARCH
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

                  // ADD CUSTOMER
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showCustomerDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Customer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // LIST HEADING
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

                  // CUSTOMER LIST
                  if (filteredCustomers.isEmpty)
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
        );
      },
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
          content: Text('Unable to save customer: $error'),
        ),
      );
    }
  }

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

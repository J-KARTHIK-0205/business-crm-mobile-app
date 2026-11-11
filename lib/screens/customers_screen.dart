import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// CUSTOMER MODEL
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

// CUSTOMERS SCREEN
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController searchController = TextEditingController();

  final CollectionReference<Map<String, dynamic>> customersCollection =
      FirebaseFirestore.instance.collection('customers');

  String searchText = '';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ADD / EDIT CUSTOMER
  void showCustomerDialog({Customer? customer}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CustomerDialog(
        customer: customer,
        onSave: (customerData) async {
          final user = currentUser;

          if (user == null) {
            throw Exception('Please log in to continue.');
          }

          if (customer == null) {
            customerData['userId'] = user.uid;
            customerData['createdAt'] = FieldValue.serverTimestamp();
            customerData['updatedAt'] = FieldValue.serverTimestamp();

            await customersCollection.add(customerData);
          } else {
            final customerRef = customersCollection.doc(customer.id);
            final existing = await customerRef.get();

            if (!existing.exists || existing.data()?['userId'] != user.uid) {
              throw Exception('You cannot edit a customer you do not own.');
            }

            await customerRef.update({
              ...customerData,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        },
      ),
    );
  }

  // DELETE CUSTOMER
  Future<void> deleteCustomer(Customer customer) async {
    final user = currentUser;

    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final ref = customersCollection.doc(customer.id);
      final doc = await ref.get();

      if (!doc.exists || doc.data()?['userId'] != user.uid) {
        throw Exception('You cannot delete a customer you do not own.');
      }

      await ref.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting customer: $error')),
      );
    }
  }

  // MAIN SCREEN
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view customers.'));
    }

    final userCustomersStream = customersCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customers Management',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Manage and organize all your business customers.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 25),

        // SEARCH AND ADD CUSTOMER
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            ElevatedButton.icon(
              onPressed: () => showCustomerDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // CUSTOMER LIST
        Expanded(
          child: Card(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userCustomersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading customers: ${snapshot.error}'),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final query = searchText.toLowerCase().trim();

                final customers = (snapshot.data?.docs ?? [])
                    .map(Customer.fromFirestore)
                    .where((customer) {
                      return customer.name.toLowerCase().contains(query) ||
                          customer.phone.contains(searchText) ||
                          customer.email.toLowerCase().contains(query) ||
                          customer.company.toLowerCase().contains(query);
                    })
                    .toList();

                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 55,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No customers found',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                // CORRECTED LISTVIEW.SEPARATED
                return ListView.separated(
                  itemCount: customers.length,

                  separatorBuilder: (context, index) {
                    return Divider(height: 1, color: colors.outlineVariant);
                  },

                  itemBuilder: (context, index) {
                    final customer = customers[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.all(16),

                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      title: Text(
                        customer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.company.isNotEmpty)
                              Text('Company: ${customer.company}'),
                            if (customer.phone.isNotEmpty)
                              Text('Phone: ${customer.phone}'),
                            if (customer.email.isNotEmpty)
                              Text('Email: ${customer.email}'),
                          ],
                        ),
                      ),

                      trailing: PopupMenuButton<String>(
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
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ADD / EDIT CUSTOMER DIALOG
class CustomerDialog extends StatefulWidget {
  final Customer? customer;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const CustomerDialog({super.key, this.customer, required this.onSave});

  @override
  State<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<CustomerDialog> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController companyController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.customer?.name ?? '');

    phoneController = TextEditingController(text: widget.customer?.phone ?? '');

    emailController = TextEditingController(text: widget.customer?.email ?? '');

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
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required.')),
      );
      return;
    }

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

      final message = widget.customer == null
          ? 'Customer added successfully'
          : 'Customer updated successfully';

      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save customer: $error')),
      );
    }
  }

  // CUSTOMER FORM
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),

      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),

        ElevatedButton.icon(
          onPressed: isSaving ? null : saveCustomer,
          icon: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

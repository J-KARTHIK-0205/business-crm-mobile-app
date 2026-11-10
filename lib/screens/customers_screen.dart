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

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.company,
  });

  factory Customer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return Customer(
      id: document.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      company: data['company'] ?? '',
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
  final TextEditingController searchController =
      TextEditingController();

  String searchText = '';

  final CollectionReference<Map<String, dynamic>>
      customersCollection =
      FirebaseFirestore.instance.collection('customers');

  // CURRENT LOGGED-IN USER

  User? get currentUser =>
      FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ADD / EDIT CUSTOMER

  void showCustomerDialog({Customer? customer}) {
    showDialog<void>(
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
              // ADD CUSTOMER WITH OWNER UID

              customerData['userId'] = user.uid;

              customerData['createdAt'] =
                  FieldValue.serverTimestamp();

              await customersCollection.add(customerData);
            } else {
              // UPDATE EXISTING CUSTOMER

              await customersCollection
                  .doc(customer.id)
                  .update(customerData);
            }
          },
        );
      },
    );
  }

  // DELETE CUSTOMER

  Future<void> deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Customer'),
          content: const Text(
            'Are you sure you want to delete this customer?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await customersCollection.doc(customer.id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deleted successfully'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting customer: $error'),
        ),
      );
    }
  }

  // MAIN SCREEN

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final user = currentUser;

    // CHECK LOGIN

    if (user == null) {
      return const Center(
        child: Text('Please log in to view customers.'),
      );
    }

    // FETCH ONLY CURRENT USER'S CUSTOMERS

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

        // SEARCH AND ADD BUTTON

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
                style: TextStyle(color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colors.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colors.primary,
                      width: 1.5,
                    ),
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
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: userCustomersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading customers: ${snapshot.error}',
                        style: TextStyle(
                          color: colors.error,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final customers = snapshot.data!.docs
                    .map(
                      (document) =>
                          Customer.fromFirestore(document),
                    )
                    .where((customer) {
                      final query = searchText.toLowerCase();

                      return customer.name
                              .toLowerCase()
                              .contains(query) ||
                          customer.phone.contains(searchText) ||
                          customer.email
                              .toLowerCase()
                              .contains(query) ||
                          customer.company
                              .toLowerCase()
                              .contains(query);
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
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: customers.length,

                  separatorBuilder: (_, index) => Divider(
                    height: 1,
                    color: colors.outlineVariant,
                  ),

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
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        '${customer.company}\n'
                        '${customer.phone}\n'
                        '${customer.email}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      isThreeLine: true,

                      trailing: PopupMenuButton<String>(
                        iconColor: colors.onSurfaceVariant,
                        onSelected: (value) {
                          if (value == 'edit') {
                            showCustomerDialog(
                              customer: customer,
                            );
                          } else if (value == 'delete') {
                            deleteCustomer(customer);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 10),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 10),
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

// CUSTOMER ADD / EDIT DIALOG

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
  State<CustomerDialog> createState() =>
      _CustomerDialogState();
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

  // SAFE CONTROLLER DISPOSAL

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
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name and phone number are required',
          ),
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    final customerData = <String, dynamic>{
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'company': companyController.text.trim(),
    };

    try {
      await widget.onSave(customerData);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.customer == null
                ? 'Customer added successfully'
                : 'Customer updated successfully',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving customer: $error'),
        ),
      );
    }
  }

  // THEME-AWARE DIALOG

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,

      title: Text(
        widget.customer == null
            ? 'Add Customer'
            : 'Edit Customer',
        style: TextStyle(
          color: colors.onSurface,
        ),
      ),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: companyController,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Company',
                prefixIcon: Icon(Icons.business),
              ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: isSaving
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: isSaving ? null : saveCustomer,
          child: isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.customer == null
                      ? 'Add'
                      : 'Update',
                ),
        ),
      ],
    );
  }
}
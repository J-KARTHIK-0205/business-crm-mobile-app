import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'customers_screen.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final CollectionReference<Map<String, dynamic>> leadsCollection =
      FirebaseFirestore.instance.collection('leads');

  final CollectionReference<Map<String, dynamic>> customersCollection =
      FirebaseFirestore.instance.collection('customers');

  final TextEditingController searchController = TextEditingController();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String searchText = '';
  String selectedStatus = 'All';
  String selectedPriority = 'All';
  String selectedCategory = 'All';

  final List<String> statuses = [
    'All',
    'New',
    'Contacted',
    'Qualified',
    'Converted',
    'Lost',
  ];

  final List<String> priorities = ['All', 'High', 'Medium', 'Low'];

  final List<String> categories = [
    'All',
    'Business',
    'Individual',
    'Enterprise',
    'Other',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // STATUS COLORS
  Color statusColor(String status) {
    switch (status) {
      case 'Contacted':
        return Colors.orange;
      case 'Qualified':
        return Colors.blue;
      case 'Converted':
        return Colors.green;
      case 'Lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // PRIORITY COLORS
  Color priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  // LOAD CUSTOMERS FOR CURRENT USER
  Future<List<Customer>> loadCustomers() async {
    final user = currentUser;

    if (user == null) return [];

    final result = await customersCollection
        .where('userId', isEqualTo: user.uid)
        .get();

    return result.docs.map(Customer.fromFirestore).toList();
  }

  // ADD / EDIT LEAD
  Future<void> showLeadDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final user = currentUser;

    if (user == null) return;

    final data = document?.data() ?? <String, dynamic>{};

    List<Customer> availableCustomers = [];

    try {
      availableCustomers = await loadCustomers();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load customers: $error')),
      );
      return;
    }

    if (!mounted) return;

    String? customerId = data['customerId']?.toString();

    if (customerId != null &&
        !availableCustomers.any((c) => c.id == customerId)) {
      customerId = null;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _LeadDialog(
          data: data,
          customers: availableCustomers,
          initialCustomerId: customerId,
          onSave: (leadData) async {
            try {
              // Verify the selected customer belongs to this user.
              if (leadData['customerId'] != null) {
                final customerDoc = await customersCollection
                    .doc(leadData['customerId'])
                    .get();

                if (!customerDoc.exists ||
                    customerDoc.data()?['userId'] != user.uid) {
                  return 'Selected customer is not available.';
                }

                final customerData = customerDoc.data()!;

                leadData['customerName'] = (customerData['name'] ?? '')
                    .toString();

                leadData['customerCompany'] = (customerData['company'] ?? '')
                    .toString();
              } else {
                leadData['customerName'] = null;
                leadData['customerCompany'] = null;
              }

              leadData['updatedAt'] = FieldValue.serverTimestamp();

              if (document == null) {
                leadData['userId'] = user.uid;
                leadData['createdAt'] = FieldValue.serverTimestamp();

                await leadsCollection.add(leadData);
              } else {
                final existing = await leadsCollection.doc(document.id).get();

                if (!existing.exists ||
                    existing.data()?['userId'] != user.uid) {
                  return 'You cannot edit a lead you do not own.';
                }

                await leadsCollection.doc(document.id).update(leadData);
              }

              return null;
            } catch (error) {
              return 'Unable to save lead: $error';
            }
          },
        );
      },
    );
  }

  // DELETE LEAD
  Future<void> deleteLead(String id) async {
    final user = currentUser;

    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Lead'),
        content: const Text('Are you sure you want to delete this lead?'),
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
      final ref = leadsCollection.doc(id);
      final doc = await ref.get();

      if (!doc.exists || doc.data()?['userId'] != user.uid) {
        throw Exception('You cannot delete a lead you do not own.');
      }

      await ref.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  // VIEW LEAD DETAILS
  void showLeadDetails(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text((data['name'] ?? 'Lead Details').toString()),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('Phone', data['phone']),
                _detailLine('Email', data['email']),
                _detailLine('Source', data['source']),
                _detailLine('Status', data['status']),
                _detailLine('Priority', data['priority']),
                _detailLine('Category', data['category']),
                _detailLine('Linked Customer', data['customerName']),
                _detailLine('Company', data['customerCompany']),
                _detailLine('Notes', data['notes']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showLeadDialog(document: document);
            },
            child: const Text('Edit Lead'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, dynamic value) {
    final text = (value ?? '').toString().trim();

    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('$label: $text'),
    );
  }

  // SUMMARY CARD
  Widget _summaryCard(String title, int count, IconData icon, Color color) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 155,
      child: Card(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: TextStyle(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  // LEAD CARD
  Widget _leadCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};

    final name = (data['name'] ?? 'Unnamed Lead').toString();
    final phone = (data['phone'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final source = (data['source'] ?? '').toString();
    final status = (data['status'] ?? 'New').toString();
    final priority = (data['priority'] ?? 'Medium').toString();
    final category = (data['category'] ?? 'Other').toString();
    final customerName = (data['customerName'] ?? '').toString();

    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showLeadDetails(document),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: colors.onPrimaryContainer),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (phone.isNotEmpty)
                      _leadInfo(Icons.phone_outlined, phone),
                    if (email.isNotEmpty)
                      _leadInfo(Icons.email_outlined, email),
                    if (source.isNotEmpty)
                      _leadInfo(Icons.campaign_outlined, source),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag(status, statusColor(status)),
                        _tag(priority, priorityColor(priority)),
                        _tag(category, Colors.blueGrey),
                        if (customerName.isNotEmpty)
                          _tag('Customer: $customerName', Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'details') {
                    showLeadDetails(document);
                  } else if (value == 'edit') {
                    showLeadDialog(document: document);
                  } else if (value == 'delete') {
                    deleteLead(document.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'details', child: Text('View Details')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadInfo(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // MAIN SCREEN WITH FULL-PAGE SCROLLING
  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view leads.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leadsCollection.where('userId', isEqualTo: user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load leads: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data?.docs ?? [];

        int countStatus(String value) {
          return documents.where((doc) => doc.data()['status'] == value).length;
        }

        final query = searchText.toLowerCase().trim();

        final filtered = documents.where((doc) {
          final data = doc.data();

          final name = (data['name'] ?? '').toString().toLowerCase();
          final phone = (data['phone'] ?? '').toString();
          final email = (data['email'] ?? '').toString().toLowerCase();

          final matchesSearch =
              name.contains(query) ||
              phone.contains(searchText) ||
              email.contains(query);

          final matchesStatus =
              selectedStatus == 'All' || data['status'] == selectedStatus;

          final matchesPriority =
              selectedPriority == 'All' || data['priority'] == selectedPriority;

          final matchesCategory =
              selectedCategory == 'All' || data['category'] == selectedCategory;

          return matchesSearch &&
              matchesStatus &&
              matchesPriority &&
              matchesCategory;
        }).toList();

        // IMPORTANT:
        // One scroll view contains the complete page.
        // There is no nested Expanded or ListView for the lead list.
        return LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              child: SingleChildScrollView(
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leads Management',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Track, organize and convert your potential customers.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),

                      // SUMMARY CARDS
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _summaryCard(
                            'Total Leads',
                            documents.length,
                            Icons.people_outline,
                            Colors.blue,
                          ),
                          _summaryCard(
                            'New Leads',
                            countStatus('New'),
                            Icons.person_add_alt,
                            Colors.orange,
                          ),
                          _summaryCard(
                            'Contacted',
                            countStatus('Contacted'),
                            Icons.call,
                            Colors.deepOrange,
                          ),
                          _summaryCard(
                            'Qualified',
                            countStatus('Qualified'),
                            Icons.verified,
                            Colors.indigo,
                          ),
                          _summaryCard(
                            'Converted',
                            countStatus('Converted'),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // SEARCH AND ADD BUTTON
                      LayoutBuilder(
                        builder: (context, searchConstraints) {
                          if (searchConstraints.maxWidth < 420) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _searchField(),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () => showLeadDialog(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Lead'),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: _searchField()),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => showLeadDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Lead'),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // FILTERS
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _filterDropdown(
                            label: 'Status',
                            value: selectedStatus,
                            items: statuses,
                            onChanged: (value) {
                              setState(() {
                                selectedStatus = value;
                              });
                            },
                          ),
                          _filterDropdown(
                            label: 'Priority',
                            value: selectedPriority,
                            items: priorities,
                            onChanged: (value) {
                              setState(() {
                                selectedPriority = value;
                              });
                            },
                          ),
                          _filterDropdown(
                            label: 'Category',
                            value: selectedCategory,
                            items: categories,
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // LEAD LIST
                      Text(
                        'All Leads (${filtered.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 45),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  size: 55,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No leads found',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Add a lead or change your filters.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map(_leadCard),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // SEARCH FIELD
  Widget _searchField() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          searchText = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search leads by name, phone or email...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // REUSABLE FILTER DROPDOWN
  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }
}

// =====================================================
// SEPARATE LEAD DIALOG
// Controllers are owned and disposed by this widget.
// This avoids the previous controller-disposal crash.
// =====================================================

class _LeadDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Customer> customers;
  final String? initialCustomerId;

  final Future<String?> Function(Map<String, dynamic> leadData) onSave;

  const _LeadDialog({
    required this.data,
    required this.customers,
    required this.initialCustomerId,
    required this.onSave,
  });

  @override
  State<_LeadDialog> createState() => _LeadDialogState();
}

class _LeadDialogState extends State<_LeadDialog> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController sourceController;
  late final TextEditingController notesController;

  late String status;
  late String priority;
  late String category;

  String? customerId;

  bool isSaving = false;

  final List<String> statuses = [
    'New',
    'Contacted',
    'Qualified',
    'Converted',
    'Lost',
  ];

  final List<String> priorities = ['High', 'Medium', 'Low'];

  final List<String> categories = [
    'Business',
    'Individual',
    'Enterprise',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.data;

    nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );

    phoneController = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );

    emailController = TextEditingController(
      text: (data['email'] ?? '').toString(),
    );

    sourceController = TextEditingController(
      text: (data['source'] ?? '').toString(),
    );

    notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    status = (data['status'] ?? 'New').toString();
    priority = (data['priority'] ?? 'Medium').toString();
    category = (data['category'] ?? 'Business').toString();

    if (!statuses.contains(status)) status = 'New';
    if (!priorities.contains(priority)) priority = 'Medium';
    if (!categories.contains(category)) category = 'Business';

    customerId = widget.initialCustomerId;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    sourceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // SAVE LEAD
  Future<void> saveLead() async {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead name and phone number are required.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final leadData = <String, dynamic>{
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'source': sourceController.text.trim(),
      'notes': notesController.text.trim(),
      'status': status,
      'priority': priority,
      'category': category,
      'customerId': customerId,
    };

    final error = await widget.onSave(leadData);

    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((item) {
          return DropdownMenuItem<T>(value: item, child: Text(item.toString()));
        }).toList(),
        onChanged: isSaving ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.data.isEmpty ? 'Add New Lead' : 'Edit Lead'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(nameController, 'Lead Name', Icons.person_outline),
              _textField(
                phoneController,
                'Phone Number',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              _textField(
                emailController,
                'Email Address',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              _textField(
                sourceController,
                'Lead Source',
                Icons.campaign_outlined,
              ),
              _textField(notesController, 'Notes', Icons.notes, maxLines: 3),

              _dropdown<String>(
                label: 'Lead Status',
                value: status,
                items: statuses,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => status = value);
                  }
                },
              ),

              _dropdown<String>(
                label: 'Priority',
                value: priority,
                items: priorities,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => priority = value);
                  }
                },
              ),

              _dropdown<String>(
                label: 'Category',
                value: category,
                items: categories,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => category = value);
                  }
                },
              ),

              DropdownButtonFormField<String?>(
                initialValue: customerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Link Existing Customer (Optional)',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No customer linked'),
                  ),
                  ...widget.customers.map(
                    (customer) => DropdownMenuItem<String?>(
                      value: customer.id,
                      child: Text(
                        customer.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: isSaving
                    ? null
                    : (value) {
                        setState(() {
                          customerId = value;
                        });
                      },
              ),

              if (widget.customers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No existing customers found. '
                    'You can still add this lead.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
          onPressed: isSaving ? null : saveLead,
          icon: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(isSaving ? 'Saving...' : 'Save Lead'),
        ),
      ],
    );
  }
}

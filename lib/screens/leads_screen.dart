
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
  final leads = FirebaseFirestore.instance.collection('leads');
  final customers = FirebaseFirestore.instance.collection('customers');
  final searchController = TextEditingController();

  String searchText = '';
  String selectedStatus = 'All';
  String selectedPriority = 'All';
  String selectedCategory = 'All';

  User? get user => FirebaseAuth.instance.currentUser;

  static const green = Color(0xFF00C853);
  static const muted = Color(0xFF9AA69D);
  static const card = Color(0xFF121A15);

  final statuses = [
    'All', 'New', 'Contacted', 'Qualified', 'Converted', 'Lost'
  ];
  final priorities = ['All', 'High', 'Medium', 'Low'];
  final categories = [
    'All', 'Business', 'Individual', 'Enterprise', 'Other'
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Color statusColor(String value) {
    switch (value) {
      case 'Converted':
        return green;
      case 'Qualified':
        return Colors.lightBlue;
      case 'Contacted':
        return Colors.orange;
      case 'Lost':
        return Colors.redAccent;
      default:
        return muted;
    }
  }

  Color priorityColor(String value) {
    switch (value) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      default:
        return green;
    }
  }

  Future<List<Customer>> loadCustomers() async {
    final current = user;
    if (current == null) return [];

    final result = await customers
        .where('userId', isEqualTo: current.uid)
        .get();

    return result.docs.map((doc) {
      return Customer.fromFirestore(doc);
    }).toList();
  }

  Future<void> showLeadDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final current = user;
    if (current == null) return;

    List<Customer> availableCustomers = [];

    try {
      availableCustomers = await loadCustomers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load customers: $error')),
      );
      return;
    }

    if (!mounted) return;

    final data = document?.data() ?? <String, dynamic>{};

    await showDialog<void>(
      context: context,
      builder: (_) => _LeadDialog(
        data: data,
        customers: availableCustomers,
        onSave: (leadData) async {
          try {
            leadData['updatedAt'] = FieldValue.serverTimestamp();

            final customerId = leadData['customerId'];
            if (customerId != null) {
              final linked = await customers.doc(customerId).get();
              if (!linked.exists ||
                  linked.data()?['userId'] != current.uid) {
                return 'The selected customer is not available.';
              }
              leadData['customerName'] =
                  linked.data()?['name'] ?? '';
              leadData['customerCompany'] =
                  linked.data()?['company'] ?? '';
            } else {
              leadData['customerName'] = '';
              leadData['customerCompany'] = '';
            }

            if (document == null) {
              leadData['userId'] = current.uid;
              leadData['createdAt'] = FieldValue.serverTimestamp();
              await leads.add(leadData);
            } else {
              final ref = leads.doc(document.id);
              final existing = await ref.get();

              if (!existing.exists ||
                  existing.data()?['userId'] != current.uid) {
                return 'You cannot edit a lead you do not own.';
              }

              await ref.update(leadData);
            }

            return null;
          } catch (error) {
            return 'Unable to save lead: $error';
          }
        },
      ),
    );
  }

  Future<void> deleteLead(String id) async {
    final current = user;
    if (current == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text('Delete Lead?'),
        content: const Text(
          'This lead will be permanently deleted.',
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

    if (confirm != true) return;

    try {
      final ref = leads.doc(id);
      final doc = await ref.get();

      if (!doc.exists || doc.data()?['userId'] != current.uid) {
        throw Exception('You cannot delete this lead.');
      }

      await ref.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Future<void> showLeadDetails(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data() ?? {};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: Text(
          (data['name'] ?? 'Lead Details').toString(),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detail('Phone', data['phone']),
              _detail('Email', data['email']),
              _detail('Source', data['source']),
              _detail('Status', data['status']),
              _detail('Priority', data['priority']),
              _detail('Category', data['category']),
              _detail('Linked Customer', data['customerName']),
              _detail('Notes', data['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _filter({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 145,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: card,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: muted),
          filled: true,
          fillColor: card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Widget _summary(String label, int value, IconData icon) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: green),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _leadCard(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    final name = (data['name'] ?? 'Unnamed Lead').toString();
    final phone = (data['phone'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final status = (data['status'] ?? 'New').toString();
    final priority = (data['priority'] ?? 'Medium').toString();
    final customerName = (data['customerName'] ?? '').toString();

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
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF69F0AE),
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
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
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(phone, style: const TextStyle(color: muted, fontSize: 12)),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _tag(status, statusColor(status)),
                    _tag('$priority Priority', priorityColor(priority)),
                    if (customerName.isNotEmpty)
                      _tag('Customer: $customerName', Colors.tealAccent),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: muted),
            color: card,
            onSelected: (value) {
              if (value == 'details') {
                showLeadDetails(document);
              } else if (value == 'edit') {
                showLeadDialog(document: document);
              } else if (value == 'delete') {
                deleteLead(document.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'details', child: Text('View details')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = user;
    if (current == null) {
      return const Center(child: Text('Please log in to view leads.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leads.where('userId', isEqualTo: current.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load leads: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: green),
          );
        }

        final documents = snapshot.data!.docs;

        int countStatus(String status) => documents
            .where((doc) => doc.data()['status'] == status)
            .length;

        final query = searchText.toLowerCase().trim();

        final filtered = documents.where((doc) {
          final data = doc.data();
          final matchesSearch =
              (data['name'] ?? '').toString().toLowerCase().contains(query) ||
              (data['phone'] ?? '').toString().contains(searchText.trim()) ||
              (data['email'] ?? '').toString().toLowerCase().contains(query);

          return matchesSearch &&
              (selectedStatus == 'All' || data['status'] == selectedStatus) &&
              (selectedPriority == 'All' || data['priority'] == selectedPriority) &&
              (selectedCategory == 'All' || data['category'] == selectedCategory);
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track, organize and convert potential customers.',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _summary('Total Leads', documents.length, Icons.groups_outlined),
                      _summary('New', countStatus('New'), Icons.person_add_alt),
                      _summary('Qualified', countStatus('Qualified'), Icons.verified_outlined),
                      _summary('Converted', countStatus('Converted'), Icons.check_circle_outline),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => searchText = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search leads by name, phone or email...',
                      hintStyle: const TextStyle(color: muted, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: green),
                      filled: true,
                      fillColor: card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showLeadDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Lead'),
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _filter(
                        label: 'Status',
                        value: selectedStatus,
                        options: statuses,
                        onChanged: (value) => setState(() => selectedStatus = value),
                      ),
                      _filter(
                        label: 'Priority',
                        value: selectedPriority,
                        options: priorities,
                        onChanged: (value) => setState(() => selectedPriority = value),
                      ),
                      _filter(
                        label: 'Category',
                        value: selectedCategory,
                        options: categories,
                        onChanged: (value) => setState(() => selectedCategory = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'All Leads',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text('${filtered.length} records',
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: Center(
                        child: Text(
                          'No leads found. Add a lead or adjust your filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ),
                    )
                  else
                    ...filtered.map(_leadCard),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LeadDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Customer> customers;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  const _LeadDialog({
    required this.data,
    required this.customers,
    required this.onSave,
  });

  @override
  State<_LeadDialog> createState() => _LeadDialogState();
}

class _LeadDialogState extends State<_LeadDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController sourceController;
  late final TextEditingController notesController;

  late String status;
  late String priority;
  late String category;

  String? customerId;
  bool saving = false;

  final statuses = ['New', 'Contacted', 'Qualified', 'Converted', 'Lost'];
  final priorities = ['High', 'Medium', 'Low'];
  final categories = ['Business', 'Individual', 'Enterprise', 'Other'];

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    nameController = TextEditingController(text: data['name'] ?? '');
    phoneController = TextEditingController(text: data['phone'] ?? '');
    emailController = TextEditingController(text: data['email'] ?? '');
    sourceController = TextEditingController(text: data['source'] ?? '');
    notesController = TextEditingController(text: data['notes'] ?? '');

    status = statuses.contains(data['status']) ? data['status'] : 'New';
    priority = priorities.contains(data['priority']) ? data['priority'] : 'Medium';
    category = categories.contains(data['category']) ? data['category'] : 'Business';

    customerId = data['customerId']?.toString();
    if (customerId != null &&
        !widget.customers.any((customer) => customer.id == customerId)) {
      customerId = null;
    }
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

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => saving = true);

    final error = await widget.onSave({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'source': sourceController.text.trim(),
      'notes': notesController.text.trim(),
      'status': status,
      'priority': priority,
      'category': category,
      'customerId': customerId,
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
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF00C853)),
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

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF1A241D),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF1A241D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: options.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: saving ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.data.isNotEmpty;

    return AlertDialog(
      backgroundColor: const Color(0xFF121A15),
      title: Text(
        editing ? 'Edit Lead' : 'Add New Lead',
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
                _field(nameController, 'Lead Name *', Icons.person_outline),
                _field(
                  phoneController,
                  'Phone Number',
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  emailController,
                  'Email Address',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(sourceController, 'Lead Source', Icons.campaign_outlined),
                _field(notesController, 'Notes', Icons.notes_outlined, maxLines: 3),
                _dropdown('Status', status, statuses, (value) {
                  if (value != null) setState(() => status = value);
                }),
                _dropdown('Priority', priority, priorities, (value) {
                  if (value != null) setState(() => priority = value);
                }),
                _dropdown('Category', category, categories, (value) {
                  if (value != null) setState(() => category = value);
                }),
                DropdownButtonFormField<String?>(
                  initialValue: customerId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A241D),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Link Existing Customer (Optional)',
                    filled: true,
                    fillColor: const Color(0xFF1A241D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No linked customer'),
                    ),
                    ...widget.customers.map((customer) {
                      return DropdownMenuItem<String?>(
                        value: customer.id,
                        child: Text(
                          customer.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => customerId = value),
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
            backgroundColor: const Color(0xFF00C853),
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
              : Text(editing ? 'Update Lead' : 'Save Lead'),
        ),
      ],
    );
  }
}

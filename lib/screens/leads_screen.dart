import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final CollectionReference<Map<String, dynamic>> collection =
      FirebaseFirestore.instance.collection('leads');

  final TextEditingController searchController = TextEditingController();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String searchText = '';
  String selectedStatus = 'All';

  final List<String> statuses = [
    'All',
    'New',
    'Contacted',
    'Qualified',
    'Converted',
    'Lost',
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

  // ADD / EDIT LEAD
  Future<void> showLeadDialog({
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final user = currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to manage leads.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _LeadDialog(
          id: id,
          data: data,
          onSave: (lead) async {
            try {
              lead['updatedAt'] = FieldValue.serverTimestamp();

              if (id == null) {
                // Assign new lead to the logged-in user.
                lead['userId'] = user.uid;
                lead['createdAt'] = FieldValue.serverTimestamp();

                await collection.add(lead);
              } else {
                // Verify ownership before editing.
                final existingLead = await collection.doc(id).get();

                if (!existingLead.exists ||
                    existingLead.data()?['userId'] != user.uid) {
                  return 'You cannot edit this lead because it does not belong to your account.';
                }

                // Do not change the existing userId.
                await collection.doc(id).update(lead);
              }

              return null;
            } catch (e) {
              return 'Error: $e';
            }
          },
        );
      },
    );
  }

  // DELETE LEAD
  Future<void> deleteLead(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('Delete Lead'),
          content: const Text(
            'Are you sure you want to delete this lead?',
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

    if (confirm == true) {
      try {
        final user = currentUser;

        if (user == null) return;

        // Verify ownership before deleting.
        final doc = await collection.doc(id).get();

        if (!doc.exists || doc.data()?['userId'] != user.uid) {
          throw Exception('You cannot delete this lead.');
        }

        await collection.doc(id).delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead deleted successfully'),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to delete lead: $e'),
          ),
        );
      }
    }
  }

  // SUMMARY CARD
  Widget summaryCard(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: 165,
      child: Card(
        color: colors.surface,
        surfaceTintColor: colors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                count.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MAIN SCREEN
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please log in to view leads.'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Only show leads belonging to the logged-in user.
      stream: collection
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load leads: ${snapshot.error}',
              style: TextStyle(color: colors.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // COUNT LEADS BY STATUS
        int count(String status) {
          return docs.where((doc) {
            return doc.data()['status'] == status;
          }).length;
        }

        // SEARCH AND FILTER
        final filtered = docs.where((doc) {
          final data = doc.data();
          final query = searchText.toLowerCase();

          final matches =
              (data['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query) ||
              (data['phone'] ?? '')
                  .toString()
                  .contains(searchText) ||
              (data['email'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query);

          return matches &&
              (selectedStatus == 'All' ||
                  data['status'] == selectedStatus);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PAGE TITLE
            Text(
              'Leads Management',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Track, organize and convert your potential customers.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 18),

            // SUMMARY CARDS
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                summaryCard(
                  context,
                  'Total Leads',
                  docs.length,
                  Icons.people_outline,
                  Colors.blue,
                ),
                summaryCard(
                  context,
                  'New Leads',
                  count('New'),
                  Icons.person_add_alt,
                  Colors.orange,
                ),
                summaryCard(
                  context,
                  'Contacted',
                  count('Contacted'),
                  Icons.call,
                  Colors.deepOrange,
                ),
                summaryCard(
                  context,
                  'Qualified',
                  count('Qualified'),
                  Icons.verified,
                  Colors.indigo,
                ),
                summaryCard(
                  context,
                  'Converted',
                  count('Converted'),
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // SEARCH AND ADD LEAD
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
                    style: TextStyle(
                      color: colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search leads...',
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

                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: () => showLeadDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Lead'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // STATUS FILTERS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((status) {
                  final selected = selectedStatus == status;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: selected,
                      selectedColor: colors.primaryContainer,
                      backgroundColor:
                          colors.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedStatus = status;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // LEAD LIST
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 52,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No leads found',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();

                        final status =
                            (data['status'] ?? 'New').toString();

                        final color = statusColor(status);

                        final leadName =
                            (data['name'] ?? '').toString();

                        return Card(
                          color: colors.surface,
                          surfaceTintColor: colors.surfaceTint,
                          margin: const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.all(14),

                            // LEAD AVATAR
                            leading: CircleAvatar(
                              backgroundColor:
                                  colors.primaryContainer,
                              child: Text(
                                leadName.isNotEmpty
                                    ? leadName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),

                            // LEAD NAME
                            title: Text(
                              leadName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // LEAD DETAILS
                            subtitle: Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phone: ${data['phone'] ?? ''}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Email: ${data['email'] ?? ''}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Source: ${data['source'] ?? ''}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            isThreeLine: true,

                            // EDIT / DELETE MENU
                            trailing: PopupMenuButton<String>(
                              iconColor: colors.onSurfaceVariant,
                              onSelected: (value) {
                                if (value == 'edit') {
                                  showLeadDialog(
                                    id: doc.id,
                                    data: data,
                                  );
                                } else if (value == 'delete') {
                                  deleteLead(doc.id);
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================
// ADD / EDIT LEAD DIALOG
// =====================================================

class _LeadDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;

  final Future<String?> Function(
    Map<String, dynamic> lead,
  ) onSave;

  const _LeadDialog({
    this.id,
    this.data,
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

  late String status;

  bool isSaving = false;

  final List<String> statuses = [
    'New',
    'Contacted',
    'Qualified',
    'Converted',
    'Lost',
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.data;

    nameController = TextEditingController(
      text: data?['name'] ?? '',
    );

    phoneController = TextEditingController(
      text: data?['phone'] ?? '',
    );

    emailController = TextEditingController(
      text: data?['email'] ?? '',
    );

    sourceController = TextEditingController(
      text: data?['source'] ?? '',
    );

    status = data?['status'] ?? 'New';

    if (!statuses.contains(status)) {
      status = 'New';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    sourceController.dispose();

    super.dispose();
  }

  // SAVE LEAD
  Future<void> saveLead() async {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lead name and phone are required',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final lead = <String, dynamic>{
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'source': sourceController.text.trim(),
      'status': status,
    };

    final error = await widget.onSave(lead);

    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
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
        widget.id == null ? 'Add New Lead' : 'Edit Lead',
        style: TextStyle(
          color: colors.onSurface,
        ),
      ),

      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // NAME
              TextField(
                controller: nameController,
                style: TextStyle(
                  color: colors.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Lead Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              // PHONE
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: colors.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              // EMAIL
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  color: colors.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              // SOURCE
              TextField(
                controller: sourceController,
                style: TextStyle(
                  color: colors.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Lead Source',
                  prefixIcon: Icon(Icons.source_outlined),
                ),
              ),

              const SizedBox(height: 12),

              // STATUS
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Lead Status',
                  border: OutlineInputBorder(),
                ),
                items: statuses.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            status = value;
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),

      // DIALOG ACTIONS
      actions: [
        TextButton(
          onPressed: isSaving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: isSaving ? null : saveLead,
          child: isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.id == null
                      ? 'Add Lead'
                      : 'Update Lead',
                ),
        ),
      ],
    );
  }
}
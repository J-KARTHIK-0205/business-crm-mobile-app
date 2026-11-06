import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final collection = FirebaseFirestore.instance.collection('leads');
  final searchController = TextEditingController();

  String searchText = '';
  String selectedStatus = 'All';

  final statuses = ['All', 'New', 'Contacted', 'Qualified', 'Converted', 'Lost'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Contacted': return Colors.orange;
      case 'Qualified': return Colors.blue;
      case 'Converted': return Colors.green;
      case 'Lost': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> showLeadDialog({String? id, Map<String, dynamic>? data}) async {
    final name = TextEditingController(text: data?['name'] ?? '');
    final phone = TextEditingController(text: data?['phone'] ?? '');
    final email = TextEditingController(text: data?['email'] ?? '');
    final source = TextEditingController(text: data?['source'] ?? '');
    String status = data?['status'] ?? 'New';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(id == null ? 'Add New Lead' : 'Edit Lead'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Lead Name')),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address')),
                  TextField(controller: source, decoration: const InputDecoration(labelText: 'Lead Source')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Lead Status', border: OutlineInputBorder()),
                    items: statuses.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead name and phone are required')),
                  );
                  return;
                }

                final lead = {
                  'name': name.text.trim(),
                  'phone': phone.text.trim(),
                  'email': email.text.trim(),
                  'source': source.text.trim(),
                  'status': status,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  if (id == null) {
                    lead['createdAt'] = FieldValue.serverTimestamp();
                    await collection.add(lead);
                  } else {
                    await collection.doc(id).update(lead);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(id == null ? 'Add Lead' : 'Update Lead'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    phone.dispose();
    email.dispose();
    source.dispose();
  }

  Future<void> deleteLead(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: const Text('Are you sure you want to delete this lead?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) await collection.doc(id).delete();
  }

  Widget summaryCard(String title, int count, IconData icon, Color color) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 165,
      child: Card(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(count.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Unable to load leads: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        int count(String status) => docs.where((d) => d.data()['status'] == status).length;

        final filtered = docs.where((doc) {
          final d = doc.data();
          final q = searchText.toLowerCase();
          final matches = (d['name'] ?? '').toString().toLowerCase().contains(q) ||
              (d['phone'] ?? '').toString().contains(searchText) ||
              (d['email'] ?? '').toString().toLowerCase().contains(q);
          return matches && (selectedStatus == 'All' || d['status'] == selectedStatus);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leads Management', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Track, organize and convert your potential customers.', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                summaryCard('Total Leads', docs.length, Icons.people_outline, Colors.blue),
                summaryCard('New Leads', count('New'), Icons.person_add_alt, Colors.orange),
                summaryCard('Contacted', count('Contacted'), Icons.call, Colors.deepOrange),
                summaryCard('Qualified', count('Qualified'), Icons.verified, Colors.indigo),
                summaryCard('Converted', count('Converted'), Icons.check_circle, Colors.green),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (v) => setState(() => searchText = v),
                    decoration: InputDecoration(
                      hintText: 'Search leads...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: selectedStatus == s,
                    onSelected: (_) => setState(() => selectedStatus = s),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No leads found'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final d = doc.data();
                        final status = (d['status'] ?? 'New').toString();
                        final color = statusColor(status);

                        return Card(
                          color: colors.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: colors.primaryContainer,
                              child: Text(
                                (d['name'] ?? '?').toString().isNotEmpty
                                    ? (d['name'] ?? '?').toString()[0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: colors.onPrimaryContainer),
                              ),
                            ),
                            title: Text((d['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Phone: ${d['phone'] ?? ''}'),
                                  Text('Email: ${d['email'] ?? ''}'),
                                  Text('Source: ${d['source'] ?? ''}'),
                                  const SizedBox(height: 6),
                                  Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') showLeadDialog(id: doc.id, data: d);
                                if (v == 'delete') deleteLead(doc.id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
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
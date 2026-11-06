import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final collection = FirebaseFirestore.instance.collection('customers');
  final searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> showCustomerDialog({String? id, Map<String, dynamic>? data}) async {
    final name = TextEditingController(text: data?['name'] ?? '');
    final phone = TextEditingController(text: data?['phone'] ?? '');
    final email = TextEditingController(text: data?['email'] ?? '');
    final company = TextEditingController(text: data?['company'] ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(id == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer Name')),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'Company')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and phone number are required')),
                );
                return;
              }

              final customer = {
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'email': email.text.trim(),
                'company': company.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              try {
                if (id == null) {
                  customer['createdAt'] = FieldValue.serverTimestamp();
                  await collection.add(customer);
                } else {
                  await collection.doc(id).update(customer);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(id == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );

    name.dispose();
    phone.dispose();
    email.dispose();
    company.dispose();
  }

  Future<void> deleteCustomer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
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

    if (confirm == true) {
      await collection.doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customers Management', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Manage and organize all your business customers.', style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: (v) => setState(() => searchText = v),
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => showCustomerDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            color: colors.surface,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: collection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final customers = snapshot.data!.docs.where((doc) {
                  final d = doc.data();
                  final q = searchText.toLowerCase();
                  return (d['name'] ?? '').toString().toLowerCase().contains(q) ||
                      (d['phone'] ?? '').toString().contains(searchText) ||
                      (d['email'] ?? '').toString().toLowerCase().contains(q) ||
                      (d['company'] ?? '').toString().toLowerCase().contains(q);
                }).toList();

                if (customers.isEmpty) return const Center(child: Text('No customers found'));

                return ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = customers[index];
                    final d = doc.data();
                    final name = (d['name'] ?? '').toString();

                    return ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: TextStyle(color: colors.onPrimaryContainer)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${d['company'] ?? ''}\n${d['phone'] ?? ''}\n${d['email'] ?? ''}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') showCustomerDialog(id: doc.id, data: d);
                          if (v == 'delete') deleteCustomer(doc.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final collection = FirebaseFirestore.instance.collection('tasks');
  final searchController = TextEditingController();

  String searchText = '';
  String selectedStatus = 'All';

  final statuses = ['All', 'Pending', 'In Progress', 'Completed'];
  final priorities = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> showTaskDialog({String? id, Map<String, dynamic>? data}) async {
    final title = TextEditingController(text: data?['title'] ?? '');
    final description = TextEditingController(text: data?['description'] ?? '');

    DateTime dueDate = DateTime.now();
    if (data?['dueDate'] is Timestamp) {
      dueDate = (data!['dueDate'] as Timestamp).toDate();
    }

    String priority = data?['priority'] ?? 'Medium';
    String status = data?['status'] ?? 'Pending';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(id == null ? 'Add Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Task Title')),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                    items: priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => priority = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: statuses.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Due Date'),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: ctx,
                          initialDate: dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() => dueDate = selected);
                        }
                      },
                      child: const Text('Choose'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task title is required')),
                  );
                  return;
                }

                final task = {
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'priority': priority,
                  'status': status,
                  'dueDate': Timestamp.fromDate(dueDate),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  if (id == null) {
                    task['createdAt'] = FieldValue.serverTimestamp();
                    await collection.add(task);
                  } else {
                    await collection.doc(id).update(task);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving task: $e')),
                    );
                  }
                }
              },
              child: Text(id == null ? 'Add Task' : 'Update Task'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    description.dispose();
  }

  Future<void> deleteTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
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

  Color priorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading tasks: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        final filtered = docs.where((doc) {
          final d = doc.data();
          final q = searchText.toLowerCase();
          final matches = (d['title'] ?? '').toString().toLowerCase().contains(q) ||
              (d['description'] ?? '').toString().toLowerCase().contains(q);
          return matches && (selectedStatus == 'All' || d['status'] == selectedStatus);
        }).toList();

        int count(String status) => docs.where((d) => d.data()['status'] == status).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tasks Management', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Create, assign and track your business tasks.', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _summary('Total Tasks', docs.length, Colors.blue),
                _summary('Pending', count('Pending'), Colors.orange),
                _summary('In Progress', count('In Progress'), Colors.indigo),
                _summary('Completed', count('Completed'), Colors.green),
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
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => showTaskDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
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
                  ? const Center(child: Text('No tasks found'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final d = doc.data();
                        final priority = (d['priority'] ?? 'Medium').toString();
                        final due = d['dueDate'] is Timestamp
                            ? (d['dueDate'] as Timestamp).toDate()
                            : null;

                        return Card(
                          color: colors.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: colors.primaryContainer,
                              child: Icon(Icons.task_alt, color: colors.onPrimaryContainer),
                            ),
                            title: Text((d['title'] ?? '').toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((d['description'] ?? '').toString()),
                                  const SizedBox(height: 5),
                                  Text('Priority: $priority',
                                      style: TextStyle(color: priorityColor(priority), fontWeight: FontWeight.bold)),
                                  Text('Status: ${d['status'] ?? 'Pending'}'),
                                  if (due != null) Text('Due: ${due.day}/${due.month}/${due.year}'),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') showTaskDialog(id: doc.id, data: d);
                                if (v == 'delete') deleteTask(doc.id);
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

  Widget _summary(String title, int count, Color color) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Card(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.assignment_outlined, color: color),
              const SizedBox(height: 8),
              Text('$count', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
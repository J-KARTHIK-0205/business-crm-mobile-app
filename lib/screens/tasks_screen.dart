
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final collection = FirebaseFirestore.instance.collection('tasks');
  final searchController = TextEditingController();

  User? get user => FirebaseAuth.instance.currentUser;

  String searchText = '';
  String selectedStatus = 'All';

  static const green = Color(0xFF00C853);
  static const muted = Color(0xFF9AA69D);
  static const card = Color(0xFF121A15);

  final statuses = ['All', 'Pending', 'In Progress', 'Completed'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Color priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      default:
        return green;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Completed':
        return green;
      case 'In Progress':
        return Colors.lightBlue;
      default:
        return Colors.orange;
    }
  }

  Future<void> showTaskDialog({
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final current = user;
    if (current == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _TaskDialog(
        id: id,
        data: data ?? {},
        onSave: (task) async {
          try {
            task['updatedAt'] = FieldValue.serverTimestamp();

            if (id == null) {
              task['userId'] = current.uid;
              task['createdAt'] = FieldValue.serverTimestamp();
              await collection.add(task);
            } else {
              final ref = collection.doc(id);
              final existing = await ref.get();

              if (!existing.exists ||
                  existing.data()?['userId'] != current.uid) {
                return 'You cannot edit this task.';
              }

              await ref.update(task);
            }

            return null;
          } catch (error) {
            return 'Unable to save task: $error';
          }
        },
      ),
    );
  }

  Future<void> deleteTask(String id) async {
    final current = user;
    if (current == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final ref = collection.doc(id);
      final document = await ref.get();

      if (!document.exists ||
          document.data()?['userId'] != current.uid) {
        throw Exception('You cannot delete this task.');
      }

      await ref.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Widget _summary(String title, int value, IconData icon) {
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
          const SizedBox(height: 9),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _taskCard(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    final title = (data['title'] ?? 'Untitled Task').toString();
    final description = (data['description'] ?? '').toString();
    final priority = (data['priority'] ?? 'Medium').toString();
    final status = (data['status'] ?? 'Pending').toString();

    final dueDate = data['dueDate'] is Timestamp
        ? (data['dueDate'] as Timestamp).toDate()
        : null;

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
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.task_alt, color: Color(0xFF69F0AE)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _tag(priority, priorityColor(priority)),
                    _tag(status, statusColor(status)),
                  ],
                ),
                if (dueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: muted,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Due ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: card,
            icon: const Icon(Icons.more_vert, color: muted),
            onSelected: (value) {
              if (value == 'edit') {
                showTaskDialog(id: document.id, data: data);
              } else if (value == 'delete') {
                deleteTask(document.id);
              }
            },
            itemBuilder: (_) => const [
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
      return const Center(child: Text('Please log in to view tasks.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: collection
          .where('userId', isEqualTo: current.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load tasks: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: green),
          );
        }

        final documents = snapshot.data!.docs;

        int countStatus(String value) => documents
            .where((doc) => doc.data()['status'] == value)
            .length;

        final query = searchText.toLowerCase().trim();

        final filtered = documents.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final description =
              (data['description'] ?? '').toString().toLowerCase();

          return (title.contains(query) || description.contains(query)) &&
              (selectedStatus == 'All' || data['status'] == selectedStatus);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tasks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create, organize and track your business tasks.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _summary('Total Tasks', documents.length, Icons.assignment_outlined),
                  _summary('Pending', countStatus('Pending'), Icons.pending_actions),
                  _summary('In Progress', countStatus('In Progress'), Icons.timelapse),
                  _summary('Completed', countStatus('Completed'), Icons.task_alt),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: searchController,
                onChanged: (value) => setState(() => searchText = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
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
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showTaskDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Task'),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                        selectedColor: green,
                        backgroundColor: card,
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          setState(() => selectedStatus = status);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'All Tasks',
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
                      'No tasks found. Add a task or change your filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              else
                ...filtered.map(_taskCard),
            ],
          ),
        );
      },
    );
  }
}

class _TaskDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic> data;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  const _TaskDialog({
    required this.id,
    required this.data,
    required this.onSave,
  });

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  late String priority;
  late String status;
  late DateTime dueDate;

  bool saving = false;

  final priorities = ['Low', 'Medium', 'High'];
  final statuses = ['Pending', 'In Progress', 'Completed'];

  static const green = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.data['title'] ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.data['description'] ?? '',
    );

    priority = priorities.contains(widget.data['priority'])
        ? widget.data['priority']
        : 'Medium';

    status = statuses.contains(widget.data['status'])
        ? widget.data['status']
        : 'Pending';

    dueDate = widget.data['dueDate'] is Timestamp
        ? (widget.data['dueDate'] as Timestamp).toDate()
        : DateTime.now();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() => dueDate = selected);
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => saving = true);

    final error = await widget.onSave({
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'priority': priority,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
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

  Widget dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
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
        items: options.map((option) {
          return DropdownMenuItem(value: option, child: Text(option));
        }).toList(),
        onChanged: saving ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF121A15),
      title: Text(
        editing ? 'Edit Task' : 'Add New Task',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Task title is required.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Task Title *',
                    prefixIcon: Icon(Icons.assignment_outlined),
                  ),
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 13),
                dropdown('Priority', priority, priorities, (value) {
                  if (value != null) setState(() => priority = value);
                }),
                dropdown('Status', status, statuses, (value) {
                  if (value != null) setState(() => status = value);
                }),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: green),
                  title: const Text(
                    'Due Date',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                    style: const TextStyle(color: Color(0xFF9AA69D)),
                  ),
                  trailing: TextButton(
                    onPressed: saving ? null : chooseDate,
                    child: const Text('Change'),
                  ),
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
            backgroundColor: green,
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
              : Text(editing ? 'Update Task' : 'Save Task'),
        ),
      ],
    );
  }
}

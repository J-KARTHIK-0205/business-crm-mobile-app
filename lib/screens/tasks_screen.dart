import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final CollectionReference<Map<String, dynamic>> collection =
      FirebaseFirestore.instance.collection('tasks');

  final TextEditingController searchController =
      TextEditingController();

  // Currently logged-in Firebase user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String searchText = '';
  String selectedStatus = 'All';

  final List<String> statuses = [
    'All',
    'Pending',
    'In Progress',
    'Completed',
  ];

  final List<String> priorities = [
    'Low',
    'Medium',
    'High',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  // STATUS COLORS
  Color taskStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  // ADD / EDIT TASK
  Future<void> showTaskDialog({
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final user = currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to manage tasks.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TaskDialog(
          id: id,
          data: data,
          onSave: (task) async {
            try {
              task['updatedAt'] =
                  FieldValue.serverTimestamp();

              if (id == null) {
                // Assign new task to the logged-in user.
                task['userId'] = user.uid;
                task['createdAt'] =
                    FieldValue.serverTimestamp();

                await collection.add(task);
              } else {
                // Verify ownership before editing.
                final existingTask =
                    await collection.doc(id).get();

                if (!existingTask.exists ||
                    existingTask.data()?['userId'] != user.uid) {
                  return 'You cannot edit this task.';
                }

                // Do not change the existing userId.
                await collection.doc(id).update(task);
              }

              return null;
            } catch (e) {
              return 'Error saving task: $e';
            }
          },
        );
      },
    );
  }

  // DELETE TASK
  Future<void> deleteTask(String id) async {
    final colors = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColors =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: const Text('Delete Task'),
          content: const Text(
            'Are you sure you want to delete this task?',
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

        if (user == null) {
          throw Exception('Please log in first.');
        }

        // Verify task ownership before deleting.
        final taskDoc = await collection.doc(id).get();

        if (!taskDoc.exists ||
            taskDoc.data()?['userId'] != user.uid) {
          throw Exception('You cannot delete this task.');
        }

        await collection.doc(id).delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully'),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting task: $e'),
            backgroundColor: colors.error,
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
    Color color,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: 160,
      child: Card(
        color: colors.surface,
        surfaceTintColor: colors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.assignment_outlined,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
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
        child: Text('Please log in to view tasks.'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Load only tasks belonging to the logged-in user.
      stream: collection
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading tasks: ${snapshot.error}',
              style: TextStyle(
                color: colors.error,
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

        final docs = snapshot.data?.docs ?? [];

        // FILTER TASKS
        final filtered = docs.where((doc) {
          final data = doc.data();
          final query = searchText.toLowerCase();

          final matches =
              (data['title'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query) ||
              (data['description'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query);

          return matches &&
              (selectedStatus == 'All' ||
                  data['status'] == selectedStatus);
        }).toList();

        // COUNT TASKS
        int count(String status) {
          return docs.where((doc) {
            return doc.data()['status'] == status;
          }).length;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PAGE TITLE
            Text(
              'Tasks Management',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Create, assign and track your business tasks.',
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
                  'Total Tasks',
                  docs.length,
                  Colors.blue,
                ),
                summaryCard(
                  context,
                  'Pending',
                  count('Pending'),
                  Colors.orange,
                ),
                summaryCard(
                  context,
                  'In Progress',
                  count('In Progress'),
                  Colors.indigo,
                ),
                summaryCard(
                  context,
                  'Completed',
                  count('Completed'),
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // SEARCH AND ADD TASK
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
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colors.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor:
                          colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
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
                  onPressed: () => showTaskDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // STATUS FILTERS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((status) {
                  final isSelected =
                      selectedStatus == status;

                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 8,
                    ),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor:
                          colors.primaryContainer,
                      backgroundColor:
                          colors.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected
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

            // TASK LIST
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_outlined,
                            size: 52,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No tasks found',
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

                        final title =
                            (data['title'] ?? '').toString();

                        final description =
                            (data['description'] ?? '')
                                .toString();

                        final priority =
                            (data['priority'] ?? 'Medium')
                                .toString();

                        final status =
                            (data['status'] ?? 'Pending')
                                .toString();

                        final dueDate =
                            data['dueDate'] is Timestamp
                                ? (data['dueDate'] as Timestamp)
                                    .toDate()
                                : null;

                        return Card(
                          color: colors.surface,
                          surfaceTintColor: colors.surfaceTint,
                          margin: const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.all(14),

                            // TASK ICON
                            leading: CircleAvatar(
                              backgroundColor:
                                  colors.primaryContainer,
                              child: Icon(
                                Icons.task_alt,
                                color: colors.onPrimaryContainer,
                              ),
                            ),

                            // TASK TITLE
                            title: Text(
                              title,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),

                            // TASK DETAILS
                            subtitle: Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color:
                                          colors.onSurfaceVariant,
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  Text(
                                    'Priority: $priority',
                                    style: TextStyle(
                                      color:
                                          priorityColor(priority),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    'Status: $status',
                                    style: TextStyle(
                                      color:
                                          taskStatusColor(status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  if (dueDate != null)
                                    Text(
                                      'Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                      style: TextStyle(
                                        color:
                                            colors.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            isThreeLine: true,

                            // EDIT / DELETE MENU
                            trailing:
                                PopupMenuButton<String>(
                              iconColor:
                                  colors.onSurfaceVariant,
                              onSelected: (value) {
                                if (value == 'edit') {
                                  showTaskDialog(
                                    id: doc.id,
                                    data: data,
                                  );
                                } else if (value == 'delete') {
                                  deleteTask(doc.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                      ),
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
// ADD / EDIT TASK DIALOG
// Separate StatefulWidget for safe controller disposal.
// =====================================================

class _TaskDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;

  final Future<String?> Function(
    Map<String, dynamic> task,
  ) onSave;

  const _TaskDialog({
    this.id,
    this.data,
    required this.onSave,
  });

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  late DateTime dueDate;
  late String priority;
  late String status;

  bool isSaving = false;

  final List<String> priorities = [
    'Low',
    'Medium',
    'High',
  ];

  final List<String> statuses = [
    'Pending',
    'In Progress',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.data;

    titleController = TextEditingController(
      text: data?['title'] ?? '',
    );

    descriptionController = TextEditingController(
      text: data?['description'] ?? '',
    );

    dueDate = DateTime.now();

    if (data?['dueDate'] is Timestamp) {
      dueDate = (data!['dueDate'] as Timestamp).toDate();
    }

    priority = data?['priority'] ?? 'Medium';
    status = data?['status'] ?? 'Pending';

    if (!priorities.contains(priority)) {
      priority = 'Medium';
    }

    if (!statuses.contains(status)) {
      status = 'Pending';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  // SELECT DUE DATE
  Future<void> chooseDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        dueDate = selected;
      });
    }
  }

  // SAVE TASK
  Future<void> saveTask() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task title is required'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final task = <String, dynamic>{
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'priority': priority,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
    };

    final error = await widget.onSave(task);

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

  // DIALOG UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,

      title: Text(
        widget.id == null ? 'Add Task' : 'Edit Task',
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
              // TASK TITLE
              TextField(
                controller: titleController,
                style: TextStyle(
                  color: colors.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  prefixIcon: Icon(
                    Icons.assignment_outlined,
                  ),
                ),
              ),

              // DESCRIPTION
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: TextStyle(
                  color: colors.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(
                    Icons.description_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // PRIORITY
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(
                    Icons.flag_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: priorities.map((item) {
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
                            priority = value;
                          });
                        }
                      },
              ),

              const SizedBox(height: 12),

              // STATUS
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(
                    Icons.check_circle_outline,
                  ),
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

              const SizedBox(height: 12),

              // DUE DATE
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_today,
                  color: colors.primary,
                ),
                title: Text(
                  'Due Date',
                  style: TextStyle(
                    color: colors.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                trailing: TextButton(
                  onPressed: isSaving ? null : chooseDueDate,
                  child: const Text('Choose'),
                ),
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
          onPressed: isSaving ? null : saveTask,
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
                      ? 'Add Task'
                      : 'Update Task',
                ),
        ),
      ],
    );
  }
}
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final searchController = TextEditingController();

  User? get user => FirebaseAuth.instance.currentUser;

  String searchText = '';
  String selectedStatus = 'All';

  bool isLoading = true;
  String? loadError;

  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> leads = [];
  List<Map<String, dynamic>> organizations = [];

  String? relationshipLoadError;

  static const green = Color(0xFF00C853);
  static const muted = Color(0xFF9AA69D);
  static const card = Color(0xFF121A15);

  final statuses = ['All', 'Pending', 'In Progress', 'Completed'];

  String get baseUrl {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost/business_crm_api/api';
    }

    return 'http://10.0.2.2/business_crm_api/api';
  }

  String get apiUrl => '$baseUrl/tasks/index.php';
  String get customersUrl => '$baseUrl/customers/index.php';
  String get leadsUrl => '$baseUrl/leads/index.php';
  String get organizationsUrl => '$baseUrl/organizations/index.php';

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> getHeaders() async {
    final current = user;

    if (current == null) {
      throw Exception('Please log in to continue.');
    }

    final token = await current.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase authentication token.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response from server.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Request failed (${response.statusCode}).',
      );
    }

    return decoded;
  }

  // Fetch customers, leads and organizations.
  Future<List<Map<String, dynamic>>> fetchRecords(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: await getHeaders())
        .timeout(const Duration(seconds: 20));

    final result = decodeResponse(response);
    final data = result['data'];

    if (data is! List) {
      throw Exception('The server returned an invalid records list.');
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> loadRelatedRecords() async {
    try {
      final results = await Future.wait([
        fetchRecords(customersUrl),
        fetchRecords(leadsUrl),
        fetchRecords(organizationsUrl),
      ]);

      if (!mounted) return;

      setState(() {
        customers = results[0];
        leads = results[1];
        organizations = results[2];
        relationshipLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        relationshipLoadError =
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // Fetch tasks from PHP API.
  Future<void> loadTasks() async {
    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Please log in to view tasks.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: await getHeaders())
          .timeout(const Duration(seconds: 20));

      final result = decodeResponse(response);
      final data = result['data'];

      if (data is! List) {
        throw Exception('The server returned an invalid tasks list.');
      }

      final loadedTasks = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        tasks = loadedTasks;
        isLoading = false;
        loadError = null;
      });

      await loadRelatedRecords();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // Add or update a task.
  Future<String?> saveTask(
    Map<String, dynamic> task, {
    String? id,
  }) async {
    try {
      final body = {
        'task_title': task['title'],
        'description': task['description'],
        'priority': task['priority'],
        'status': task['status'],
        'due_date': (task['dueDate'] as DateTime).toIso8601String(),
        'customer_id': task['customerId'],
        'lead_id': task['leadId'],
        'organization_id': task['organizationId'],
      };

      final headers = await getHeaders();

      final http.Response response;

      if (id == null) {
        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20));
      } else {
        response = await http
            .put(
              Uri.parse(apiUrl),
              headers: headers,
              body: jsonEncode({
                ...body,
                'id': int.parse(id),
              }),
            )
            .timeout(const Duration(seconds: 20));
      }

      decodeResponse(response);

      await loadTasks();

      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  // Delete a task.
  Future<void> deleteTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Delete Task?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this task?',
          style: TextStyle(color: muted),
        ),
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
      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {'id': id},
      );

      final response = await http
          .delete(uri, headers: await getHeaders())
          .timeout(const Duration(seconds: 20));

      decodeResponse(response);

      await loadTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  // Open Add/Edit Task dialog.
  Future<void> showTaskDialog({
    String? id,
    Map<String, dynamic>? data,
  }) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to manage tasks.'),
        ),
      );
      return;
    }

    if (customers.isEmpty && leads.isEmpty && organizations.isEmpty) {
      await loadRelatedRecords();
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _TaskDialog(
        id: id,
        data: data ?? {},
        customers: customers,
        leads: leads,
        organizations: organizations,
        relationshipLoadError: relationshipLoadError,
        onSave: (task) => saveTask(task, id: id),
      ),
    );
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
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
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

  // Find a linked record name using its database ID.
  String? relatedName(
    dynamic id,
    List<Map<String, dynamic>> records,
    String nameKey,
  ) {
    if (id == null) return null;

    for (final record in records) {
      if (record['id'].toString() == id.toString()) {
        return record[nameKey]?.toString();
      }
    }

    return null;
  }

  Widget _relationshipLine(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF69F0AE),
            size: 13,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Individual task card.
  Widget _taskCard(Map<String, dynamic> data) {
    final id = data['id'].toString();
    final title = (data['task_title'] ?? 'Untitled Task').toString();
    final description = (data['description'] ?? '').toString();
    final priority = (data['priority'] ?? 'Medium').toString();
    final status = (data['status'] ?? 'Pending').toString();

    final customerName =
        relatedName(data['customer_id'], customers, 'customer_name');

    // Leads API returns lead_name using the JSON key "name".
    final leadName =
        relatedName(data['lead_id'], leads, 'name');

    final organizationName = relatedName(
      data['organization_id'],
      organizations,
      'organization_name',
    );

    DateTime? dueDate;
    final rawDate = data['due_date'];

    if (rawDate != null && rawDate.toString().isNotEmpty) {
      dueDate = DateTime.tryParse(rawDate.toString());
    }

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
            child: const Icon(
              Icons.task_alt,
              color: Color(0xFF69F0AE),
            ),
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
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
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
                if (customerName != null ||
                    leadName != null ||
                    organizationName != null) ...[
                  const SizedBox(height: 9),
                  if (customerName != null)
                    _relationshipLine(
                      Icons.person_outline,
                      customerName,
                    ),
                  if (leadName != null)
                    _relationshipLine(
                      Icons.track_changes,
                      leadName,
                    ),
                  if (organizationName != null)
                    _relationshipLine(
                      Icons.business_outlined,
                      organizationName,
                    ),
                ],
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
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: card,
            icon: const Icon(
              Icons.more_vert,
              color: muted,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                showTaskDialog(id: id, data: data);
              } else if (value == 'delete') {
                deleteTask(id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view tasks.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    if (loadError != null && tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 35,
              ),
              const SizedBox(height: 12),
              Text(
                loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: loadTasks,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    int countStatus(String value) =>
        tasks.where((task) => task['status'] == value).length;

    final query = searchText.toLowerCase().trim();

    final filtered = tasks.where((task) {
      final title =
          (task['task_title'] ?? '').toString().toLowerCase();

      final description =
          (task['description'] ?? '').toString().toLowerCase();

      return (title.contains(query) || description.contains(query)) &&
          (selectedStatus == 'All' ||
              task['status'] == selectedStatus);
    }).toList();

    return RefreshIndicator(
      color: green,
      onRefresh: loadTasks,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              style: TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),

            // Summary cards.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _summary(
                  'Total Tasks',
                  tasks.length,
                  Icons.assignment_outlined,
                ),
                _summary(
                  'Pending',
                  countStatus('Pending'),
                  Icons.pending_actions,
                ),
                _summary(
                  'In Progress',
                  countStatus('In Progress'),
                  Icons.timelapse,
                ),
                _summary(
                  'Completed',
                  countStatus('Completed'),
                  Icons.task_alt,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Search.
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() => searchText = value);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: green,
                ),
                filled: true,
                fillColor: card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 11),

            // Add task button.
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

            // Status filters.
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
                Text(
                  '${filtered.length} records',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
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
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD / EDIT TASK DIALOG
// -----------------------------------------------------------------------------

class _TaskDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic> data;

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> leads;
  final List<Map<String, dynamic>> organizations;

  final String? relationshipLoadError;

  final Future<String?> Function(Map<String, dynamic>) onSave;

  const _TaskDialog({
    required this.id,
    required this.data,
    required this.customers,
    required this.leads,
    required this.organizations,
    required this.relationshipLoadError,
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

  int? customerId;
  int? leadId;
  int? organizationId;

  bool saving = false;

  final priorities = ['Low', 'Medium', 'High'];
  final statuses = ['Pending', 'In Progress', 'Completed'];

  static const green = Color(0xFF00C853);

  int? _parseId(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  int? _validInitialId(
    dynamic value,
    List<Map<String, dynamic>> records,
  ) {
    final parsed = _parseId(value);

    if (parsed == null) return null;

    for (final record in records) {
      if (_parseId(record['id']) == parsed) {
        return parsed;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.data['task_title']?.toString() ?? '',
    );

    descriptionController = TextEditingController(
      text: widget.data['description']?.toString() ?? '',
    );

    final savedPriority = widget.data['priority']?.toString();

    priority = priorities.contains(savedPriority)
        ? savedPriority!
        : 'Medium';

    final savedStatus = widget.data['status']?.toString();

    status = statuses.contains(savedStatus)
        ? savedStatus!
        : 'Pending';

    final savedDate = widget.data['due_date']?.toString();

    dueDate = savedDate != null
        ? (DateTime.tryParse(savedDate) ?? DateTime.now())
        : DateTime.now();

    customerId = _validInitialId(
      widget.data['customer_id'],
      widget.customers,
    );

    leadId = _validInitialId(
      widget.data['lead_id'],
      widget.leads,
    );

    organizationId = _validInitialId(
      widget.data['organization_id'],
      widget.organizations,
    );
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
      'dueDate': dueDate,
      'customerId': customerId,
      'leadId': leadId,
      'organizationId': organizationId,
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
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: saving ? null : onChanged,
      ),
    );
  }

  // Customer / Lead / Organization dropdown.
  Widget relatedDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> records,
    required String nameKey,
    required ValueChanged<int?> onChanged,
  }) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('None'),
      ),
      ...records.map((record) {
        final recordId = int.tryParse(record['id'].toString());

        return DropdownMenuItem<int?>(
          value: recordId,
          child: Text(
            (record[nameKey] ?? 'Unnamed').toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).where((item) => item.value != null),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: DropdownButtonFormField<int?>(
        initialValue: value,
        isExpanded: true,
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
        items: items,
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
                  maxLength: 150,
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
                  if (value != null) {
                    setState(() => priority = value);
                  }
                }),

                dropdown('Status', status, statuses, (value) {
                  if (value != null) {
                    setState(() => status = value);
                  }
                }),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 9),
                    child: Text(
                      'Link this task (optional)',
                      style: TextStyle(
                        color: Color(0xFF69F0AE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                relatedDropdown(
                  label: 'Customer',
                  value: customerId,
                  records: widget.customers,
                  nameKey: 'customer_name',
                  onChanged: (value) {
                    setState(() => customerId = value);
                  },
                ),

                relatedDropdown(
                  label: 'Lead',
                  value: leadId,
                  records: widget.leads,
                  // Leads API uses "name" for lead_name.
                  nameKey: 'name',
                  onChanged: (value) {
                    setState(() => leadId = value);
                  },
                ),

                relatedDropdown(
                  label: 'Organization',
                  value: organizationId,
                  records: widget.organizations,
                  nameKey: 'organization_name',
                  onChanged: (value) {
                    setState(() => organizationId = value);
                  },
                ),

                if (widget.relationshipLoadError != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Some linked-record lists could not be loaded. '
                      'You can still save this task without linking records.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_month,
                    color: green,
                  ),
                  title: const Text(
                    'Due Date',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                    style: const TextStyle(
                      color: Color(0xFF9AA69D),
                    ),
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
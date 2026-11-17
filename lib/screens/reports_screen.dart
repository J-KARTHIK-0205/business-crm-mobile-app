
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const green = Color(0xFF00C853);
  static const accent = Color(0xFF69F0AE);
  static const background = Color(0xFF080C09);
  static const card = Color(0xFF121A15);
  static const muted = Color(0xFF9AA69D);

  bool get isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get pageBackground =>
      isDark ? background : const Color(0xFFF5F7FA);

  Color get cardBackground =>
      isDark ? card : Colors.white;

  Color get primaryText =>
      isDark ? Colors.white : const Color(0xFF17211B);

  Color get secondaryText =>
      isDark ? muted : const Color(0xFF65736A);

  Color get borderColor =>
      isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE1E8E3);

  Color get dividerColor =>
      isDark ? Colors.white12 : const Color(0xFFE5EAE7);

  Color get progressBackground =>
      isDark ? Colors.white12 : const Color(0xFFE5EAE7);

  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> leads = [];
  List<Map<String, dynamic>> organizations = [];
  List<Map<String, dynamic>> tasks = [];

  String get baseUrl {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost/business_crm_api/api';
    }

    return 'http://10.0.2.2/business_crm_api/api';
  }

  Map<String, String> get endpoints => {
        'customers': '$baseUrl/customers/index.php',
        'leads': '$baseUrl/leads/index.php',
        'organizations': '$baseUrl/organizations/index.php',
        'tasks': '$baseUrl/tasks/index.php',
      };

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  // -----------------------------------------------------
  // AUTHENTICATION HEADERS
  // -----------------------------------------------------

  Future<Map<String, String>> getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to view reports.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to generate Firebase authentication token.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // -----------------------------------------------------
  // NORMALIZE STATUS VALUES
  // -----------------------------------------------------

  String normalizeStatus(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  // -----------------------------------------------------
  // FETCH API RECORDS
  // -----------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchRecords(
    String url,
    Map<String, String> headers,
  ) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected server response.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'Unable to load report data.',
      );
    }

    final data = decoded['data'];

    if (data is! List) {
      throw Exception(
        'Invalid records received from the server.',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // -----------------------------------------------------
  // LOAD ALL REPORT DATA
  // -----------------------------------------------------

  Future<void> loadReports() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Please log in to view reports.';
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final headers = await getHeaders();

      final results = await Future.wait([
        fetchRecords(endpoints['customers']!, headers),
        fetchRecords(endpoints['leads']!, headers),
        fetchRecords(endpoints['organizations']!, headers),
        fetchRecords(endpoints['tasks']!, headers),
      ]);

      if (!mounted) return;

      setState(() {
        customers = results[0];
        leads = results[1];
        organizations = results[2];
        tasks = results[3];

        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // -----------------------------------------------------
  // LEAD STATISTICS
  // -----------------------------------------------------

  int leadCount(String status) {
    return leads.where((lead) {
      return normalizeStatus(lead['status']) ==
          normalizeStatus(status);
    }).length;
  }

  // -----------------------------------------------------
  // TASK STATISTICS
  // -----------------------------------------------------

  int taskCount(String status) {
    return tasks.where((task) {
      return normalizeStatus(task['status']) ==
          normalizeStatus(status);
    }).length;
  }

  int get completedTasks => taskCount('Completed');

  int get pendingTasks => taskCount('Pending');

  int get inProgressTasks => taskCount('In Progress');

  double get completionRate {
    if (tasks.isEmpty) return 0;

    return completedTasks / tasks.length;
  }

  // -----------------------------------------------------
  // STATISTICS CARD
  // -----------------------------------------------------

  Widget buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.13),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: TextStyle(
              color: primaryText,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        title,
        style: TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // LEAD STATUS ANALYSIS
  // -----------------------------------------------------

  Widget buildProgressItem(
    String title,
    int count,
    int total,
    Color color,
  ) {
    final progress = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: secondaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: progressBackground,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLeadChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Lead Status Analysis'),
          buildProgressItem(
            'New',
            leadCount('New'),
            leads.length,
            Colors.blue,
          ),
          buildProgressItem(
            'Contacted',
            leadCount('Contacted'),
            leads.length,
            Colors.orange,
          ),
          buildProgressItem(
            'Qualified',
            leadCount('Qualified'),
            leads.length,
            Colors.purple,
          ),
          buildProgressItem(
            'Converted',
            leadCount('Converted'),
            leads.length,
            green,
          ),
          buildProgressItem(
            'Lost',
            leadCount('Lost'),
            leads.length,
            Colors.redAccent,
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // TASK COMPLETION ANALYSIS
  // -----------------------------------------------------

  Widget buildTaskChart() {
    final percentage = (completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Task Completion Analysis'),
          Text(
            '$completedTasks of ${tasks.length} tasks completed',
            style: TextStyle(color: secondaryText),
          ),
          const SizedBox(height: 22),
          Center(
            child: SizedBox(
              width: 155,
              height: 155,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 145,
                    height: 145,
                    child: CircularProgressIndicator(
                      value: completionRate.clamp(0.0, 1.0),
                      strokeWidth: 13,
                      backgroundColor: progressBackground,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Completed',
                        style: TextStyle(color: secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          taskStatusRow('Completed', completedTasks, green),
          taskStatusRow('In Progress', inProgressTasks, Colors.blue),
          taskStatusRow('Pending', pendingTasks, Colors.orange),
        ],
      ),
    );
  }

  Widget taskStatusRow(
    String title,
    int count,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // BUSINESS SUMMARY
  // -----------------------------------------------------

  Widget summaryRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? accent : green,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBusinessSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Business Summary'),
          summaryRow(
            'Total Customers',
            '${customers.length}',
            Icons.people_outline,
          ),
          Divider(color: dividerColor),
          summaryRow(
            'Total Leads',
            '${leads.length}',
            Icons.person_search,
          ),
          Divider(color: dividerColor),
          summaryRow(
            'Total Organizations',
            '${organizations.length}',
            Icons.business_outlined,
          ),
          Divider(color: dividerColor),
          summaryRow(
            'Total Tasks',
            '${tasks.length}',
            Icons.task_alt,
          ),
          Divider(color: dividerColor),
          summaryRow(
            'Completed Tasks',
            '$completedTasks',
            Icons.check_circle_outline,
          ),
          Divider(color: dividerColor),
          summaryRow(
            'In Progress Tasks',
            '$inProgressTasks',
            Icons.timelapse,
          ),
          Divider(color: dividerColor),
          summaryRow(
            'Pending Tasks',
            '$pendingTasks',
            Icons.pending_actions,
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // MAIN SCREEN
  // -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Center(
        child: Text(
          'Please log in to view reports.',
          style: TextStyle(color: primaryText),
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 15),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: loadReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: pageBackground,
      child: RefreshIndicator(
        color: green,
        onRefresh: loadReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports & Analytics',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Monitor your business performance and activities.',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Overview',
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh reports',
                    onPressed: loadReports,
                    icon: Icon(
                      Icons.refresh,
                      color: isDark ? accent : green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Statistics cards.
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth > 850 ? 4 : 2;

                  return GridView.count(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    children: [
                      buildStatCard(
                        'Customers',
                        '${customers.length}',
                        Icons.people_outline,
                        Colors.blue,
                      ),
                      buildStatCard(
                        'Leads',
                        '${leads.length}',
                        Icons.person_search,
                        Colors.orange,
                      ),
                      buildStatCard(
                        'Organizations',
                        '${organizations.length}',
                        Icons.business_outlined,
                        Colors.purple,
                      ),
                      buildStatCard(
                        'Tasks',
                        '${tasks.length}',
                        Icons.task_alt,
                        green,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),

              // Analysis sections.
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 850) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: buildLeadChart()),
                        const SizedBox(width: 15),
                        Expanded(child: buildTaskChart()),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      buildLeadChart(),
                      const SizedBox(height: 16),
                      buildTaskChart(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              buildBusinessSummary(),
            ],
          ),
        ),
      ),
    );
  }
}

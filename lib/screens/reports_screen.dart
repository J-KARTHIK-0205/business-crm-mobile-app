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

  Future<Map<String, String>> getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to view reports.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to get Firebase authentication token.');
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> fetchRecords(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: await getHeaders(),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Unable to load report data.',
      );
    }

    final data = decoded['data'];

    if (data is! List) {
      throw Exception('Invalid records received from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> loadReports() async {
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please log in to view reports.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        fetchRecords(endpoints['customers']!),
        fetchRecords(endpoints['leads']!),
        fetchRecords(endpoints['organizations']!),
        fetchRecords(endpoints['tasks']!),
      ]);

      if (!mounted) return;

      setState(() {
        customers = results[0];
        leads = results[1];
        organizations = results[2];
        tasks = results[3];
        isLoading = false;
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

  int leadCount(String status) {
    return leads.where((lead) {
      return lead['status']?.toString() == status;
    }).length;
  }

  int taskCount(String status) {
    return tasks.where((task) {
      return task['status']?.toString() == status;
    }).length;
  }

  int get completedTasks => taskCount('Completed');

  int get pendingTasks => taskCount('Pending');

  int get inProgressTasks => taskCount('In Progress');

  double get completionRate {
    if (tasks.isEmpty) return 0;
    return completedTasks / tasks.length;
  }

  // ---------------------------------------------------------------------------
  // STATISTICS CARD
  // ---------------------------------------------------------------------------

  Widget buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
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

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LEAD STATUS ANALYSIS
  // ---------------------------------------------------------------------------

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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: muted,
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
              backgroundColor: Colors.white12,
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
        color: card,
        borderRadius: BorderRadius.circular(17),
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

  // ---------------------------------------------------------------------------
  // TASK COMPLETION ANALYSIS
  // ---------------------------------------------------------------------------

  Widget buildTaskChart() {
    final percentage = (completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Task Completion Analysis'),

          Text(
            '$completedTasks of ${tasks.length} tasks completed',
            style: const TextStyle(color: muted),
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
                      value: completionRate,
                      strokeWidth: 13,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Completed',
                        style: TextStyle(color: muted),
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

  Widget taskStatusRow(String title, int count, Color color) {
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
              style: const TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUSINESS SUMMARY
  // ---------------------------------------------------------------------------

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
            color: accent,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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
        color: card,
        borderRadius: BorderRadius.circular(17),
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
          const Divider(color: Colors.white12),
          summaryRow(
            'Total Leads',
            '${leads.length}',
            Icons.person_search,
          ),
          const Divider(color: Colors.white12),
          summaryRow(
            'Total Organizations',
            '${organizations.length}',
            Icons.business_outlined,
          ),
          const Divider(color: Colors.white12),
          summaryRow(
            'Total Tasks',
            '${tasks.length}',
            Icons.task_alt,
          ),
          const Divider(color: Colors.white12),
          summaryRow(
            'Completed Tasks',
            '$completedTasks',
            Icons.check_circle_outline,
          ),
          const Divider(color: Colors.white12),
          summaryRow(
            'In Progress Tasks',
            '$inProgressTasks',
            Icons.timelapse,
          ),
          const Divider(color: Colors.white12),
          summaryRow(
            'Pending Tasks',
            '$pendingTasks',
            Icons.pending_actions,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(
        child: Text(
          'Please log in to view reports.',
          style: TextStyle(color: Colors.white),
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
                style: const TextStyle(color: muted),
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

    return RefreshIndicator(
      color: green,
      onRefresh: loadReports,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports & Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Monitor your business performance and activities.',
              style: TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh reports',
                  onPressed: loadReports,
                  icon: const Icon(
                    Icons.refresh,
                    color: accent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Statistics cards.
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 850
                    ? 4
                    : constraints.maxWidth > 500
                        ? 2
                        : 2;

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
    );
  }
}
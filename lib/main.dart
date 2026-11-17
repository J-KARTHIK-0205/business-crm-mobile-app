
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';
import 'auth/auth_gate.dart';

import 'screens/customers_screen.dart';
import 'screens/organizations_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

// --------------------------------------------------
// FIREBASE INITIALIZATION
// --------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BusinessCRM());
}

// --------------------------------------------------
// MAIN APPLICATION WITH USER-SPECIFIC THEME
// --------------------------------------------------

class BusinessCRM extends StatelessWidget {
  const BusinessCRM({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return _buildMaterialApp(false);
        }

        final preferencesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences');

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: preferencesRef.snapshots(),
          builder: (context, snapshot) {
            final preferences =
                snapshot.data?.data() ?? <String, dynamic>{};

            final savedDarkMode = preferences['darkModeEnabled'];

            final bool isDarkMode = savedDarkMode is bool
                ? savedDarkMode
                : preferences['theme'] == 'Dark';

            return _buildMaterialApp(isDarkMode);
          },
        );
      },
    );
  }

  // --------------------------------------------------
  // APPLICATION THEMES
  // --------------------------------------------------

  Widget _buildMaterialApp(bool isDarkMode) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Business CRM',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
        ),
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111827),
        cardTheme: const CardThemeData(
          color: Color(0xFF1F2937),
          elevation: 1,
        ),
      ),

      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      home: AuthGate(
        authenticatedView: const DashboardScreen(),
      ),
    );
  }
}

// --------------------------------------------------
// DASHBOARD AND NAVIGATION
// --------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  // Organizations added between Customers and Leads.
  final List<String> menuTitles = [
    'Dashboard',
    'Customers',
    'Organizations',
    'Leads',
    'Tasks',
    'Reports',
    'Settings',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.business,
    Icons.person_search,
    Icons.task_alt,
    Icons.bar_chart,
    Icons.settings,
  ];

  void selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  // --------------------------------------------------
  // PAGE NAVIGATION
  // --------------------------------------------------

  Widget getCurrentPage() {
    switch (selectedIndex) {
      case 0:
        return const DashboardOverview();

      case 1:
        return const CustomersScreen();

      case 2:
        return const OrganizationsScreen();

      case 3:
        return const LeadsScreen();

      case 4:
        return const TasksScreen();

      case 5:
        return const ReportsScreen();

      case 6:
        return const SettingsScreen();

      default:
        return const Center(
          child: Text('Page Not Found'),
        );
    }
  }

  // --------------------------------------------------
  // SIDEBAR MENU
  // --------------------------------------------------

  Widget buildMenu(bool closeDrawer) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Column(
      children: [
        const SizedBox(height: 25),

        Text(
          'MAIN MENU',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        for (int i = 0; i < menuTitles.length; i++)
          ListTile(
            leading: Icon(
              menuIcons[i],
              color: selectedIndex == i
                  ? primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),

            title: Text(
              menuTitles[i],
              style: TextStyle(
                color: selectedIndex == i
                    ? primaryColor
                    : theme.colorScheme.onSurface,
                fontWeight: selectedIndex == i
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),

            selected: selectedIndex == i,

            selectedTileColor:
                theme.colorScheme.primaryContainer.withValues(
              alpha: 0.35,
            ),

            onTap: () {
              selectPage(i);

              if (closeDrawer) {
                Navigator.pop(context);
              }
            },
          ),
      ],
    );
  }

  // --------------------------------------------------
  // DASHBOARD LAYOUT
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        return Scaffold(
          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: buildMenu(true),
                  ),
                ),

          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,

            title: const Text(
              'Business CRM',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            actions: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications.'),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                ),
              ),

              const SizedBox(width: 10),

              CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 20),
            ],
          ),

          body: Row(
            children: [
              if (isWide)
                Container(
                  width: 220,
                  color: theme.colorScheme.surface,
                  child: buildMenu(false),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: getCurrentPage(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------
// DASHBOARD OVERVIEW - MYSQL / PHP API DATA
// --------------------------------------------------

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() =>
      _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  static const Color _blue = Colors.blue;
  static const Color _orange = Colors.orange;
  static const Color _green = Colors.green;
  static const Color _purple = Colors.purple;

  bool isLoading = true;
  String? loadError;

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> leads = [];
  List<Map<String, dynamic>> tasks = [];

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // --------------------------------------------------
  // API URLS
  // --------------------------------------------------

  String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost/business_crm_api/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/business_crm_api/api';
    }

    return 'http://localhost/business_crm_api/api';
  }

  String get customersApiUrl =>
      '$apiBaseUrl/customers/index.php';

  String get leadsApiUrl =>
      '$apiBaseUrl/leads/index.php';

  String get tasksApiUrl =>
      '$apiBaseUrl/tasks/index.php';

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  // --------------------------------------------------
  // AUTHENTICATION HEADERS
  // --------------------------------------------------

  Future<Map<String, String>> _getHeaders() async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'Please log in to view dashboard data.',
      );
    }

    final token = await user.getIdToken(true);

    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to get Firebase authentication token.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --------------------------------------------------
  // FETCH RECORDS FROM PHP API
  // --------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchRecords(
    String url,
  ) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: await _getHeaders(),
        )
        .timeout(const Duration(seconds: 20));

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'The server returned an invalid response '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Unexpected response from the CRM API.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        (decoded['message'] ??
                'Unable to load dashboard records.')
            .toString(),
      );
    }

    final data = decoded['data'];

    if (data is! List) {
      throw Exception(
        'The CRM API did not return a records list.',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // --------------------------------------------------
  // LOAD DASHBOARD DATA
  // --------------------------------------------------

  Future<void> loadDashboardData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final results = await Future.wait([
        _fetchRecords(customersApiUrl),
        _fetchRecords(leadsApiUrl),
        _fetchRecords(tasksApiUrl),
      ]);

      if (!mounted) return;

      setState(() {
        customers = results[0];
        leads = results[1];
        tasks = results[2];

        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        loadError = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  // --------------------------------------------------
  // STATISTICS CARD
  // --------------------------------------------------

  Widget statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: color,
              size: 30,
            ),

            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              title,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // RECENT ACTIVITY ITEM
  // --------------------------------------------------

  Widget activity(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 15,
      ),
    );
  }

  // --------------------------------------------------
  // DATE HANDLING
  // --------------------------------------------------

  DateTime _recordDate(Map<String, dynamic> data) {
    final rawDate = data['created_at'] ??
        data['createdAt'] ??
        data['updated_at'] ??
        data['updatedAt'];

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is DateTime) {
      return rawDate;
    }

    if (rawDate != null) {
      return DateTime.tryParse(rawDate.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // --------------------------------------------------
  // RECENT ACTIVITIES FROM MYSQL RECORDS
  // --------------------------------------------------

  List<Map<String, dynamic>> get recentActivities {
    final items = <Map<String, dynamic>>[];

    for (final customer in customers) {
      final name = customer['customer_name'] ??
          customer['name'] ??
          'Customer';

      items.add({
        'title': 'New customer added',
        'subtitle': name.toString(),
        'icon': Icons.person_add,
        'date': _recordDate(customer),
      });
    }

    for (final lead in leads) {
      final name = lead['lead_name'] ??
          lead['name'] ??
          'Lead';

      items.add({
        'title': 'New lead added',
        'subtitle': name.toString(),
        'icon': Icons.trending_up,
        'date': _recordDate(lead),
      });
    }

    for (final task in tasks) {
      final status = task['status'] ?? 'Updated';

      final title = task['title'] ??
          task['task_title'] ??
          'Task';

      items.add({
        'title': 'Task: $status',
        'subtitle': title.toString(),
        'icon': Icons.task_alt,
        'date': _recordDate(task),
      });
    }

    items.sort((a, b) {
      return (b['date'] as DateTime)
          .compareTo(a['date'] as DateTime);
    });

    return items.take(5).toList();
  }

  // --------------------------------------------------
  // TASK COUNTS
  // --------------------------------------------------

  int get pendingTasks {
    return tasks.where((task) {
      final status =
          (task['status'] ?? '').toString().toLowerCase();

      return status == 'pending';
    }).length;
  }

  int get completedTasks {
    return tasks.where((task) {
      final status =
          (task['status'] ?? '').toString().toLowerCase();

      return status == 'completed';
    }).length;
  }

  // --------------------------------------------------
  // ERROR VIEW
  // --------------------------------------------------

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.orange,
            ),

            const SizedBox(height: 12),

            const Text(
              'Unable to load dashboard data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              loadError ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // DASHBOARD UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (loadError != null &&
        customers.isEmpty &&
        leads.isEmpty &&
        tasks.isEmpty) {
      return _errorView();
    }

    return RefreshIndicator(
      onRefresh: loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Welcome back! Here is your business summary.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            if (loadError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Some dashboard data could not be refreshed: '
                '$loadError',
                style: const TextStyle(
                  color: Colors.orange,
                ),
              ),
            ],

            const SizedBox(height: 25),

            // LIVE STATISTICS GRID

            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth > 900
                    ? 4
                    : box.maxWidth > 500
                        ? 2
                        : 1;

                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  children: [
                    statCard(
                      context,
                      'Total Customers',
                      customers.length.toString(),
                      Icons.people,
                      _blue,
                    ),

                    statCard(
                      context,
                      'Total Leads',
                      leads.length.toString(),
                      Icons.person_search,
                      _orange,
                    ),

                    statCard(
                      context,
                      'Total Sales',
                      'Not tracked',
                      Icons.currency_rupee,
                      _green,
                    ),

                    statCard(
                      context,
                      'Pending Tasks',
                      pendingTasks.toString(),
                      Icons.task_alt,
                      _purple,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 25),

            // COMPLETED TASKS SUMMARY

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 28,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed Tasks',
                            style: TextStyle(
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            completedTasks.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      '${tasks.length} Total Tasks',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // RECENT ACTIVITIES

            const Text(
              'Recent Activities',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              child: recentActivities.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(25),
                      child: Center(
                        child: Text(
                          'No recent activities found.',
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0;
                            i < recentActivities.length;
                            i++) ...[
                          activity(
                            context,
                            recentActivities[i]['title']
                                as String,
                            recentActivities[i]['subtitle']
                                as String,
                            recentActivities[i]['icon']
                                as IconData,
                          ),

                          if (i != recentActivities.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

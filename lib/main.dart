
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth/auth_gate.dart';

import 'screens/customers_screen.dart';
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
// MAIN APPLICATION WITH FIRESTORE THEME
// --------------------------------------------------

class BusinessCRM extends StatelessWidget {
  const BusinessCRM({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('preferences')
          .snapshots(),
      builder: (context, snapshot) {
        final preferences =
            snapshot.data?.data() ?? <String, dynamic>{};

        final dynamic savedDarkMode =
            preferences['darkModeEnabled'];

        final bool isDarkMode = savedDarkMode is bool
            ? savedDarkMode
            : preferences['theme'] == 'Dark';

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

          themeMode:
              isDarkMode ? ThemeMode.dark : ThemeMode.light,

          home: AuthGate(
            authenticatedView: const DashboardScreen(),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------
// DASHBOARD AND NAVIGATION
// --------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final List<String> menuTitles = [
    'Dashboard',
    'Customers',
    'Leads',
    'Tasks',
    'Reports',
    'Settings',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.people,
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

  Widget getCurrentPage() {
    switch (selectedIndex) {
      case 0:
        return const DashboardOverview();
      case 1:
        return const CustomersScreen();
      case 2:
        return const LeadsScreen();
      case 3:
        return const TasksScreen();
      case 4:
        return const ReportsScreen();
      case 5:
        return const SettingsScreen();
      default:
        return const Center(
          child: Text('Page Not Found'),
        );
    }
  }

  // SIDEBAR MENU

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
                  padding: EdgeInsets.all(isWide ? 24 : 16),
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
// DASHBOARD OVERVIEW
// --------------------------------------------------

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key});

  // COMPACT STATISTICS CARD

  Widget statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: color,
              size: 25,
            ),

            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // RECENT ACTIVITY ITEM

  Widget activity(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: colors.primaryContainer,
        child: Icon(
          icon,
          color: colors.primary,
          size: 19,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colors.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please log in to view the dashboard.'),
      );
    }

    // USER-SPECIFIC FIRESTORE STREAMS

    final customersStream = firestore
        .collection('customers')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    final leadsStream = firestore
        .collection('leads')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    final tasksStream = firestore
        .collection('tasks')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customersStream,
      builder: (context, customerSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: leadsStream,
          builder: (context, leadSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksStream,
              builder: (context, taskSnapshot) {
                if (customerSnapshot.hasError ||
                    leadSnapshot.hasError ||
                    taskSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load dashboard data.',
                      style: TextStyle(color: colors.error),
                    ),
                  );
                }

                if (!customerSnapshot.hasData ||
                    !leadSnapshot.hasData ||
                    !taskSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // CURRENT USER RECORDS

                final customers = customerSnapshot.data!.docs;
                final leads = leadSnapshot.data!.docs;
                final tasks = taskSnapshot.data!.docs;

                // TASK COUNTS

                final pendingTasks = tasks.where((doc) {
                  return doc.data()['status'] == 'Pending';
                }).length;

                final completedTasks = tasks.where((doc) {
                  return doc.data()['status'] == 'Completed';
                }).length;

                final totalTasks = tasks.length;

                final completionRate = totalTasks == 0
                    ? 0.0
                    : completedTasks / totalTasks;

                // RECENT ACTIVITIES

                final List<Map<String, dynamic>> activities = [];

                for (final doc in customers) {
                  final data = doc.data();

                  activities.add({
                    'title': 'New customer added',
                    'subtitle': data['name'] ?? 'Customer',
                    'icon': Icons.person_add,
                    'date': data['createdAt'] is Timestamp
                        ? data['createdAt']
                        : Timestamp(0, 0),
                  });
                }

                for (final doc in leads) {
                  final data = doc.data();

                  activities.add({
                    'title': 'New lead added',
                    'subtitle': data['name'] ?? 'Lead',
                    'icon': Icons.trending_up,
                    'date': data['createdAt'] is Timestamp
                        ? data['createdAt']
                        : Timestamp(0, 0),
                  });
                }

                for (final doc in tasks) {
                  final data = doc.data();

                  activities.add({
                    'title':
                        'Task: ${data['status'] ?? 'Updated'}',
                    'subtitle': data['title'] ?? 'Task',
                    'icon': Icons.task_alt,
                    'date': data['createdAt'] is Timestamp
                        ? data['createdAt']
                        : Timestamp(0, 0),
                  });
                }

                activities.sort((a, b) {
                  final dateA = a['date'] as Timestamp;
                  final dateB = b['date'] as Timestamp;
                  return dateB.compareTo(dateA);
                });

                final recentActivities =
                    activities.take(5).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DASHBOARD HEADER

                      Text(
                        'Dashboard Overview',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 25,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Welcome back! Here is your business summary.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // STATISTICS GRID

                      LayoutBuilder(
                        builder: (context, box) {
                          final columns = box.maxWidth > 1000
                              ? 4
                              : box.maxWidth > 600
                                  ? 2
                                  : 2;

                          return GridView.count(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            childAspectRatio:
                                box.maxWidth < 400 ? 1.15 : 1.55,
                            children: [
                              statCard(
                                context,
                                'Total Customers',
                                customers.length.toString(),
                                Icons.people,
                                Colors.blue,
                              ),
                              statCard(
                                context,
                                'Total Leads',
                                leads.length.toString(),
                                Icons.person_search,
                                Colors.orange,
                              ),
                              statCard(
                                context,
                                'Total Sales',
                                'Not tracked',
                                Icons.currency_rupee,
                                Colors.green,
                              ),
                              statCard(
                                context,
                                'Pending Tasks',
                                pendingTasks.toString(),
                                Icons.task_alt,
                                Colors.purple,
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // TASK COMPLETION SUMMARY

                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 25,
                                  ),
                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Completed Tasks',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color:
                                                colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$completedTasks of $totalTasks',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Text(
                                    '${(completionRate * 100).toStringAsFixed(0)}%',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: completionRate,
                                  minHeight: 8,
                                  backgroundColor:
                                      colors.surfaceContainerHighest,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // RECENT ACTIVITIES HEADER

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activities',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                          Text(
                            '${recentActivities.length} recent',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // RECENT ACTIVITIES LIST

                      Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: activities.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(22),
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
                                    if (i !=
                                        recentActivities.length - 1)
                                      const Divider(
                                        height: 1,
                                        indent: 60,
                                      ),
                                  ],
                                ],
                              ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

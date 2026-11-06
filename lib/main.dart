
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

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
        String selectedTheme = 'Light';

        if (snapshot.hasData && snapshot.data!.exists) {
          selectedTheme =
              snapshot.data!.data()?['theme'] ?? 'Light';
        }

        final isDarkMode = selectedTheme == 'Dark';

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

          home: const DashboardScreen(),
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
  State<DashboardScreen> createState() => _DashboardScreenState();
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

          // APP BAR

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

          // MAIN BODY

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
// DASHBOARD OVERVIEW
// --------------------------------------------------

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key});

  // STATISTICS CARD

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

  // RECENT ACTIVITY ITEM

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

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('customers').snapshots(),
      builder: (context, customerSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('leads').snapshots(),
          builder: (context, leadSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('tasks').snapshots(),
              builder: (context, taskSnapshot) {
                if (customerSnapshot.hasError ||
                    leadSnapshot.hasError ||
                    taskSnapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load dashboard data.',
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

                // FIRESTORE RECORDS

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
                        child: activities.isEmpty
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
                                    if (i !=
                                        recentActivities.length - 1)
                                      const Divider(height: 1),
                                  ],
                                ],
                              ),
                      ),
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

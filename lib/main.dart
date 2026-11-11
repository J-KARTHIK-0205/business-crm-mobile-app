
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth/auth_gate.dart';

import 'screens/customers_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/organizations_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

// --------------------------------------------------
// APP COLORS
// --------------------------------------------------

class CRMColors {
  static const background = Color(0xFF080C09);
  static const surface = Color(0xFF121A15);
  static const surfaceLight = Color(0xFF1A241D);
  static const emerald = Color(0xFF00C853);
  static const emeraldLight = Color(0xFF69F0AE);
  static const muted = Color(0xFF9AA69D);
}

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
// THEME
// --------------------------------------------------

class BusinessCRM extends StatelessWidget {
  const BusinessCRM({super.key});

  ThemeData buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: CRMColors.emerald,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF4F8F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F8F5),
        foregroundColor: Color(0xFF17231B),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE5EDE7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F6F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  ThemeData buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: CRMColors.emerald,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: CRMColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: CRMColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: CRMColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CRMColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('preferences')
          .snapshots(),
      builder: (context, snapshot) {
        final preferences = snapshot.data?.data() ?? <String, dynamic>{};

        final savedDarkMode = preferences['darkModeEnabled'];

        final isDarkMode = savedDarkMode is bool
            ? savedDarkMode
            : preferences['theme'] == 'Dark';

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Business CRM',
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final List<String> menuTitles = [
    'Dashboard',
    'Customers',
    'Leads',
    'Organizations',
    'Tasks',
    'Reports',
    'Settings',
  ];

  final List<IconData> menuIcons = [
    Icons.grid_view_rounded,
    Icons.people_alt_rounded,
    Icons.trending_up_rounded,
    Icons.business_rounded,
    Icons.task_alt_rounded,
    Icons.analytics_rounded,
    Icons.settings_rounded,
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
        return const OrganizationsScreen();
      case 4:
        return const TasksScreen();
      case 5:
        return const ReportsScreen();
      case 6:
        return const SettingsScreen();
      default:
        return const Center(child: Text('Page Not Found'));
    }
  }

  // ------------------------------------------------
  // PREMIUM SIDEBAR
  // ------------------------------------------------

  Widget buildMenu(bool closeDrawer) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : const Color(0xFF17231B);
    final mutedColor = isDark
        ? CRMColors.muted
        : const Color(0xFF758279);

    return Container(
      color: isDark ? CRMColors.surface : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Container(
                    height: 43,
                    width: 43,
                    decoration: BoxDecoration(
                      color: CRMColors.emerald,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.bubble_chart_rounded,
                      color: Colors.black,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXUS',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'BUSINESS CRM',
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 38),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: menuTitles.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () {
                        selectPage(index);

                        if (closeDrawer) {
                          Navigator.pop(context);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CRMColors.emerald.withValues(alpha: 0.13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                          border: isSelected
                              ? Border.all(
                                  color: CRMColors.emerald.withValues(
                                    alpha: 0.25,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              menuIcons[index],
                              size: 21,
                              color: isSelected
                                  ? CRMColors.emerald
                                  : mutedColor,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                menuTitles[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? CRMColors.emerald
                                      : textColor,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                height: 7,
                                width: 7,
                                decoration: const BoxDecoration(
                                  color: CRMColors.emerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isDark
                      ? CRMColors.surfaceLight
                      : const Color(0xFFF1F6F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: CRMColors.emerald,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Business workspace',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 750;

        return Scaffold(
          drawer: isWide
              ? null
              : Drawer(
                  width: 275,
                  child: buildMenu(true),
                ),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuTitles[selectedIndex],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage your business efficiently',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications.'),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 18, left: 5),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: CRMColors.emerald.withValues(
                    alpha: 0.18,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: CRMColors.emerald,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              if (isWide)
                SizedBox(
                  width: 245,
                  child: buildMenu(false),
                ),
              if (isWide)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              Expanded(
                child: Container(
                  color: isDark
                      ? CRMColors.background
                      : const Color(0xFFF4F8F5),
                  padding: EdgeInsets.all(isWide ? 26 : 15),
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

  // ------------------------------------------------
  // STATISTICS CARD
  // ------------------------------------------------

  Widget statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 39,
                width: 39,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              Icon(
                Icons.north_east_rounded,
                size: 17,
                color: isDark
                    ? CRMColors.muted
                    : const Color(0xFF829087),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------
  // ACTIVITY ITEM
  // ------------------------------------------------

  Widget activity(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: CRMColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: CRMColors.emerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------
  // SECTION HEADING
  // ------------------------------------------------

  Widget sectionHeading(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
                    child: CircularProgressIndicator(
                      color: CRMColors.emerald,
                    ),
                  );
                }

                final customers = customerSnapshot.data!.docs;
                final leads = leadSnapshot.data!.docs;
                final tasks = taskSnapshot.data!.docs;

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
                    'icon': Icons.person_add_alt_1_rounded,
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
                    'icon': Icons.trending_up_rounded,
                    'date': data['createdAt'] is Timestamp
                        ? data['createdAt']
                        : Timestamp(0, 0),
                  });
                }

                for (final doc in tasks) {
                  final data = doc.data();

                  activities.add({
                    'title': 'Task: ${data['status'] ?? 'Updated'}',
                    'subtitle': data['title'] ?? 'Task',
                    'icon': Icons.task_alt_rounded,
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

                final recentActivities = activities.take(5).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // WELCOME HEADER

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF064D2A),
                              Color(0xFF087A3C),
                              Color(0xFF00A94F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -10,
                              top: -15,
                              child: Icon(
                                Icons.bubble_chart_rounded,
                                size: 115,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BUSINESS OVERVIEW',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Welcome back!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Your business activity at a glance.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 17),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Workspace active',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      sectionHeading(
                        context,
                        'Business statistics',
                        'A quick look at your CRM data',
                      ),

                      const SizedBox(height: 14),

                      LayoutBuilder(
                        builder: (context, box) {
                          final columns = box.maxWidth > 950
                              ? 4
                              : box.maxWidth > 570
                                  ? 2
                                  : 2;

                          return GridView.count(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio:
                                box.maxWidth < 400 ? 1.08 : 1.35,
                            children: [
                              statCard(
                                context,
                                'Total Customers',
                                customers.length.toString(),
                                Icons.people_alt_rounded,
                                const Color(0xFF29B6F6),
                              ),
                              statCard(
                                context,
                                'Total Leads',
                                leads.length.toString(),
                                Icons.trending_up_rounded,
                                const Color(0xFFFFA726),
                              ),
                              statCard(
                                context,
                                'Total Sales',
                                'Not tracked',
                                Icons.currency_rupee_rounded,
                                CRMColors.emerald,
                              ),
                              statCard(
                                context,
                                'Pending Tasks',
                                pendingTasks.toString(),
                                Icons.pending_actions_rounded,
                                const Color(0xFFAB7BFF),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // TASK COMPLETION

                      sectionHeading(
  context,
  'Task performance',
  "Track your team's task completion",
),

                      const SizedBox(height: 13),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(19),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.dividerColor.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 43,
                                  width: 43,
                                  decoration: BoxDecoration(
                                    color: CRMColors.emerald.withValues(
                                      alpha: 0.13,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.task_alt_rounded,
                                    color: CRMColors.emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Completed tasks',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$completedTasks completed out of $totalTasks',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(completionRate * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: CRMColors.emerald,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: completionRate,
                                minHeight: 9,
                                backgroundColor:
                                    colors.surfaceContainerHighest,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  CRMColors.emerald,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$completedTasks completed',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '$pendingTasks pending',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // RECENT ACTIVITIES

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          sectionHeading(
                            context,
                            'Recent activities',
                            'Latest updates from your workspace',
                          ),
                          Text(
                            '${recentActivities.length} items',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),

                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.dividerColor.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: activities.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(25),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 35,
                                        color: CRMColors.muted,
                                      ),
                                      SizedBox(height: 9),
                                      Text(
                                        'No recent activities yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Your updates will appear here.',
                                        style: TextStyle(
                                          color: CRMColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (
                                    int i = 0;
                                    i < recentActivities.length;
                                    i++
                                  ) ...[
                                    activity(
                                      context,
                                      recentActivities[i]['title'] as String,
                                      recentActivities[i]['subtitle']
                                          as String,
                                      recentActivities[i]['icon'] as IconData,
                                    ),
                                    if (i != recentActivities.length - 1)
                                      Divider(
                                        height: 1,
                                        indent: 65,
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      ),

                      const SizedBox(height: 20),
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

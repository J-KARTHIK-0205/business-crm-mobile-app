import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please log in to view reports.'),
      );
    }

    // Only load records belonging to the logged-in user.
    final customersStream = db
        .collection('customers')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    final leadsStream = db
        .collection('leads')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    final tasksStream = db
        .collection('tasks')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customersStream,
      builder: (context, customerSnapshot) {
        if (customerSnapshot.hasError) {
          return _errorMessage(
            'Customer Error: ${customerSnapshot.error}',
            colors.error,
          );
        }

        if (!customerSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: leadsStream,
          builder: (context, leadSnapshot) {
            if (leadSnapshot.hasError) {
              return _errorMessage(
                'Lead Error: ${leadSnapshot.error}',
                colors.error,
              );
            }

            if (!leadSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksStream,
              builder: (context, taskSnapshot) {
                if (taskSnapshot.hasError) {
                  return _errorMessage(
                    'Task Error: ${taskSnapshot.error}',
                    colors.error,
                  );
                }

                if (!taskSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Current user's Firestore records.
                final customers = customerSnapshot.data!.docs;
                final leads = leadSnapshot.data!.docs;
                final tasks = taskSnapshot.data!.docs;

                // LEAD COUNTS
                int leadCount(String status) {
                  return leads.where((doc) {
                    return doc.data()['status'] == status;
                  }).length;
                }

                // TASK COUNTS
                int taskCount(String status) {
                  return tasks.where((doc) {
                    return doc.data()['status'] == status;
                  }).length;
                }

                // TASK COMPLETION
                final totalTasks = tasks.length;
                final completedTasks = taskCount('Completed');

                final completionRate = totalTasks == 0
                    ? 0.0
                    : (completedTasks / totalTasks) * 100;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PAGE TITLE
                        Text(
                          'Business Reports',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          'Overview of your business performance.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // CUSTOMER OVERVIEW
                        _sectionTitle(context, 'Customer Overview'),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _metric(
                              context,
                              'Total Customers',
                              customers.length,
                              Icons.people,
                              Colors.blue,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // LEAD OVERVIEW
                        _sectionTitle(context, 'Lead Overview'),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _metric(
                              context,
                              'Total Leads',
                              leads.length,
                              Icons.groups,
                              Colors.blue,
                            ),
                            _metric(
                              context,
                              'New Leads',
                              leadCount('New'),
                              Icons.person_add,
                              Colors.orange,
                            ),
                            _metric(
                              context,
                              'Contacted',
                              leadCount('Contacted'),
                              Icons.call,
                              Colors.deepOrange,
                            ),
                            _metric(
                              context,
                              'Qualified',
                              leadCount('Qualified'),
                              Icons.verified,
                              Colors.indigo,
                            ),
                            _metric(
                              context,
                              'Converted',
                              leadCount('Converted'),
                              Icons.check_circle,
                              Colors.green,
                            ),
                            _metric(
                              context,
                              'Lost',
                              leadCount('Lost'),
                              Icons.cancel,
                              Colors.red,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // TASK OVERVIEW
                        _sectionTitle(context, 'Task Overview'),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _metric(
                              context,
                              'Total Tasks',
                              totalTasks,
                              Icons.assignment,
                              Colors.blue,
                            ),
                            _metric(
                              context,
                              'Completed Tasks',
                              completedTasks,
                              Icons.task_alt,
                              Colors.green,
                            ),
                            _metric(
                              context,
                              'Pending Tasks',
                              taskCount('Pending'),
                              Icons.pending_actions,
                              Colors.orange,
                            ),
                            _metric(
                              context,
                              'In Progress',
                              taskCount('In Progress'),
                              Icons.timelapse,
                              Colors.indigo,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // COMPLETION RATE
                        _completionCard(
                          context,
                          completionRate,
                        ),

                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ERROR MESSAGE
  Widget _errorMessage(String message, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // SECTION TITLE
  Widget _sectionTitle(
    BuildContext context,
    String title,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: colors.onSurface,
      ),
    );
  }

  // METRIC CARD
  Widget _metric(
    BuildContext context,
    String title,
    int value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: 175,
      child: Card(
        color: colors.surface,
        surfaceTintColor: colors.surfaceTint,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 26,
              ),

              const SizedBox(height: 12),

              Text(
                value.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 4),

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

  // TASK COMPLETION CARD
  Widget _completionCard(
    BuildContext context,
    double completionRate,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Completion Rate',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 18),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (completionRate / 100).clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colors.primary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              '${completionRate.toStringAsFixed(1)}% completed',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('customers').snapshots(),
      builder: (context, customerSnapshot) {
        if (customerSnapshot.hasError) {
          return Center(child: Text('Customer Error: ${customerSnapshot.error}'));
        }

        if (!customerSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('leads').snapshots(),
          builder: (context, leadSnapshot) {
            if (leadSnapshot.hasError) {
              return Center(child: Text('Lead Error: ${leadSnapshot.error}'));
            }

            if (!leadSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection('tasks').snapshots(),
              builder: (context, taskSnapshot) {
                if (taskSnapshot.hasError) {
                  return Center(child: Text('Task Error: ${taskSnapshot.error}'));
                }

                if (!taskSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = customerSnapshot.data!.docs;
                final leads = leadSnapshot.data!.docs;
                final tasks = taskSnapshot.data!.docs;

                int leadCount(String status) {
                  return leads.where((doc) {
                    return doc.data()['status'] == status;
                  }).length;
                }

                int taskCount(String status) {
                  return tasks.where((doc) {
                    return doc.data()['status'] == status;
                  }).length;
                }

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
                        const Text(
                          'Business Reports',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          'Overview of your business performance.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'Customer Overview',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

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

                        const Text(
                          'Lead Overview',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

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

                        const Text(
                          'Task Overview',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

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

                        Card(
                          color: colors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Task Completion Rate',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 18),

                                LinearProgressIndicator(
                                  value: completionRate / 100,
                                  minHeight: 12,
                                  borderRadius: BorderRadius.circular(10),
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  '${completionRate.toStringAsFixed(1)}% completed',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _metric(
    BuildContext context,
    String title,
    int value,
    IconData icon,
    Color color,
  ) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 175,
      child: Card(
        color: colors.surface,
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
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                title,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
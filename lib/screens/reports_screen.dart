
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const green = Color(0xFF00C853);
  static const muted = Color(0xFF9AA69D);
  static const card = Color(0xFF121A15);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view reports.'));
    }

    final db = FirebaseFirestore.instance;

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
          return _error('Customer report: ${customerSnapshot.error}');
        }
        if (!customerSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: green),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: leadsStream,
          builder: (context, leadSnapshot) {
            if (leadSnapshot.hasError) {
              return _error('Lead report: ${leadSnapshot.error}');
            }
            if (!leadSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: green),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksStream,
              builder: (context, taskSnapshot) {
                if (taskSnapshot.hasError) {
                  return _error('Task report: ${taskSnapshot.error}');
                }
                if (!taskSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: green),
                  );
                }

                final customerDocs = customerSnapshot.data!.docs;
                final leadDocs = leadSnapshot.data!.docs;
                final taskDocs = taskSnapshot.data!.docs;

                int leadCount(String status) => leadDocs
                    .where((doc) => doc.data()['status'] == status)
                    .length;

                int taskCount(String status) => taskDocs
                    .where((doc) => doc.data()['status'] == status)
                    .length;

                final totalTasks = taskDocs.length;
                final completedTasks = taskCount('Completed');

                final completionRate = totalTasks == 0
                    ? 0.0
                    : completedTasks / totalTasks;

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'A live overview of your CRM activity.',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 22),

                      _sectionTitle('Customer Overview'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metric(
                            'Total Customers',
                            customerDocs.length,
                            Icons.people_outline,
                          ),
                        ],
                      ),

                      const SizedBox(height: 23),
                      _sectionTitle('Lead Overview'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metric('Total Leads', leadDocs.length, Icons.groups_outlined),
                          _metric('New Leads', leadCount('New'), Icons.person_add_alt),
                          _metric('Contacted', leadCount('Contacted'), Icons.call_outlined),
                          _metric('Qualified', leadCount('Qualified'), Icons.verified_outlined),
                          _metric('Converted', leadCount('Converted'), Icons.check_circle_outline),
                          _metric('Lost', leadCount('Lost'), Icons.cancel_outlined),
                        ],
                      ),

                      const SizedBox(height: 23),
                      _sectionTitle('Task Overview'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metric('Total Tasks', totalTasks, Icons.assignment_outlined),
                          _metric('Completed', completedTasks, Icons.task_alt),
                          _metric('Pending', taskCount('Pending'), Icons.pending_actions),
                          _metric('In Progress', taskCount('In Progress'), Icons.timelapse),
                        ],
                      ),

                      const SizedBox(height: 23),
                      _completionCard(
                        completionRate: completionRate,
                        completed: completedTasks,
                        total: totalTasks,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Note: Sales and revenue reporting will be available '
                        'after a sales module is implemented.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
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

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _metric(String title, int value, IconData icon) {
    return Container(
      width: 155,
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF69F0AE), size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _completionCard({
    required double completionRate,
    required int completed,
    required int total,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Task Completion Rate',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Progress across all your tasks',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    minHeight: 11,
                    backgroundColor: const Color(0xFF26332A),
                    valueColor: const AlwaysStoppedAnimation(green),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${(completionRate * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF69F0AE),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$completed completed out of $total tasks',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

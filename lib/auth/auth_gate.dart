
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth_screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  final Widget authenticatedView;

  const AuthGate({
    super.key,
    required this.authenticatedView,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        // Authentication stream error
        if (snapshot.hasError) {
          debugPrint('AUTH GATE ERROR: ${snapshot.error}');

          return const Scaffold(
            body: Center(
              child: Text(
                'Authentication error. Please restart the app.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Wait until Firebase checks the login state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF080C09),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00C853),
              ),
            ),
          );
        }

        final user = snapshot.data;

        debugPrint('AUTH GATE STATE: ${snapshot.connectionState}');
        debugPrint('AUTH GATE USER: ${user?.uid}');

        // User is logged in
        if (user != null) {
          debugPrint('Opening DashboardScreen');

          return authenticatedView;
        }

        // User is not logged in
        debugPrint('Opening LoginScreen');

        return const LoginScreen();
      },
    );
  }
}

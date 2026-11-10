
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
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Authentication error. Please restart the app.',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        debugPrint('AUTH GATE USER: ${user?.uid}');

        if (user != null) {
          return authenticatedView;
        }

        return const LoginScreen();
      },
    );
  }
}

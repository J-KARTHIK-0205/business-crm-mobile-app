
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // PHP API URL based on the platform.
  String get _apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost/business_crm_api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/business_crm_api';
    }

    return 'http://localhost/business_crm_api';
  }

  // Synchronize Firebase user with MySQL through PHP.
  Future<void> _syncUserWithBackend(User user) async {
    final idToken = await user.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to obtain Firebase authentication token.');
    }

    final uri = Uri.parse(
      '$_apiBaseUrl/api/auth/sync_user.php',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 20));

    final Map<String, dynamic> result =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || result['success'] != true) {
      throw Exception(
        result['message'] ?? 'MySQL user synchronization failed.',
      );
    }
  }

  // REGISTER
  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Account creation failed. Please try again.');
      }

      await user.updateDisplayName(name.trim());
      await user.reload();

      final updatedUser = _auth.currentUser;

      if (updatedUser == null) {
        throw Exception('Unable to retrieve the registered user.');
      }

      // Preserve the existing Firestore profile.
      await _firestore.collection('users').doc(updatedUser.uid).set({
        'uid': updatedUser.uid,
        'name': name.trim(),
        'email': updatedUser.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Synchronize the user with MySQL.
      await _syncUserWithBackend(updatedUser);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception(
        'Registration failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // LOGIN
  Future<UserCredential> login(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Login failed. Please try again.');
      }

      // Synchronize the user with MySQL after login.
      await _syncUserWithBackend(user);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // FORGOT PASSWORD
  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // SEND EMAIL VERIFICATION
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Please log in first.');
      }

      if (user.emailVerified) {
        throw Exception('Your email is already verified.');
      }

      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // CHECK EMAIL VERIFICATION STATUS
  Future<bool> checkEmailVerification() async {
    await _auth.currentUser?.reload();

    return _auth.currentUser?.emailVerified ?? false;
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // FIREBASE ERROR HANDLING
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';

      case 'user-not-found':
        return 'No account found with this email.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'network-request-failed':
        return 'Network error. Check your internet connection.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'operation-not-allowed':
        return 'This authentication method is not enabled in Firebase.';

      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

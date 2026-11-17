
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

  // PHP API base URL
  String get _apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost/business_crm_api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/business_crm_api';
    }

    return 'http://localhost/business_crm_api';
  }

  // Get a fresh Firebase ID token
  Future<String> getFreshIdToken() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    final idToken = await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to generate Firebase ID token.');
    }

    return idToken;
  }

  // Synchronize Firebase user with PHP/MySQL backend
  Future<void> _syncUserWithBackend(
    User user, {
    String? existingToken,
  }) async {
    final idToken = existingToken ?? await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Firebase ID token is empty.');
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

    Map<String, dynamic> responseData;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected response format.');
      }

      responseData = decoded;
    } catch (_) {
      throw Exception(
        'Invalid response received from PHP backend. '
        'HTTP Status: ${response.statusCode}',
      );
    }

    if (response.statusCode != 200 ||
        responseData['success'] != true) {
      throw Exception(
        responseData['message']?.toString() ??
            'Failed to synchronize user with backend.',
      );
    }
  }

  // Register a new user
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
        throw Exception('User registration failed.');
      }

      await user.updateDisplayName(name.trim());
      await user.reload();

      final updatedUser = _auth.currentUser;

      if (updatedUser == null) {
        throw Exception('Unable to load registered user.');
      }

      // Save user details in Firestore
      await _firestore.collection('users').doc(updatedUser.uid).set({
        'uid': updatedUser.uid,
        'name': name.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Generate a fresh Firebase ID token
      final idToken = await updatedUser.getIdToken(true);

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Unable to generate Firebase ID token.');
      }

      // Synchronize user with PHP/MySQL
      await _syncUserWithBackend(
        updatedUser,
        existingToken: idToken,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Login an existing user
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Login failed. User not found.');
      }

      // Generate a fresh Firebase ID token
      final idToken = await user.getIdToken(true);

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Unable to generate Firebase ID token.');
      }

      // Synchronize user with PHP/MySQL
      await _syncUserWithBackend(
        user,
        existingToken: idToken,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Forgot password
  Future<void> forgotPassword({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Please log in first.');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Check email verification status
  Future<bool> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      await user.reload();

      final updatedUser = _auth.currentUser;

      return updatedUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Handle Firebase authentication errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email address is already registered.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';

      case 'user-not-found':
        return 'No account found with this email address.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'operation-not-allowed':
        return 'This authentication method is not enabled.';

      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

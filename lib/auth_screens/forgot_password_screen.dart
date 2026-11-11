import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  static const Color backgroundColor = Color(0xFF080C09);
  static const Color cardColor = Color(0xFF121A15);
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color secondaryGreen = Color(0xFF69F0AE);
  static const Color mutedText = Color(0xFF9AA69D);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // SEND PASSWORD RESET EMAIL
  // EXISTING FIREBASE AUTHENTICATION PRESERVED

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _emailSent = false;
    });

    try {
      await _authService.forgotPassword(_emailController.text.trim());

      if (!mounted) return;

      setState(() {
        _emailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // EMAIL INPUT FIELD

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _sendResetEmail();
        }
      },
      decoration: InputDecoration(
        labelText: 'Email Address',
        labelStyle: const TextStyle(color: mutedText),
        hintText: 'Enter your registered email',
        hintStyle: const TextStyle(color: Color(0xFF68746C), fontSize: 13),
        prefixIcon: const Icon(Icons.alternate_email, color: secondaryGreen),
        filled: true,
        fillColor: const Color(0xFF1A241D),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF29382E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }

        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
          return 'Enter a valid email address';
        }

        return null;
      },
    );
  }

  // HEADER DESIGN

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          height: 88,
          width: 88,
          decoration: BoxDecoration(
            color: const Color(0xFF12251A),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: primaryGreen.withValues(alpha: 0.5),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withValues(alpha: 0.13),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: secondaryGreen,
            size: 45,
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'RESET PASSWORD',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Secure your account and get back to work.',
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedText, fontSize: 13),
        ),
      ],
    );
  }

  // RESET EMAIL BUTTON

  Widget _buildResetButton() {
    return SizedBox(
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendResetEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.black,
          disabledBackgroundColor: primaryGreen.withValues(alpha: 0.5),
          elevation: 5,
          shadowColor: primaryGreen.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 23,
                width: 23,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded),
                  SizedBox(width: 10),
                  Text(
                    'Send Reset Link',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  // SUCCESS MESSAGE

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF10251A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: secondaryGreen,
              size: 32,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Check Your Email',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'If the address is eligible for password recovery, '
            'you will receive a reset link. Check your inbox '
            'and spam folder, then follow the instructions '
            'to create a new password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedText, fontSize: 13, height: 1.6),
          ),

          const SizedBox(height: 12),

          Text(
            _emailController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: secondaryGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Account Recovery',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildHeader(),

                  const SizedBox(height: 35),

                  // MAIN RECOVERY CARD
                  Container(
                    padding: const EdgeInsets.all(23),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF26372C)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Forgot your password?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'No worries! Enter the email address '
                            'associated with your account. We will '
                            'send you instructions to reset it.',
                            style: TextStyle(
                              color: mutedText,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 27),

                          const Text(
                            'REGISTERED EMAIL',
                            style: TextStyle(
                              color: secondaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),

                          const SizedBox(height: 10),

                          _buildEmailField(),

                          const SizedBox(height: 23),

                          _buildResetButton(),

                          if (_emailSent) ...[
                            const SizedBox(height: 23),
                            _buildSuccessCard(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // BACK TO LOGIN
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 19),
                    label: const Text(
                      'Back to Login',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: secondaryGreen,
                      side: BorderSide(
                        color: primaryGreen.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: secondaryGreen,
                        size: 16,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Your account security matters to us',
                        style: TextStyle(color: mutedText, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

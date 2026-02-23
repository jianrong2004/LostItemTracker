// email_verification_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'registration_success_page.dart';
import 'user_login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final String fullName;
  final String phoneNumber;
  final String campusId;
  final String userId;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.campusId,
    required this.userId,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  Timer? _verificationCheckTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _canResend = false;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _startVerificationCheck() {
    _verificationCheckTimer?.cancel();
    // check every 3 seconds
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // If no currentUser, nothing to check here. User may have signed out; ask them to sign in.
        debugPrint('EmailVerificationPage: no current user while checking verification.');
        return;
      }

      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        _verificationCheckTimer?.cancel();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationSuccessPage(),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error checking verification: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      setState(() {
        _isLoading = true;
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No signed-in user found. Please sign in and try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await user.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _startResendCountdown();
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: ${e.toString()}'),
          backgroundColor: Colors.red,
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

  Future<void> _verifyAndSignUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // cannot check; user may have signed out
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No signed-in user. Please sign in and then verify your email.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationSuccessPage(),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your email first. Check your inbox.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in verifyAndSignUp: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Step 2 of 2',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              Icon(
                Icons.email_outlined,
                size: 80,
                color: Colors.indigo.shade700,
              ),

              const SizedBox(height: 30),

              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'We have sent a verification link to:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                widget.email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.indigo.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.indigo.shade700,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please check your email and click the verification link to complete your registration.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The page will automatically proceed once your email is verified.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Resend Email Button
              TextButton(
                onPressed: _canResend ? _resendVerificationEmail : null,
                child: Text(
                  _canResend ? 'Resend Verification Email' : 'Resend in $_resendCountdown seconds',
                  style: TextStyle(
                    color: _canResend ? Colors.indigo.shade700 : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Manual Verify Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'I Have Verified My Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Text(
                "Didn't receive the email?",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Check your spam folder or resend the verification email.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserLoginPage(),
                    ),
                        (route) => false,
                  );
                },
                child: Text(
                  'Back to Login',
                  style: TextStyle(
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

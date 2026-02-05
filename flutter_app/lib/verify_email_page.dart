// verify_email_page.dart
// Winzaap

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with WidgetsBindingObserver {
  bool canResendEmail = true;
  bool _checking = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _checkEmailVerified(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerified();
    }
  }

  Future<void> _checkEmailVerified() async {
    if (_checking) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _checking = true;
    await user.reload();
    _checking = false;
    // AuthGate handles navigation automatically
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !canResendEmail) return;

    try {
      await user.sendEmailVerification();
      setState(() => canResendEmail = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );

      await Future.delayed(const Duration(seconds: 60));
      if (mounted) setState(() => canResendEmail = true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send email')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 80,
                color: Colors.indigo,
              ),
              const SizedBox(height: 24),

              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'A verification email has been sent.\n'
                    'Please check your inbox or spam folder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: canResendEmail ? _sendVerificationEmail : null,
                child: Text(
                  canResendEmail ? 'Resend Email' : 'Wait 60 seconds',
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

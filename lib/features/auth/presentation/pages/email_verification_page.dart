import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:business_management_system/core/theme/app_theme.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  int _resendCooldown = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 30;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _resendCooldown--;
        });
        if (_resendCooldown > 0) {
          _startCooldown();
        } else {
          setState(() {
            _canResend = true;
          });
        }
      }
    });
  }

  void _resendEmail() {
    // TODO: Implement resend email logic
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent!'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            const Icon(
              Icons.mark_email_read_outlined,
              size: 100,
              color: AppColors.primaryColor,
            ),
            const SizedBox(height: 30),
            Text(
              'Verify Your Email',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'We\'ve sent a verification link to your email address.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please check your inbox and click the link to verify your account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Check verification status
                  context.go('/dashboard');
                },
                child: Text(
                  'Continue to Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canResend ? _resendEmail : null,
                child: Text(
                  _canResend ? 'Resend Email' : 'Resend in $_resendCooldown seconds',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
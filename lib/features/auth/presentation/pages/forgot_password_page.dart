import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:business_management_system/core/theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/custom_text_field.dart';
import 'package:business_management_system/core/utils/responsive.dart';
import 'package:business_management_system/core/widgets/responsive_layout.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitted = false;

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitted = true;
      });
      // TODO: Implement password reset logic
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Padding(
            padding:
                Responsive.getPagePadding(context), // Use responsive padding
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const AuthHeader(
                    title: 'Reset Password',
                    subtitle: 'Enter your email to receive reset instructions',
                  ),
                  const SizedBox(height: 40),
                  if (!_isSubmitted) ...[
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        child: Text(
                          'Send Reset Link',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                            AppColors.successColor.withAlpha(25),
                            Theme.of(context).canvasColor),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 64,
                            color: AppColors.successColor,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Check Your Email',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.successColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'We\'ve sent password reset instructions to ${_emailController.text}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                context.go('/login');
                              },
                              child: Text(
                                'Back to Login',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // TextButton(
                  //   onPressed: _handleBack,
                  //   child: Text(
                  //     'Back to Login',
                  //     style: GoogleFonts.inter(
                  //       color: AppColors.primaryColor,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

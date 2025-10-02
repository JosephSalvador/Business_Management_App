import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports & Analytics',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: const Center(
        child: Text('Reports Page - Coming Soon'),
      ),
    );
  }
}
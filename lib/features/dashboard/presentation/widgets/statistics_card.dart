import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatisticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatisticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(
          minHeight: 120, // ensures consistent height
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // evenly distributes
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon wrapper
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color.alphaBlend(color.withAlpha(25), Colors.transparent),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),

            // Value
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Title
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

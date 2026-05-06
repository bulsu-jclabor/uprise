import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 80,
              color: primaryOrange.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Announcements',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay tuned for updates from your organizations!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
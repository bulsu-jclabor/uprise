// lib/widgets/student/profile_summary.dart
import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class ProfileSummary extends StatelessWidget {
  final String userEmail;
  
  const ProfileSummary({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryOrange, secondaryOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryOrange.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.person,
              size: 30,
              color: primaryOrange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail.split('@').first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CICT Student',
                    style: TextStyle(
                      color: primaryOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () {
              // Show Digital ID
            },
          ),
        ],
      ),
    );
  }
}
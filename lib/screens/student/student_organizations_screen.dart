import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class StudentOrganizationsScreen extends StatelessWidget {
  const StudentOrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy org data – replace with Firestore later
    final orgs = [
      {
        'name': 'SWITS',
        'description':
            'Focuses on technology and innovation, helping students build skills and collaborate.',
        'members': 24,
      },
      {
        'name': 'FRX CREW',
        'description':
            'A creative group for multimedia, design, and digital content.',
        'members': 18,
      },
      {
        'name': 'BLIS',
        'description':
            'Supports students in library and information science and research.',
        'members': 42,
      },
      {
        'name': 'Information Systems Synergy Society',
        'description':
            'Promotes teamwork and skill development in information systems.',
        'members': 30,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orgs.length,
        itemBuilder: (context, index) {
          final org = orgs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo placeholder
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: primaryOrange.withOpacity(0.2),
                    child: Text(
                      (org['name'] as String)[0], // ✅ cast to String
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Org info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org['name'] as String, // ✅ cast to String
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          org['description'] as String, // ✅ cast to String
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Dummy member avatars
                            for (int i = 0; i < 4; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey[300],
                                  child: const Icon(Icons.person,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            Text(
                              '+${org['members']} members',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

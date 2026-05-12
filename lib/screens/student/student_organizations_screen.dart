import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import 'student_organization_details_screen.dart'; // ✅ import details screen

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
        'about':
            'SWITS provides opportunities to develop technical skills, collaborate on projects, and engage in hands-on learning. It helps members stay updated with emerging trends while fostering creativity, problem-solving, and teamwork.',
        'adviser': 'Dr. Juan Dela Cruz, MIT',
        'officers': [
          {'name': 'Arvin', 'role': 'President'},
          {'name': 'Jayson', 'role': 'Vice President'},
          {'name': 'Claudine', 'role': 'Secretary'},
        ],
        'events': [
          {
            'title': 'CICT Tech Summit 2024',
            'date': 'Oct 24, 2024',
            'time': '9:00 AM',
            'location': 'Main Auditorium',
          },
        ],
      },
      {
        'name': 'FRX CREW',
        'description':
            'A creative group for multimedia, design, and digital content.',
        'members': 18,
        'about': 'FRX CREW focuses on creativity and digital content production.',
        'adviser': 'Prof. Maria Santos',
        'officers': [
          {'name': 'Leo', 'role': 'President'},
          {'name': 'Mia', 'role': 'Vice President'},
        ],
        'events': [],
      },
      {
        'name': 'BLIS',
        'description':
            'Supports students in library and information science and research.',
        'members': 42,
        'about': 'BLIS supports LIS students in research and academic growth.',
        'adviser': 'Dr. Ana Cruz',
        'officers': [
          {'name': 'Paolo', 'role': 'President'},
          {'name': 'Ella', 'role': 'Secretary'},
        ],
        'events': [],
      },
      {
        'name': 'Information Systems Synergy Society',
        'description':
            'Promotes teamwork and skill development in information systems.',
        'members': 30,
        'about': 'IS Synergy Society promotes collaboration and IS skills.',
        'adviser': 'Engr. Mark Reyes',
        'officers': [
          {'name': 'Kim', 'role': 'President'},
          {'name': 'Rica', 'role': 'Vice President'},
        ],
        'events': [],
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orgs.length,
        itemBuilder: (context, index) {
          final org = orgs[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentOrganizationsDetailsScreen(org: org), // ✅ navigate
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
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
                        (org['name'] as String)[0],
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
                          Row(
                            children: [
                              Icon(Icons.group,
                                  color: Colors.grey[600], size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  org['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            org['description'] as String,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
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
            ),
          );
        },
      ),
    );
  }
}

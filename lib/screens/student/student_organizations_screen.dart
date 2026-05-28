import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import 'student_organization_details_screen.dart'; // ✅ import details screen

class StudentOrganizationsScreen extends StatelessWidget {
  const StudentOrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final org = docs[index].data() as Map<String, dynamic>;
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
                        // Logo or placeholder
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: primaryOrange.withOpacity(0.2),
                          backgroundImage: org['logoUrl'] != null &&
                                  (org['logoUrl'] as String).isNotEmpty
                              ? NetworkImage(org['logoUrl'])
                              : null,
                          child: (org['logoUrl'] == null ||
                                  (org['logoUrl'] as String).isEmpty)
                              ? Text(
                                  (org['name'] ?? 'O')[0],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                )
                              : null,
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
                                      org['name'] ?? '',
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
                                org['description'] ?? '',
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
                                    '+${org['members'] ?? 0} members',
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
          );
        },
      ),
    );
  }
}

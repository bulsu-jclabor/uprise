import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentOrganizationsDetailsScreen extends StatelessWidget {
  final String orgId;
  const StudentOrganizationsDetailsScreen({super.key, required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final org = snapshot.data!.data() as Map<String, dynamic>;
          final officers = (org['officers'] as List?) ?? [];
          final events = (org['events'] as List?) ?? [];
          final announcements = (org['announcements'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + Name + Status
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        backgroundImage: (org['logoUrl'] != null &&
                                (org['logoUrl'] as String).isNotEmpty)
                            ? NetworkImage(org['logoUrl'])
                            : null,
                        child: (org['logoUrl'] == null ||
                                (org['logoUrl'] as String).isEmpty)
                            ? Text(
                                (org['name'] ?? 'O')[0],
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        org['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      _statusBadge(org['status'] ?? 'active'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // About
                const Text('ABOUT',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  org['description'] ?? 'No description available',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Adviser
                Text(
                  'Adviser: ${org['adviserName'] ?? 'No adviser listed'}'
                  '${org['adviserTitle'] != null ? ', ${org['adviserTitle']}' : ''}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),

                // Officers
                const Text('Executive Officers',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                officers.isEmpty
                    ? const Text('No officers listed',
                        style: TextStyle(fontSize: 13, color: Colors.grey))
                    : Column(
                        children: officers
                            .map((officer) => Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.grey,
                                      child: Icon(Icons.person,
                                          color: Colors.white),
                                    ),
                                    title: Text(officer['name'] ?? ''),
                                    subtitle: Text(officer['position'] ?? ''),
                                  ),
                                ))
                            .toList(),
                      ),
                const SizedBox(height: 24),

                // Events
                const Text('Upcoming Events',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                events.isEmpty
                    ? const Text('No upcoming events',
                        style: TextStyle(fontSize: 13, color: Colors.grey))
                    : Column(
                        children: events
                            .map((event) => Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: Container(
                                      width: 50,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        (event['date'] ?? '')
                                            .toString()
                                            .split(' ')
                                            .first, // e.g. OCT 24
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                    title: Text(event['title'] ?? ''),
                                    subtitle: Text(
                                        '${event['location'] ?? ''} • ${event['time'] ?? ''}'),
                                  ),
                                ))
                            .toList(),
                      ),
                const SizedBox(height: 24),

                // Announcements
                const Text('Recent Announcements',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                announcements.isEmpty
                    ? const Text('No announcements available',
                        style: TextStyle(fontSize: 13, color: Colors.grey))
                    : Column(
                        children: announcements
                            .map((announcement) => Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const Icon(Icons.campaign,
                                        color: Colors.orange),
                                    title: Text(announcement['title'] ?? ''),
                                    subtitle:
                                        Text(announcement['content'] ?? ''),
                                    trailing: Text(
                                      announcement['timeAgo'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Map<String, Map<String, dynamic>> styles = {
      'active': {
        'bg': const Color(0xFFECFDF5),
        'fg': const Color(0xFF059669),
        'label': 'ACTIVE'
      },
      'suspended': {
        'bg': const Color(0xFFFFFBEB),
        'fg': const Color(0xFFD97706),
        'label': 'SUSPENDED'
      },
      'archived': {
        'bg': const Color(0xFFF3F4F6),
        'fg': const Color(0xFF6B7280),
        'label': 'ARCHIVED'
      },
    };
    final s = styles[status.toLowerCase()] ?? styles['archived']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s['bg'],
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        s['label'],
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: s['fg'],
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

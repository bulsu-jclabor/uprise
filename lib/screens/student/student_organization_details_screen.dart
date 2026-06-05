import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_broadcast_screen.dart'; // Import the broadcast screen

class StudentOrganizationsDetailsScreen extends StatefulWidget {
  final String orgId;
  const StudentOrganizationsDetailsScreen({super.key, required this.orgId});

  @override
  State<StudentOrganizationsDetailsScreen> createState() =>
      _StudentOrganizationsDetailsScreenState();
}

class _StudentOrganizationsDetailsScreenState
    extends State<StudentOrganizationsDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final org = snapshot.data!.data() as Map<String, dynamic>;
          final officers = (org['officers'] as List?) ?? [];
          final events = (org['events'] as List?) ?? [];
          final announcements = (org['announcements'] as List?) ?? [];

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Organization'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
              actions: [
                // Broadcast Channel Icon
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentBroadcastScreen(
                          orgId: widget.orgId,
                          orgName: org['name'] ?? 'Organization',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.radio, color: Colors.orange),
                ),
                const SizedBox(width: 8),
                // Event Gallery Icon
                IconButton(
                  onPressed: () {
                    // TODO: Navigate to Event Gallery Screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event Gallery - Coming Soon')),
                    );
                  },
                  icon: const Icon(Icons.grid_view_rounded, color: Colors.orange),
                ),
                const SizedBox(width: 16),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Cover Image
                  Stack(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          image: org['coverUrl'] != null && (org['coverUrl'] as String).isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(org['coverUrl']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: org['coverUrl'] == null || (org['coverUrl'] as String).isEmpty
                            ? Center(
                                child: Icon(Icons.business,
                                    size: 60, color: Colors.orange[200]),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -30,
                        left: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white,
                            backgroundImage: (org['logoUrl'] != null &&
                                    (org['logoUrl'] as String).isNotEmpty)
                                ? NetworkImage(org['logoUrl'])
                                : null,
                            child: (org['logoUrl'] == null ||
                                    (org['logoUrl'] as String).isEmpty)
                                ? Text(
                                    (org['name'] ?? 'O')[0],
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Organization Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Organization Name
                        Text(
                          org['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Category / Type
                        Text(
                          org['category'] ?? 'Student Council',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // ACCREDITED badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            'ACCREDITED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ABOUT Section
                        const Text(
                          'ABOUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          org['description'] ?? 'No description available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Organization Adviser
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_outline,
                                    color: Colors.orange),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Organization Adviser',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      org['adviserName'] ?? 'No adviser listed',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (org['adviserTitle'] != null)
                                      Text(
                                        org['adviserTitle'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Executive Officers Section
                        const Text(
                          'Executive Officers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (officers.isEmpty)
                          Text(
                            'No officers listed',
                            style: TextStyle(color: Colors.grey[500]),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: officers.length,
                            separatorBuilder: (_, __) => const Divider(height: 0),
                            itemBuilder: (context, index) {
                              final officer = officers[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange[100],
                                  child: Text(
                                    (officer['name'] ?? '')[0],
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  officer['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  officer['position'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // Upcoming Events Section
                        const Text(
                          'Upcoming Events',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (events.isEmpty)
                          Text(
                            'No upcoming events',
                            style: TextStyle(color: Colors.grey[500]),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            (event['date'] ?? '')
                                                .toString()
                                                .split(' ')
                                                .first,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                          Text(
                                            (event['date'] ?? '')
                                                .toString()
                                                .split(' ')
                                                .last,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event['title'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 12, color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(
                                                event['location'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(Icons.access_time,
                                                  size: 12, color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(
                                                event['time'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // Recent Announcements Section
                        const Text(
                          'Recent Announcements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (announcements.isEmpty)
                          Text(
                            'No announcements available',
                            style: TextStyle(color: Colors.grey[500]),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: announcements.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final announcement = announcements[index];
                              final isUrgent = announcement['type'] == 'urgent' ||
                                  (announcement['title'] ?? '').contains('URGENT');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUrgent ? Colors.red[50] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: isUrgent
                                      ? Border.all(color: Colors.red[200]!)
                                      : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isUrgent
                                            ? Colors.red[100]
                                            : Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isUrgent
                                            ? Icons.priority_high
                                            : Icons.campaign,
                                        size: 18,
                                        color: isUrgent ? Colors.red : Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            announcement['title'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isUrgent ? Colors.red[800] : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            announcement['content'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            announcement['timeAgo'] ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 32),
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
// lib/widgets/student/announcements_feed.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../screens/student/student_announcements_screen.dart';

class AnnouncementsFeed extends StatelessWidget {
  final Function(AnnouncementData)? onTap;
  
  const AnnouncementsFeed({super.key, this.onTap});

  Stream<QuerySnapshot> get _announcementsStream =>
      FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .limit(4)
          .snapshots();

  String _formatTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            
            // Convert to AnnouncementData
            final announcement = AnnouncementData.fromFirestore(doc);
            
            final title = data['title'] as String? ?? 'Untitled announcement';
            final content = data['content'] as String? ?? '';
            final timestamp = data['timestamp'];

            return GestureDetector(
              onTap: () {
                if (onTap != null) {
                  onTap!(announcement);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(158, 158, 158, 0.05),
                      spreadRadius: 1,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 107, 53, 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign, color: Color(0xFFFF6B35)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            content,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(timestamp),
                            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
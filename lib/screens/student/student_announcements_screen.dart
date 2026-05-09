import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data – replace with Firestore later
    final announcements = [
      {
        'pinned': true,
        'title': 'CICT FIREFOX DANCERS',
        'details':
            'EVENT UPDATE\nID: CICT-2024-089\nFRX CREW ANNOUNCEMENT\nFRX CREW\nORGANIZATION\nOct 24, 2023\n10:30 AM',
        'likes': 42,
        'hearts': 18,
        'comments': 5,
      },
      {
        'pinned': false,
        'title': 'BLIS ANNOUNCEMENT',
        'details':
            'EVENT UPDATE\nID: CICT-2024-089\nBLIS ANNOUNCEMENT\nBLIS\nORGANIZATION\nOct 24, 2023\n10:30 AM',
        'likes': 67,
        'hearts': 47,
        'comments': 6,
      },
      {
        'pinned': false,
        'title': 'INFORMATION SYSTEMS SYNERGY SOCIETY',
        'details':
            'EVENT UPDATE\nID: CICT-2024-089\nCURSOR ANOUNCEMENT\nCURSOR ANNOUNCEMENT\nORGANIZATION\nOct 24, 2023\n10:30 AM',
        'likes': 20,
        'hearts': 22,
        'comments': 5,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final ann = announcements[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ann['pinned'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PINNED',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    ann['title'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ann['details'] as String, // ✅ cast to String
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.thumb_up_alt_outlined,
                          size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text('${ann['likes']}'),
                      const SizedBox(width: 16),
                      Icon(Icons.favorite_border,
                          size: 18, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${ann['hearts']}'),
                      const SizedBox(width: 16),
                      Icon(Icons.comment_outlined,
                          size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text('${ann['comments']}'),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () {
                          // TODO: implement share
                        },
                      ),
                    ],
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

import 'package:flutter/material.dart';

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final announcements = [
      {
        'title': 'BLIS ANNOUNCEMENT',
        'id': 'CICT-2024-089',
        'org': 'BLIS ORGANIZATION',
        'date': 'Oct 24, 2023',
        'time': '10:30 AM',
        'imageUrl':
            'https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?w=800&q=60',
        'logoUrl':
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Logo.svg/120px-Logo.svg.png',
        'likes': 42,
        'reactions': 18,
        'comments': 5,
        'shares': 3,
      },
      {
        'title': 'SWITS ANNOUNCEMENT',
        'id': 'CICT-2024-090',
        'org': 'SWITS ORGANIZATION',
        'date': 'Nov 10, 2023',
        'time': '2:00 PM',
        'imageUrl':
            'https://images.unsplash.com/photo-1529333166437-7750a6dd5a70?w=800&q=60',
        'logoUrl':
            'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Logo.svg/120px-Logo.svg.png',
        'likes': 30,
        'reactions': 12,
        'comments': 8,
        'shares': 2,
      },
      {
        'title': 'INFORMATION SYSTEMS SYNERGY SOCIETY',
        'id': 'CICT-2024-091',
        'org': 'IS Synergy Society',
        'date': 'Oct 24, 2023',
        'time': '10:30 AM',
        'imageUrl':
            'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&q=60',
        'logoUrl':
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Bulacan_State_University_logo.png/120px-Bulacan_State_University_logo.png',
        'likes': 54,
        'reactions': 22,
        'comments': 9,
        'shares': 4,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final ann = announcements[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image banner
                Image.network(
                  ann['imageUrl'] as String,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 50),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ann['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${ann['id']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                NetworkImage(ann['logoUrl'] as String),
                            backgroundColor: Colors.grey[200],
                          ),
                          const SizedBox(width: 10),
                          Text(
                            ann['org'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                ann['date'] as String,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87),
                              ),
                              Text(
                                ann['time'] as String,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Engagement row (gray icons)
                      Row(
                        children: [
                          Icon(Icons.thumb_up_alt_outlined,
                              color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Text('${ann['likes']}',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 16),
                          Icon(Icons.favorite_border,
                              color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Text('${ann['reactions']}',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 16),
                          Icon(Icons.comment_outlined,
                              color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Text('${ann['comments']}',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 16),
                          Icon(Icons.share_outlined,
                              color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Text('${ann['shares']}',
                              style: const TextStyle(color: Colors.grey)),
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
    );
  }
}

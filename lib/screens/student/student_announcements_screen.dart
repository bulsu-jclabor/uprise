import 'package:flutter/material.dart';

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final announcements = [
      {
        'title': 'FRX CREW ANNOUNCEMENT',
        'id': 'CICT-2024-089',
        'org': 'FRX CREW',
        'orgSub': 'ORGANIZATION',
        'date': 'Oct 14, 2025',
        'time': '10:30 AM',
        'isPinned': true,
        'tag': 'EVENT UPDATE',
        'imageUrl':
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=60',
        'logoUrl':
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Logo.svg/120px-Logo.svg.png',
        'likes': 40,
        'reactions': 18,
        'comments': 5,
        'shares': 0,
      },
      {
        'title': 'BLIS ANNOUNCEMENT',
        'id': 'CICT-2024-090',
        'org': 'BLIS',
        'orgSub': 'ORGANIZATION',
        'date': 'Oct 24, 2025',
        'time': '10:30 AM',
        'isPinned': true,
        'tag': 'EVENT UPDATE',
        'imageUrl':
            'https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?w=800&q=60',
        'logoUrl':
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Logo.svg/120px-Logo.svg.png',
        'likes': 42,
        'reactions': 18,
        'comments': 5,
        'shares': 0,
      },
      {
        'title': 'INFORMATION SYSTEMS SYNERGY SOCIETY',
        'id': 'CICT-2024-091',
        'org': 'CURSOR ANNOUNCEMENT',
        'orgSub': 'ORGANIZATION',
        'date': 'Oct 24, 2025',
        'time': '10:30 AM',
        'isPinned': true,
        'tag': 'EVENT UPDATE',
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
        title: const Text(
          'Announcement',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: const Color(0xFFF2F2F2),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final ann = announcements[index];
          final isPinned = ann['isPinned'] as bool;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Banner Image with Pinned Badge ──
                Stack(
                  children: [
                    Image.network(
                      ann['imageUrl'] as String,
                      height: 155,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 155,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
                    ),
                    if (isPinned)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA726), // amber
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.push_pin, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Pinned',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tag row: EVENT UPDATE  |  ID ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ann['tag'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF888888),
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            ann['id'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // ── Announcement Title ──
                      Text(
                        ann['title'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Org Row ──
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                NetworkImage(ann['logoUrl'] as String),
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ann['org'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                ann['orgSub'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                ann['date'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                ann['time'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 10),

                      // ── Engagement Row ──
                      Row(
                        children: [
                          _EngagementItem(
                            icon: Icons.thumb_up_alt_outlined,
                            count: ann['likes'] as int,
                          ),
                          const SizedBox(width: 18),
                          _EngagementItem(
                            icon: Icons.favorite_border,
                            count: ann['reactions'] as int,
                          ),
                          const SizedBox(width: 18),
                          _EngagementItem(
                            icon: Icons.mode_comment_outlined,
                            count: ann['comments'] as int,
                          ),
                          const Spacer(),
                          _EngagementItem(
                            icon: Icons.share_outlined,
                            count: ann['shares'] as int,
                            showCount: false,
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
    );
  }
}

class _EngagementItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool showCount;

  const _EngagementItem({
    required this.icon,
    required this.count,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF999999)),
        if (showCount) ...[
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ],
    );
  }
}
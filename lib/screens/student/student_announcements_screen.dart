import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────
class AnnouncementData {
  final String title;
  final String id;
  final String org;
  final String orgSub;
  final String date;
  final String time;
  final bool isPinned;
  final String tag;
  final String imageUrl;
  final String logoUrl;
  final int likes;
  final int reactions;
  final int comments;
  final int shares;
  final String body;
  final List<String> hashtags;
  final List<Map<String, String>> attachments;

  const AnnouncementData({
    required this.title,
    required this.id,
    required this.org,
    required this.orgSub,
    required this.date,
    required this.time,
    required this.isPinned,
    required this.tag,
    required this.imageUrl,
    required this.logoUrl,
    required this.likes,
    required this.reactions,
    required this.comments,
    required this.shares,
    required this.body,
    required this.hashtags,
    required this.attachments,
  });
}

// ─────────────────────────────────────────────────────────────
//  SAMPLE DATA
// ─────────────────────────────────────────────────────────────
final List<AnnouncementData> sampleAnnouncements = [
  AnnouncementData(
    title: 'FRX CREW ANNOUNCEMENT',
    id: 'CICT-2024-089',
    org: 'FRX CREW',
    orgSub: 'ORGANIZATION',
    date: 'Oct 14, 2025',
    time: '10:30 AM',
    isPinned: true,
    tag: 'EVENT UPDATE',
    imageUrl:
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=60',
    logoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Logo.svg/120px-Logo.svg.png',
    likes: 40,
    reactions: 18,
    comments: 5,
    shares: 0,
    body:
        'Good day, CICTians! We are thrilled to announce that the schedule for the highly anticipated CICT Week 2024 has been finalized. This year\'s theme, "Innovation Beyond Limits," promises a week filled with learning, competition, and camaraderie.\n\nPlease be informed of the following key directives:\n\nAll organization representatives must attend the first briefing tomorrow at the Multi-Purpose Hall at 2:00 PM.\n\nAttendance is mandatory for all SC members and local org officers.\n\nOfficial registration for technical competitions starts this Friday.\n\nLet\'s work together to make this year\'s celebration our biggest success yet! For any questions, please coordinate with your respective year-level representatives.',
    hashtags: ['#CICTWeek2024', '#OneCICT', '#TechExcellence'],
    attachments: [
      {'name': 'CICT_Week_Full_Schedule...', 'type': 'pdf'},
      {'name': 'Event_Map_Layout.jpg', 'type': 'image'},
    ],
  ),
  AnnouncementData(
    title: 'BLIS ANNOUNCEMENT',
    id: 'CICT-2024-090',
    org: 'BLIS',
    orgSub: 'ORGANIZATION',
    date: 'Oct 24, 2025',
    time: '10:30 AM',
    isPinned: true,
    tag: 'EVENT UPDATE',
    imageUrl:
        'https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?w=800&q=60',
    logoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Logo.svg/120px-Logo.svg.png',
    likes: 42,
    reactions: 18,
    comments: 5,
    shares: 0,
    body:
        'Dear BLIS members,\n\nThis is an official announcement regarding upcoming activities for CICT Week 2024. Kindly take note of the schedule and make sure to participate actively in all events.\n\nFull details will be shared during the general assembly. Please check the attached schedule for more information.',
    hashtags: ['#BLIS2024', '#CICTWeek', '#LibraryScience'],
    attachments: [
      {'name': 'BLIS_Schedule_2024.pdf', 'type': 'pdf'},
    ],
  ),
  AnnouncementData(
    title: 'INFORMATION SYSTEMS SYNERGY SOCIETY',
    id: 'CICT-2024-091',
    org: 'CURSOR ANNOUNCEMENT',
    orgSub: 'ORGANIZATION',
    date: 'Oct 24, 2025',
    time: '10:30 AM',
    isPinned: true,
    tag: 'EVENT UPDATE',
    imageUrl:
        'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&q=60',
    logoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Bulacan_State_University_logo.png/120px-Bulacan_State_University_logo.png',
    likes: 54,
    reactions: 22,
    comments: 9,
    shares: 4,
    body:
        'Greetings from the Information Systems Synergy Society!\n\nWe are excited to announce our upcoming tech competition and exhibit during CICT Week 2024. All IS students are highly encouraged to join and showcase their skills.\n\nRegistration forms are available at the IS Department. Deadline for submission is on October 27, 2025.',
    hashtags: ['#IS3CICT', '#SynergySociety', '#TechFest2024'],
    attachments: [
      {'name': 'IS3_Registration_Form.pdf', 'type': 'pdf'},
      {'name': 'Competition_Guidelines.pdf', 'type': 'pdf'},
      {'name': 'Exhibit_Map.jpg', 'type': 'image'},
    ],
  ),
];

// ─────────────────────────────────────────────────────────────
//  LIST SCREEN
// ─────────────────────────────────────────────────────────────
class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        itemCount: sampleAnnouncements.length,
        itemBuilder: (context, index) {
          final ann = sampleAnnouncements[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnnouncementDetailScreen(announcement: ann),
                ),
              );
            },
            child: _AnnouncementCard(ann: ann),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CARD WIDGET (list item)
// ─────────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final AnnouncementData ann;
  const _AnnouncementCard({required this.ann});

  @override
  Widget build(BuildContext context) {
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
                ann.imageUrl,
                height: 155,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 155,
                  color: Colors.grey[300],
                  child:
                      const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
              if (ann.isPinned)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726),
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
                // ── Tag row ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ann.tag,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF888888),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      ann.id,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ── Title ──
                Text(
                  ann.title,
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
                      backgroundImage: NetworkImage(ann.logoUrl),
                      backgroundColor: Colors.grey[200],
                      onBackgroundImageError: (_, __) {},
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ann.org,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          ann.orgSub,
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
                          ann.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          ann.time,
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
                        count: ann.likes),
                    const SizedBox(width: 18),
                    _EngagementItem(
                        icon: Icons.favorite_border,
                        count: ann.reactions),
                    const SizedBox(width: 18),
                    _EngagementItem(
                        icon: Icons.mode_comment_outlined,
                        count: ann.comments),
                    const Spacer(),
                    _EngagementItem(
                      icon: Icons.share_outlined,
                      count: ann.shares,
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
  }
}

// ─────────────────────────────────────────────────────────────
//  DETAIL SCREEN
// ─────────────────────────────────────────────────────────────
class AnnouncementDetailScreen extends StatefulWidget {
  final AnnouncementData announcement;
  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  bool _dismissed = false;

  AnnouncementData get ann => widget.announcement;

  void _handleDismiss() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DismissConfirmSheet(
        onConfirm: () {
          Navigator.pop(context); // close sheet
          setState(() => _dismissed = true);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) Navigator.pop(context); // go back to list
          });
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Collapsible header with banner ──
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        size: 20, color: Colors.black),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Announcement',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                centerTitle: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        ann.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image,
                              size: 60, color: Colors.grey),
                        ),
                      ),
                      // gradient overlay so title is readable
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x77000000),
                              Color(0x00000000),
                            ],
                          ),
                        ),
                      ),
                      if (ann.isPinned)
                        Positioned(
                          top: 56,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA726),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.push_pin,
                                    size: 12, color: Colors.white),
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
                ),
              ),

              // ── Body content ──
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tag + ID row
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ann.tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF888888),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  ann.id,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Title
                            Text(
                              ann.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Org row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(ann.logoUrl),
                                  backgroundColor: Colors.grey[200],
                                  onBackgroundImageError: (_, __) {},
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ann.org,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      ann.orgSub,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      ann.date,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      ann.time,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(
                                height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 16),

                            // Body text
                            Text(
                              ann.body,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Hashtags
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: ann.hashtags
                                  .map(
                                    (tag) => Text(
                                      tag,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1565C0),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 20),

                            // Attachments
                            if (ann.attachments.isNotEmpty) ...[
                              Text(
                                'ATTACHMENTS (${ann.attachments.length})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF888888),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...ann.attachments.map(
                                (att) => _AttachmentTile(attachment: att),
                              ),
                              const SizedBox(height: 8),
                            ],

                            const Divider(
                                height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 10),

                            // Engagement row
                            Row(
                              children: [
                                _EngagementItem(
                                    icon: Icons.thumb_up_alt_outlined,
                                    count: ann.likes),
                                const SizedBox(width: 18),
                                _EngagementItem(
                                    icon: Icons.favorite_border,
                                    count: ann.reactions),
                                const SizedBox(width: 18),
                                _EngagementItem(
                                    icon: Icons.mode_comment_outlined,
                                    count: ann.comments),
                                const Spacer(),
                                _EngagementItem(
                                  icon: Icons.share_outlined,
                                  count: ann.shares,
                                  showCount: false,
                                ),
                              ],
                            ),

                            // Bottom padding for the sticky button
                            const SizedBox(height: 90),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky "Dismiss Announcement" button ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _dismissed ? null : _handleDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dismissed
                          ? Colors.grey[400]
                          : const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _dismissed
                          ? 'Announcement Dismissed'
                          : 'Dismiss Announcement',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ATTACHMENT TILE
// ─────────────────────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final Map<String, String> attachment;
  const _AttachmentTile({required this.attachment});

  IconData get _icon {
    switch (attachment['type']) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.attach_file;
    }
  }

  Color get _iconColor {
    switch (attachment['type']) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'image':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 20, color: _iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              attachment['name'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.download_outlined,
              size: 20, color: Color(0xFF999999)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DISMISS CONFIRM BOTTOM SHEET
// ─────────────────────────────────────────────────────────────
class _DismissConfirmSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DismissConfirmSheet({
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.announcement_outlined,
              size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          const Text(
            'Dismiss Announcement?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This announcement will be removed from your list. You can view it again from the archive.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED ENGAGEMENT ITEM WIDGET
// ─────────────────────────────────────────────────────────────
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
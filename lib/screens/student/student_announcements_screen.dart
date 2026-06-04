import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

ImageProvider _studentImageProvider(String url) {
  if (url.isEmpty) return const AssetImage('assets/placeholder.png');
  if (url.startsWith('data:image')) {
    return MemoryImage(base64Decode(url.split(',').last));
  }
  // Raw base64 string (org side stores it without the data: prefix)
  if (!url.startsWith('http')) {
    try {
      return MemoryImage(base64Decode(url));
    } catch (_) {}
  }
  return NetworkImage(url);
}

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

  factory AnnouncementData.fromFirestore(DocumentSnapshot doc) {
  final d = doc.data() as Map<String, dynamic>? ?? {};
  final timestamp = d['timestamp'];
  final dateTime = timestamp is Timestamp
      ? timestamp.toDate()
      : timestamp is DateTime
          ? timestamp
          : DateTime.now();

  // ── FIX: read imageBase64 (org field), fall back to imageUrl ──
  final rawImage = d['imageBase64'] as String? ?? d['imageUrl'] as String? ?? '';

  return AnnouncementData(
    title: d['title'] as String? ?? '',
    id: doc.id,
    org: d['authorName'] as String? ?? 'Organization',
    orgSub: (d['category'] as String?)?.toUpperCase() ?? 'ANNOUNCEMENT',
    date: DateFormat('MMM dd, yyyy').format(dateTime),
    time: DateFormat('h:mm a').format(dateTime),
    isPinned: d['pinned'] as bool? ?? false,   // also fix: was always false
    tag: (d['targetAudience'] as String?)?.toUpperCase() ??
         (d['category'] as String?)?.toUpperCase() ?? 'ANNOUNCEMENT',
    imageUrl: rawImage,                         // pass base64 string here
    logoUrl: d['logoUrl'] as String? ?? '',
    likes: 0,
    reactions: 0,
    comments: 0,
    shares: 0,
    body: d['content'] as String? ?? '',
    hashtags: [],
    attachments: ((d['attachmentsBase64'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((att) => {
              'name': att['name'] as String? ?? '',
              'type': _guessType(att['name'] as String? ?? ''),
            })
        .toList(),
  );
}

// helper to guess attachment type from filename
static String _guessType(String name) {
  final ext = name.split('.').last.toLowerCase();
  if (ext == 'pdf') return 'pdf';
  if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
  return 'file';
}
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

  Stream<QuerySnapshot> get _announcementsStream =>
      FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .snapshots();

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
      body: StreamBuilder<QuerySnapshot>(
        stream: _announcementsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load announcements.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign_outlined,
                        size: 56, color: Color(0xFF616161)),
                    const SizedBox(height: 16),
                    const Text(
                      'No announcements yet.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'New posts from your organizations will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = docs
              .map((doc) => AnnouncementData.fromFirestore(doc))
              .toList();

          // compute quick summary counts
          final total = items.length;
          final pinned = items.where((a) => a.isPinned).length;
          final withAttachments = items.where((a) => a.attachments.isNotEmpty).length;

          // Render a single ListView where index 0 is the summary cards header
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      _SummaryCardSmall(title: 'Total', value: '$total'),
                      const SizedBox(width: 12),
                      _SummaryCardSmall(title: 'Pinned', value: '$pinned'),
                      const SizedBox(width: 12),
                      _SummaryCardSmall(title: 'With Attachments', value: '$withAttachments'),
                    ],
                  ),
                );
              }

              final ann = items[index - 1];
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
              ann.imageUrl.isNotEmpty
                  ? Image(
                      image: _studentImageProvider(ann.imageUrl),
                      height: 155,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 155,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image,
                            size: 50, color: Colors.grey),
                      ),
                    )
                  : Container(
                      height: 155,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image,
                          size: 50, color: Colors.grey),
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
                // ── Tag / post metadata row ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ann.tag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555555),
                          letterSpacing: 0.4,
                        ),
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

                const SizedBox(height: 8),

                // ── Title ──
                Text(
                  ann.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  ann.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ann.hashtags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF7FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFB3E5FC)),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),

                // ── Engagement Row ──
                Row(
                  children: [
                    _EngagementItem(
                        icon: Icons.thumb_up_alt_outlined,
                        count: ann.likes),
                    const SizedBox(width: 16),
                    _EngagementItem(
                        icon: Icons.favorite_border,
                        count: ann.reactions),
                    const SizedBox(width: 16),
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
                      ann.imageUrl.isNotEmpty
                          ? Image(
                              image: _studentImageProvider(ann.imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image,
                                    size: 60, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image,
                                  size: 60, color: Colors.grey),
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
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: ann.logoUrl.isNotEmpty
                                      ? NetworkImage(ann.logoUrl)
                                      : null,
                                  child: ann.logoUrl.isEmpty
                                      ? const Icon(Icons.campaign,
                                          size: 20, color: Colors.white)
                                      : null,
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
                                height: 1.7,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Hashtags
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: ann.hashtags
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDF7FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 20),

                            if (ann.attachments.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFD),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFDEE7F1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attachments',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4B5878),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ...ann.attachments.map(
                                      (att) => _AttachmentTile(
                                          attachment: att),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            const Divider(
                                height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 14),

                            // Action buttons
                            Row(
                              children: [
                                _PostActionButton(
                                  icon: Icons.thumb_up_alt_outlined,
                                  label: 'Like',
                                  count: ann.likes,
                                ),
                                const SizedBox(width: 10),
                                _PostActionButton(
                                  icon: Icons.mode_comment_outlined,
                                  label: 'Comment',
                                  count: ann.comments,
                                ),
                                const SizedBox(width: 10),
                                _PostActionButton(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  count: ann.shares,
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

class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: () {},
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: const Color(0xFF37474F),
          backgroundColor: const Color(0xFFF7F9FB),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          '$label${count > 0 ? ' · $count' : ''}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
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

// ─────────────────────────────────────────────────────────────
// Small summary card used at top of the list to match admin UI
// ─────────────────────────────────────────────────────────────
class _SummaryCardSmall extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryCardSmall({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
          ],
        ),
      ),
    );
  }
}
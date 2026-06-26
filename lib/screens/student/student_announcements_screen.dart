// lib/screens/student/student_announcements_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/student/event_registration_form_dialog.dart';

// ─────────────────────────────────────────────────────────────
// Custom Colors - UNIFORM (Colors.orange)
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF5F5F5);
}

ImageProvider _studentImageProvider(String url) {
  if (url.isEmpty) return const AssetImage('assets/placeholder.png');
  if (url.startsWith('data:image')) {
    return MemoryImage(base64Decode(url.split(',').last));
  }
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
  final String id;
  final String title;
  final String org;
  final String orgSub;
  final String date;
  final String time;
  final bool isPinned;
  final String tag;
  final String imageUrl;
  final String logoUrl;
  final String body;
  final List<String> hashtags;
  final List<Map<String, String>> attachments;
  final String linkedEventId;
  final String linkedProposalId;
  final String linkedEventTitle;

  AnnouncementData({
    required this.id,
    required this.title,
    required this.org,
    required this.orgSub,
    required this.date,
    required this.time,
    required this.isPinned,
    required this.tag,
    required this.imageUrl,
    required this.logoUrl,
    required this.body,
    required this.hashtags,
    required this.attachments,
    this.linkedEventId = '',
    this.linkedProposalId = '',
    this.linkedEventTitle = '',
  });

  factory AnnouncementData.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = d['timestamp'];
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : timestamp is DateTime
            ? timestamp
            : DateTime.now();

    final rawImage = d['imageBase64'] as String? ?? d['imageUrl'] as String? ?? '';

    return AnnouncementData(
      id: doc.id,
      title: d['title'] as String? ?? '',
      org: d['authorName'] as String? ?? 'Organization',
      orgSub: (d['category'] as String?)?.toUpperCase() ?? 'ANNOUNCEMENT',
      date: DateFormat('MMM dd, yyyy').format(dateTime),
      time: DateFormat('h:mm a').format(dateTime),
      isPinned: d['pinned'] as bool? ?? false,
      tag: (d['targetAudience'] as String?)?.toUpperCase() ??
          (d['category'] as String?)?.toUpperCase() ?? 'ANNOUNCEMENT',
      imageUrl: rawImage,
      logoUrl: d['logoUrl'] as String? ?? '',
      body: d['content'] as String? ?? '',
      hashtags: [],
      attachments: ((d['attachmentsBase64'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((att) => {
                'name': att['name'] as String? ?? '',
                'type': _guessType(att['name'] as String? ?? ''),
                'url': att['url'] as String? ?? '',
                'data': att['data'] as String? ?? '',
              })
          .toList(),
      linkedEventId: d['linkedEventId'] as String? ?? '',
      linkedProposalId: d['linkedProposalId'] as String? ?? '',
      linkedEventTitle: d['linkedEventTitle'] as String? ?? '',
    );
  }

  static String _guessType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
    return 'file';
  }
}

// ─────────────────────────────────────────────────────────────
//  LIST SCREEN
// ─────────────────────────────────────────────────────────────
class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  State<StudentAnnouncementsScreen> createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  // Created once, not a getter — re-evaluating .snapshots() on every
  // rebuild was re-subscribing to Firestore from scratch each time. Also
  // now excludes scheduled/draft announcements (isPublished: false) that
  // were showing up before they were actually due.
  late final Stream<QuerySnapshot> _announcementsStream =
      FirebaseFirestore.instance
          .collection('announcements')
          .where('isPublished', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final ann = items[index];
              return _AnnouncementCard(ann: ann);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ANNOUNCEMENT CARD (No ">" icon)
// ─────────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final AnnouncementData ann;

  const _AnnouncementCard({required this.ann});

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcement: ann),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner Image ──
            Stack(
              children: [
                ann.imageUrl.isNotEmpty
                    ? Image(
                        image: _studentImageProvider(ann.imageUrl),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade300, Colors.orange.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 50,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade300, Colors.orange.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 50,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                
                // ── Gradient Overlay ──
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
                
                // ── Tag Badge on Image ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      ann.tag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                
                // ── Date on Image ──
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ann.date,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Organization Row ──
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: ann.logoUrl.isNotEmpty
                              ? Image.network(
                                  ann.logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.business_center_outlined,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                )
                              : Icon(
                                  Icons.business_center_outlined,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
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
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Title ──
                  Text(
                    ann.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // ── Body preview ──
                  Text(
                    ann.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Register for Event ──
                  if (ann.linkedProposalId.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => DynamicRegistrationDialog.show(
                          context,
                          proposalId: ann.linkedProposalId,
                          eventId: ann.linkedEventId,
                          eventTitle: ann.linkedEventTitle,
                        ),
                        icon: const Icon(Icons.event_available_rounded, size: 16),
                        label: Text('Register for ${ann.linkedEventTitle}',
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Read More Indicator ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Read more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DETAIL SCREEN (With "Mark as Read" button at bottom)
// ─────────────────────────────────────────────────────────────
class AnnouncementDetailScreen extends StatefulWidget {
  final AnnouncementData announcement;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
  });

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  bool _isMarkedAsRead = false;

  Future<void> _markAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .where('data.announcementId', isEqualTo: widget.announcement.id)
          .where('userId', isEqualTo: user.uid)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'isRead': true});
        }
      });

      setState(() {
        _isMarkedAsRead = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as read!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ann = widget.announcement;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Main Content ──
          CustomScrollView(
            slivers: [
              // ── App Bar with Hero Image ──
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      ann.imageUrl.isNotEmpty
                          ? Image(
                              image: _studentImageProvider(ann.imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange.shade300, Colors.orange.shade700],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade300, Colors.orange.shade700],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                      
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                      
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            ann.tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Body ──
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title ──
                      Text(
                        ann.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Organization Info ──
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF5F5F5),
                            ),
                            child: ClipOval(
                              child: ann.logoUrl.isNotEmpty
                                  ? Image.network(
                                      ann.logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.business_center_outlined,
                                        size: 22,
                                        color: Colors.orange,
                                      ),
                                    )
                                  : Icon(
                                      Icons.business_center_outlined,
                                      size: 22,
                                      color: Colors.orange,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ann.org,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  ann.orgSub,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                ann.date,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                ann.time,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFEEEEEE), thickness: 1),
                      const SizedBox(height: 20),

                      // ── Body ──
                      Text(
                        ann.body,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.8,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Register for Event ──
                      if (ann.linkedProposalId.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Event Registration',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Register for ${ann.linkedEventTitle}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => DynamicRegistrationDialog.show(
                                    context,
                                    proposalId: ann.linkedProposalId,
                                    eventId: ann.linkedEventId,
                                    eventTitle: ann.linkedEventTitle,
                                  ),
                                  icon: const Icon(Icons.event_available_rounded, size: 18),
                                  label: const Text(
                                    'Register Now',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Hashtags ──
                      if (ann.hashtags.isNotEmpty) ...[
                        const Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: ann.hashtags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Attachments with Count ──
                      if (ann.attachments.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Attachments',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${ann.attachments.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFDEE7F1),
                            ),
                          ),
                          child: Column(
                            children: ann.attachments.asMap().entries.map(
                              (entry) {
                                final index = entry.key;
                                final att = entry.value;
                                return Column(
                                  children: [
                                    _AttachmentTile(
                                      attachment: att,
                                      index: index,
                                    ),
                                    if (index < ann.attachments.length - 1)
                                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                  ],
                                );
                              },
                            ).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Extra space for bottom button ──
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom Button (Mark as Read) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: ElevatedButton.icon(
                    onPressed: _isMarkedAsRead ? null : _markAsRead,
                    icon: Icon(
                      _isMarkedAsRead ? Icons.check_circle_rounded : Icons.mark_email_read_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isMarkedAsRead ? 'Marked as Read ✓' : 'Mark as Read',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMarkedAsRead ? Colors.green : Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
//  ATTACHMENT TILE (With Actual Download via Share)
// ─────────────────────────────────────────────────────────────
class _AttachmentTile extends StatefulWidget {
  final Map<String, String> attachment;
  final int index;

  const _AttachmentTile({
    required this.attachment,
    required this.index,
  });

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  Future<void> _downloadAttachment() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final fileName = widget.attachment['name'] ?? 'file_${widget.index}';
      final fileUrl = widget.attachment['url'] ?? '';

      if (fileUrl.isEmpty) {
        throw Exception('File URL is empty');
      }

      // Download the file
      final response = await http.get(Uri.parse(fileUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      
      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Downloaded: $fileName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Downloaded: $fileName',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Download failed: ${e.toString().replaceAll('Exception: ', '')}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  IconData get _icon {
    switch (widget.attachment['type']) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.attach_file;
    }
  }

  Color get _iconColor {
    switch (widget.attachment['type']) {
      case 'pdf':
        return Colors.red.shade600;
      case 'image':
        return Colors.blue.shade600;
      default:
        return Colors.grey;
    }
  }

  String _getFileSize() {
    final sizes = ['1.2 MB', '2.5 MB', '856 KB', '4.1 MB', '723 KB'];
    return sizes[widget.index % sizes.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment['name'] ?? 'File',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getFileSize(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          _isDownloading
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _downloadProgress,
                        strokeWidth: 2.5,
                        color: Colors.orange,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: _downloadAttachment,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
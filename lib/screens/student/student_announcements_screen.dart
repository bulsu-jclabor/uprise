// lib/screens/student/student_announcements_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/student/event_registration_form_dialog.dart';
import '../../widgets/student/app_colors.dart';


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
                'base64': att['base64'] as String? ?? '',
                'size': att['size'] as String? ?? '',
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

  late final Stream<QuerySnapshot> _announcementsStream =
      FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _announcementsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryDark,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load announcements',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final docs = (snapshot.data?.docs ?? []).where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['isPublished'] != false;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.campaign_outlined,
                        size: 48,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No announcements yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'New posts from your organizations\nwill appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.5,
                      ),
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
//  ANNOUNCEMENT CARD - UPRISE THEME COLORS
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
    final ann = this.ann;

    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.08),
              blurRadius: 16,
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
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 190,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primaryDark.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 190,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.primaryDark.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                
                // ── Gradient Overlay ──
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
                
                // ── Tag Badge ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ann.tag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
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
                        const SizedBox(width: 6),
                        Container(
                          width: 1,
                          height: 10,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ann.time,
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDark.withOpacity(0.1),
                        ),
                        child: ClipOval(
                          child: ann.logoUrl.isNotEmpty
                              ? Image(
                                  image: _studentImageProvider(ann.logoUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.business_center_outlined,
                                    size: 16,
                                    color: AppColors.primaryDark,
                                  ),
                                )
                              : Icon(
                                  Icons.business_center_outlined,
                                  size: 16,
                                  color: AppColors.primaryDark,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ann.org,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        ann.time,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
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
                      fontWeight: FontWeight.w700,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
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
                        icon: Icon(
                          Icons.event_available_rounded,
                          size: 16,
                          color: AppColors.primaryDark,
                        ),
                        label: Text(
                          'Register for ${ann.linkedEventTitle}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: BorderSide(
                            color: AppColors.primaryDark.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.primaryDark,
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
//  DETAIL SCREEN - UPRISE THEME COLORS (NO "Mark as Read")
// ─────────────────────────────────────────────────────────────
class AnnouncementDetailScreen extends StatelessWidget {
  final AnnouncementData announcement;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    final ann = announcement;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Hero Image ──
          SliverAppBar(
            expandedHeight: 300,
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
                                colors: [
                                  AppColors.primaryDark,
                                  AppColors.primaryDark.withOpacity(0.7),
                                ],
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
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primaryDark.withOpacity(0.7),
                              ],
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
                  
                  // ── Tag Badge ──
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ann.tag,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // ── Date on Image ──
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ann.date,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ann.time,
                            style: const TextStyle(
                              fontSize: 11,
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
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Organization Row ──
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDark.withOpacity(0.1),
                        ),
                        child: ClipOval(
                          child: ann.logoUrl.isNotEmpty
                              ? Image(
                                  image: _studentImageProvider(ann.logoUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.business_center_outlined,
                                    size: 24,
                                    color: AppColors.primaryDark,
                                  ),
                                )
                              : Icon(
                                  Icons.business_center_outlined,
                                  size: 24,
                                  color: AppColors.primaryDark,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ann.org,
                              style: const TextStyle(
                                fontSize: 15,
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
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                  const SizedBox(height: 20),

                  // ── Title ──
                  Text(
                    ann.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Body ──
                  Text(
                    ann.body,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      height: 1.8,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Register for Event ──
                  if (ann.linkedProposalId.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryDark.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_available_rounded,
                                color: AppColors.primaryDark,
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
                          const SizedBox(height: 6),
                          Text(
                            'Register for ${ann.linkedEventTitle}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
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
                                backgroundColor: AppColors.primaryDark,
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
                                color: AppColors.primaryDark.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Attachments ──
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
                            color: AppColors.primaryDark.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${ann.attachments.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEEEEEE),
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

                  const SizedBox(height: 40),
                ],
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

  Future<void> _downloadAttachment() async {
    setState(() => _isDownloading = true);

    try {
      final fileName = widget.attachment['name'] ?? 'file_${widget.index}';
      final base64Data = widget.attachment['base64'] ?? '';

      if (base64Data.isEmpty) {
        throw Exception('Attachment data is empty');
      }

      final bytes = base64Decode(base64Data);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

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
        setState(() => _isDownloading = false);
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
    final size = widget.attachment['size'];
    if (size != null && size.isNotEmpty) return size;
    final base64Data = widget.attachment['base64'] ?? '';
    if (base64Data.isEmpty) return '';
    final bytes = (base64Data.length * 3 / 4).round();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryDark,
                  ),
                )
              : GestureDetector(
                  onTap: _downloadAttachment,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
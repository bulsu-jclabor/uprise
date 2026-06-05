import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const Color primaryDark = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent = Color(0xFFF59E0B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FB);
  static const Color pageBg = Color(0xFFFBFCFE);
  static const Color feedBg = Color(0xFFF0F2F5);
  static const Color border = Color(0xFFE8ECF0);
  static const Color borderSoft = Color(0xFFE2E6EA);
  static const Color charcoal = Color(0xFF1A202C);
  static const Color textMid = Color(0xFF374151);
  static const Color darkGray = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF9AA5B4);
  static const Color info = Color(0xFF2563EB);
}

class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Image provider helper
// ─────────────────────────────────────────────────────────────────────────────
ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen - Student Broadcast (Read Only)
// ─────────────────────────────────────────────────────────────────────────────
class StudentBroadcastScreen extends StatelessWidget {
  final String orgId;
  final String orgName;

  const StudentBroadcastScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: AppBar(
        title: Text(
          orgName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _C.white,
        foregroundColor: _C.charcoal,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Search functionality
            },
            icon: const Icon(Icons.search, color: _C.darkGray),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChannelHeader(),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildChannelHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: _C.white,
        border: const Border(bottom: BorderSide(color: _C.border)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _C.primaryDark.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.campaign_rounded,
                color: _C.primaryDark, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Broadcast Channel',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _C.charcoal)),
                const SizedBox(height: 2),
                Text(orgName,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.darkGray)),
              ],
            ),
          ),
          // Message count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('broadcasts')
                .where('orgId', isEqualTo: orgId)
                .snapshots(),
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.info.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 13, color: _C.info),
                    const SizedBox(width: 6),
                    Text('$count',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.info)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.feedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: _DS.cardShadow,
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('broadcasts')
            .where('orgId', isEqualTo: orgId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _C.primaryDark));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final broadcasts = snapshot.data!.docs
              .map((doc) => BroadcastModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: broadcasts.length,
            itemBuilder: (context, index) {
              final broadcast = broadcasts[index];
              final showDateSeparator = index == 0 ||
                  !_isSameDay(broadcasts[index - 1].timestamp,
                      broadcast.timestamp);

              return Column(
                children: [
                  if (showDateSeparator)
                    _DateSeparator(timestamp: broadcast.timestamp),
                  _BroadcastCard(broadcast: broadcast),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _DS.cardShadow,
            ),
            child: const Icon(Icons.campaign_outlined,
                size: 40, color: _C.textFaint),
          ),
          const SizedBox(height: 16),
          Text('No announcements yet',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _C.charcoal)),
          const SizedBox(height: 6),
          Text('Check back later for updates.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: _C.darkGray)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _DS.cardShadow,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: _C.primaryDark, size: 28),
          ),
          const SizedBox(height: 14),
          Text('Failed to load announcements',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.charcoal)),
          const SizedBox(height: 6),
          Text(error,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: _C.darkGray)),
        ],
      ),
    );
  }

  bool _isSameDay(Timestamp a, Timestamp b) {
    final da = a.toDate();
    final db = b.toDate();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date Separator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final Timestamp timestamp;
  const _DateSeparator({required this.timestamp});

  String _label() {
    final now = DateTime.now();
    final date = timestamp.toDate();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _C.border, thickness: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.border),
            ),
            child: Text(_label(),
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _C.darkGray)),
          ),
          const Expanded(child: Divider(color: _C.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Broadcast Card - Student View (Read Only)
// ─────────────────────────────────────────────────────────────────────────────
class _BroadcastCard extends StatelessWidget {
  final BroadcastModel broadcast;

  const _BroadcastCard({required this.broadcast});

  String _timeLabel(Timestamp ts) =>
      DateFormat('h:mm a').format(ts.toDate());

  @override
  Widget build(BuildContext context) {
    final b = broadcast;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author and time
          Row(
            children: [
              Text(b.authorName,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.charcoal)),
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 3, color: _C.textFaint),
              const SizedBox(width: 8),
              Text(_timeLabel(b.timestamp),
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: _C.textFaint)),
              if (b.pinned) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.primaryDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin_rounded,
                          size: 10, color: _C.primaryDark),
                      const SizedBox(width: 4),
                      Text('Pinned',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _C.primaryDark)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Message Bubble
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB45309),
                  Color(0xFFD97706),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.primaryDark.withOpacity(0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image if present
                if (b.imageUrl != null && b.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(14),
                    ),
                    child: Image(
                      image: _imageProviderFromUrl(b.imageUrl!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.content.isNotEmpty)
                        Text(b.content,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                color: Colors.white,
                                height: 1.5)),
                      // Attachments
                      if (b.attachments.isNotEmpty) ...[
                        if (b.content.isNotEmpty) const SizedBox(height: 12),
                        ...b.attachments.map((att) =>
                            _AttachmentLink(attachment: att)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Like and Reply counts
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 14, color: _C.darkGray),
                    const SizedBox(width: 6),
                    Text('${b.likes}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.darkGray)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mode_comment_outlined,
                        size: 14, color: _C.darkGray),
                    const SizedBox(width: 6),
                    Text('${b.replyCount}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.darkGray)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachment Link (copies URL when tapped)
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentLink extends StatelessWidget {
  final Attachment attachment;

  const _AttachmentLink({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Copy link to clipboard
        Clipboard.setData(ClipboardData(text: attachment.url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(attachment.name,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_outlined, size: 13, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class Attachment {
  final String name;
  final String url;
  const Attachment({required this.name, required this.url});
}

class BroadcastModel {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final int likes;
  final int replyCount;
  final bool pinned;
  final Timestamp timestamp;
  final List<Attachment> attachments;
  final String? imageUrl;

  const BroadcastModel({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.likes,
    required this.replyCount,
    required this.pinned,
    required this.timestamp,
    required this.attachments,
    this.imageUrl,
  });

  factory BroadcastModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    String? imageUrl = d['imageUrl'] as String?;
    if (imageUrl == '') imageUrl = null;

    return BroadcastModel(
      id: doc.id,
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      likes: (d['likes'] as int?) ?? 0,
      replyCount: (d['replyCount'] as int?) ?? 0,
      pinned: (d['pinned'] as bool?) ?? false,
      timestamp: d['timestamp'] as Timestamp,
      attachments: ((d['attachments'] as List?) ?? [])
          .map((a) => Attachment(name: a['name'], url: a['url']))
          .toList(),
      imageUrl: imageUrl,
    );
  }
}
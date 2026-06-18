// lib/screens/student/student_announcements_screen.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/student/event_registration_form_dialog.dart';

// ─────────────────────────────────────────────────────────────
// Custom Colors - UNIFORM
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Color(0xFFBE4700);
  static const Color primaryLight = Color(0xFFD47A00);
  static const Color accent = Color(0xFFDA6937);
  static const Color background = Color(0xFFF8F9FA);
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
              return _AnnouncementCard(ann: ann, userId: _userId);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ANNOUNCEMENT CARD
// ─────────────────────────────────────────────────────────────
class _AnnouncementCard extends StatefulWidget {
  final AnnouncementData ann;
  final String? userId;

  const _AnnouncementCard({required this.ann, required this.userId});

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  late int _likes;
  late int _reactions;
  late int _comments;
  late int _shares;
  bool _isLiked = false;
  bool _isReacted = false;
  bool _isShared = false;
  String? _interactionId;

  @override
  void initState() {
    super.initState();
    _likes = 0;
    _reactions = 0;
    _comments = 0;
    _shares = 0;
    _checkUserInteraction();
  }

  Future<void> _checkUserInteraction() async {
    if (widget.userId == null) return;

    final interactionDoc = await FirebaseFirestore.instance
        .collection('announcement_interactions')
        .doc('${widget.ann.id}_${widget.userId}')
        .get();

    if (interactionDoc.exists) {
      final data = interactionDoc.data()!;
      setState(() {
        _isLiked = data['liked'] ?? false;
        _isReacted = data['reacted'] ?? false;
        _isShared = data['shared'] ?? false;
        _interactionId = interactionDoc.id;
      });
    }
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final doc = await FirebaseFirestore.instance
        .collection('announcement_counts')
        .doc(widget.ann.id)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _likes = data['likes'] ?? 0;
        _reactions = data['reactions'] ?? 0;
        _comments = data['comments'] ?? 0;
        _shares = data['shares'] ?? 0;
      });
    }
  }

  Future<void> _updateCount(String field, int change) async {
    final docRef = FirebaseFirestore.instance
        .collection('announcement_counts')
        .doc(widget.ann.id);

    await docRef.set({
      field: FieldValue.increment(change),
    }, SetOptions(merge: true));
  }

  Future<void> _updateInteraction(Map<String, dynamic> data) async {
    if (widget.userId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('announcement_interactions')
        .doc('${widget.ann.id}_${widget.userId}');

    await docRef.set(data, SetOptions(merge: true));
  }

  void _handleLike() async {
    if (widget.userId == null) return;

    setState(() {
      if (_isLiked) {
        _likes--;
        _isLiked = false;
      } else {
        _likes++;
        _isLiked = true;
      }
    });

    await _updateCount('likes', _isLiked ? 1 : -1);
    await _updateInteraction({'liked': _isLiked});
  }

  void _handleReact() async {
    if (widget.userId == null) return;

    setState(() {
      if (_isReacted) {
        _reactions--;
        _isReacted = false;
      } else {
        _reactions++;
        _isReacted = true;
      }
    });

    await _updateCount('reactions', _isReacted ? 1 : -1);
    await _updateInteraction({'reacted': _isReacted});
  }

  void _handleComment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        announcementId: widget.ann.id,
        onCommentAdded: () async {
          setState(() => _comments++);
          await _updateCount('comments', 1);
        },
      ),
    );
  }

  void _handleShare() async {
    if (widget.userId == null) return;

    setState(() {
      _shares++;
      _isShared = true;
    });

    await _updateCount('shares', 1);
    await _updateInteraction({'shared': true});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shared successfully!'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcement: widget.ann),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner Image ──
            widget.ann.imageUrl.isNotEmpty
                ? Image(
                    image: _studentImageProvider(widget.ann.imageUrl),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AppColors.primaryDark.withOpacity(0.1),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: AppColors.primaryDark.withOpacity(0.3),
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: 160,
                    width: double.infinity,
                    color: AppColors.primaryDark.withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: AppColors.primaryDark.withOpacity(0.3),
                      ),
                    ),
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
                          color: AppColors.primaryDark.withOpacity(0.1),
                        ),
                        child: ClipOval(
                          child: widget.ann.logoUrl.isNotEmpty
                              ? Image.network(
                                  widget.ann.logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.business_center_outlined,
                                    size: 18,
                                    color: AppColors.primaryDark,
                                  ),
                                )
                              : Icon(
                                  Icons.business_center_outlined,
                                  size: 18,
                                  color: AppColors.primaryDark,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ann.org,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              widget.ann.orgSub,
                              style: const TextStyle(
                                fontSize: 10,
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
                            widget.ann.date,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            widget.ann.time,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Tag Badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.ann.tag,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Title ──
                  Text(
                    widget.ann.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // ── Body preview ──
                  Text(
                    widget.ann.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Register for Event ──
                  if (widget.ann.linkedProposalId.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => DynamicRegistrationDialog.show(
                          context,
                          proposalId: widget.ann.linkedProposalId,
                          eventId: widget.ann.linkedEventId,
                          eventTitle: widget.ann.linkedEventTitle,
                        ),
                        icon: const Icon(Icons.event_available_rounded, size: 16),
                        label: Text('Register for ${widget.ann.linkedEventTitle}',
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.primaryDark),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Engagement Icons ──
                  Row(
                    children: [
                      _EngagementIcon(
                        icon: _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                        count: _likes,
                        isActive: _isLiked,
                        color: _isLiked ? AppColors.primaryDark : Colors.grey[500]!,
                        onTap: _handleLike,
                      ),
                      const SizedBox(width: 14),
                      _EngagementIcon(
                        icon: _isReacted ? Icons.favorite : Icons.favorite_border,
                        count: _reactions,
                        isActive: _isReacted,
                        color: _isReacted ? Colors.red.shade600 : Colors.grey[500]!,
                        onTap: _handleReact,
                      ),
                      const SizedBox(width: 14),
                      _EngagementIcon(
                        icon: Icons.mode_comment_outlined,
                        count: _comments,
                        isActive: false,
                        color: Colors.grey[500]!,
                        onTap: _handleComment,
                      ),
                      const Spacer(),
                      _EngagementIcon(
                        icon: Icons.share_outlined,
                        count: _shares,
                        isActive: _isShared,
                        color: _isShared ? AppColors.primaryDark : Colors.grey[500]!,
                        onTap: _handleShare,
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
//  ENGAGEMENT ICON (Icon only)
// ─────────────────────────────────────────────────────────────
class _EngagementIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _EngagementIcon({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  COMMENT SHEET
// ─────────────────────────────────────────────────────────────
class _CommentSheet extends StatefulWidget {
  final String announcementId;
  final VoidCallback onCommentAdded;

  const _CommentSheet({
    required this.announcementId,
    required this.onCommentAdded,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to comment.'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      String userName = 'Anonymous';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('students')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (userDoc.docs.isNotEmpty) {
          userName = userDoc.docs.first.data()['fullName'] ?? 'Anonymous';
        }
      } catch (_) {}

      await FirebaseFirestore.instance.collection('comments').add({
        'announcementId': widget.announcementId,
        'userId': user.uid,
        'userName': userName,
        'content': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      widget.onCommentAdded();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added!'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add Comment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your comment here...',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
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
                  onPressed: _isSubmitting ? null : _submitComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DETAIL SCREEN (No "Announcement" title)
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
  late int _likes;
  late int _reactions;
  late int _comments;
  late int _shares;
  bool _isLiked = false;
  bool _isReacted = false;
  bool _isShared = false;
  String? _userId;
  String? _interactionId;

  AnnouncementData get ann => widget.announcement;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _likes = 0;
    _reactions = 0;
    _comments = 0;
    _shares = 0;
    _checkUserInteraction();
    _loadCounts();
  }

  Future<void> _checkUserInteraction() async {
    if (_userId == null) return;

    final interactionDoc = await FirebaseFirestore.instance
        .collection('announcement_interactions')
        .doc('${ann.id}_$_userId')
        .get();

    if (interactionDoc.exists) {
      final data = interactionDoc.data()!;
      setState(() {
        _isLiked = data['liked'] ?? false;
        _isReacted = data['reacted'] ?? false;
        _isShared = data['shared'] ?? false;
        _interactionId = interactionDoc.id;
      });
    }
  }

  Future<void> _loadCounts() async {
    final doc = await FirebaseFirestore.instance
        .collection('announcement_counts')
        .doc(ann.id)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _likes = data['likes'] ?? 0;
        _reactions = data['reactions'] ?? 0;
        _comments = data['comments'] ?? 0;
        _shares = data['shares'] ?? 0;
      });
    }
  }

  Future<void> _updateCount(String field, int change) async {
    final docRef = FirebaseFirestore.instance
        .collection('announcement_counts')
        .doc(ann.id);

    await docRef.set({
      field: FieldValue.increment(change),
    }, SetOptions(merge: true));
  }

  Future<void> _updateInteraction(Map<String, dynamic> data) async {
    if (_userId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('announcement_interactions')
        .doc('${ann.id}_$_userId');

    await docRef.set(data, SetOptions(merge: true));
  }

  void _handleLike() async {
    if (_userId == null) return;

    setState(() {
      if (_isLiked) {
        _likes--;
        _isLiked = false;
      } else {
        _likes++;
        _isLiked = true;
      }
    });

    await _updateCount('likes', _isLiked ? 1 : -1);
    await _updateInteraction({'liked': _isLiked});
  }

  void _handleReact() async {
    if (_userId == null) return;

    setState(() {
      if (_isReacted) {
        _reactions--;
        _isReacted = false;
      } else {
        _reactions++;
        _isReacted = true;
      }
    });

    await _updateCount('reactions', _isReacted ? 1 : -1);
    await _updateInteraction({'reacted': _isReacted});
  }

  void _handleComment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        announcementId: ann.id,
        onCommentAdded: () async {
          setState(() => _comments++);
          await _updateCount('comments', 1);
        },
      ),
    );
  }

  void _handleShare() async {
    if (_userId == null) return;

    setState(() {
      _shares++;
      _isShared = true;
    });

    await _updateCount('shares', 1);
    await _updateInteraction({'shared': true});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shared successfully!'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  void _handleDismiss() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DismissConfirmSheet(
        onConfirm: () {
          Navigator.pop(context);
          setState(() => _dismissed = true);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) Navigator.pop(context);
          });
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar ──
              SliverAppBar(
                expandedHeight: 200,
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
                    ],
                  ),
                ),
              ),

              // ── Body ── (No "Announcement" title)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tag ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ann.tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

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
                                        color: AppColors.primaryDark,
                                      ),
                                    )
                                  : Icon(
                                      Icons.business_center_outlined,
                                      size: 22,
                                      color: AppColors.primaryDark,
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
                      const Divider(color: Color(0xFFEEEEEE)),
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

                      const SizedBox(height: 20),

                      // ── Register for Event ──
                      if (ann.linkedProposalId.isNotEmpty) ...[
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
                            label: Text('Register for ${ann.linkedEventTitle}',
                                overflow: TextOverflow.ellipsis),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Hashtags ──
                      if (ann.hashtags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: ann.hashtags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF7FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1565C0),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attachments',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B5878),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...ann.attachments.map(
                                (att) => _AttachmentTile(attachment: att),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Action Buttons (Icons only) ──
                      Row(
                        children: [
                          _PostActionButton(
                            icon: _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                            count: _likes,
                            isActive: _isLiked,
                            onTap: _handleLike,
                          ),
                          const SizedBox(width: 10),
                          _PostActionButton(
                            icon: _isReacted ? Icons.favorite : Icons.favorite_border,
                            count: _reactions,
                            isActive: _isReacted,
                            onTap: _handleReact,
                          ),
                          const SizedBox(width: 10),
                          _PostActionButton(
                            icon: Icons.mode_comment_outlined,
                            count: _comments,
                            isActive: false,
                            onTap: _handleComment,
                          ),
                          const SizedBox(width: 10),
                          _PostActionButton(
                            icon: Icons.share_outlined,
                            count: _shares,
                            isActive: _isShared,
                            onTap: _handleShare,
                          ),
                        ],
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Dismiss Button ──
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
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _dismissed ? null : _handleDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _dismissed ? Colors.grey[400] : AppColors.primaryDark,
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
//  POST ACTION BUTTON (Icon only)
// ─────────────────────────────────────────────────────────────
class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _PostActionButton({
    required this.icon,
    required this.count,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: isActive ? AppColors.primaryDark : const Color(0xFF37474F),
          backgroundColor: isActive
              ? AppColors.primaryDark.withOpacity(0.08)
              : const Color(0xFFF7F9FB),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
        return Colors.red.shade600;
      case 'image':
        return Colors.blue.shade600;
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
//  DISMISS CONFIRM SHEET
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
              size: 48, color: Colors.red),
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
                    backgroundColor: AppColors.primaryDark,
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
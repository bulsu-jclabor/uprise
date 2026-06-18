// lib/screens/student/student_broadcast_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom Colors - UNIFORM (MATCHING ORANGE TABS)
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFA726);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF8F9FA);
}

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color pageBg = Color(0xFFF0F2F5);
  static const Color feedBg = Color(0xFFE8ECF0);
  static const Color border = Color(0xFFE8ECF0);
  static const Color borderSoft = Color(0xFFE2E6EA);
  static const Color charcoal = Color(0xFF1A202C);
  static const Color textMid = Color(0xFF374151);
  static const Color darkGray = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF9AA5B4);
}

class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.08),
      blurRadius: 16,
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
// Main Screen - Student Broadcast
// ─────────────────────────────────────────────────────────────────────────────
class StudentBroadcastScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const StudentBroadcastScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<StudentBroadcastScreen> createState() => _StudentBroadcastScreenState();
}

class _StudentBroadcastScreenState extends State<StudentBroadcastScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECF0), // Mas dark na grey background
      appBar: AppBar(
        title: Text(
          widget.orgName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _C.charcoal,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: _BroadcastSearchDelegate(
                  orgId: widget.orgId,
                  orgName: widget.orgName,
                ),
              );
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
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: _C.border)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.campaign_rounded,
              color: Colors.orange,
              size: 24,
            ),
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
                Text(widget.orgName,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.darkGray)),
              ],
            ),
          ),
          // Message count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('broadcasts')
                .where('orgId', isEqualTo: widget.orgId)
                .snapshots(),
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 13, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text('$count',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange)),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('broadcasts')
            .where('orgId', isEqualTo: widget.orgId)
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Colors.orange),
                ));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          var broadcasts = snapshot.data!.docs
              .map((doc) => BroadcastModel.fromFirestore(doc))
              .toList();

          if (_searchQuery.isNotEmpty) {
            broadcasts = broadcasts.where((b) =>
                b.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                b.authorName.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }

          if (broadcasts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: _C.textFaint,
                  ),
                  const SizedBox(height: 12),
                  Text('No results found',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _C.charcoal)),
                  const SizedBox(height: 4),
                  Text('Try a different search term',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 12, color: _C.darkGray)),
                ],
              ),
            );
          }

          // Reverse: latest messages at the bottom
          final reversedBroadcasts = broadcasts.reversed.toList();

          return ListView.builder(
            reverse: true,
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: reversedBroadcasts.length,
            itemBuilder: (context, index) {
              final broadcast = reversedBroadcasts[index];
              final originalIndex = broadcasts.length - 1 - index;
              final showDateSeparator = originalIndex == 0 ||
                  !_isSameDay(broadcasts[originalIndex - 1].timestamp,
                      broadcast.timestamp);

              return Column(
                children: [
                  if (showDateSeparator)
                    _DateSeparator(timestamp: broadcast.timestamp),
                  const SizedBox(height: 8),
                  _BroadcastCard(
                    broadcast: broadcast,
                    orgId: widget.orgId,
                  ),
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
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.1)),
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 40,
              color: Colors.orange.withOpacity(0.4),
            ),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _DS.cardShadow,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: Colors.orange,
              size: 28,
            ),
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
// Broadcast Search Delegate
// ─────────────────────────────────────────────────────────────────────────────
class _BroadcastSearchDelegate extends SearchDelegate {
  final String orgId;
  final String orgName;

  _BroadcastSearchDelegate({
    required this.orgId,
    required this.orgName,
  });

  @override
  String get searchFieldLabel => 'Search broadcasts...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: _C.textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for broadcasts',
              style: GoogleFonts.beVietnamPro(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _C.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Type a keyword to find messages',
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: _C.darkGray,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('broadcasts')
          .where('orgId', isEqualTo: orgId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var broadcasts = snapshot.data!.docs
            .map((doc) => BroadcastModel.fromFirestore(doc))
            .where((b) =>
                b.content.toLowerCase().contains(query.toLowerCase()) ||
                b.authorName.toLowerCase().contains(query.toLowerCase()))
            .toList();

        if (broadcasts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: _C.textFaint,
                ),
                const SizedBox(height: 12),
                Text(
                  'No results found',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _C.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try a different keyword',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: _C.darkGray,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: broadcasts.length,
          itemBuilder: (context, index) {
            final broadcast = broadcasts[index];
            return _BroadcastCard(
              broadcast: broadcast,
              orgId: orgId,
            );
          },
        );
      },
    );
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE8ECF0), thickness: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(_label(),
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _C.darkGray)),
          ),
          const Expanded(child: Divider(color: Color(0xFFE8ECF0), thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Broadcast Card with Replies - IMPROVED WITH BETTER VISIBILITY
// ─────────────────────────────────────────────────────────────────────────────
class _BroadcastCard extends StatefulWidget {
  final BroadcastModel broadcast;
  final String orgId;

  const _BroadcastCard({
    required this.broadcast,
    required this.orgId,
  });

  @override
  State<_BroadcastCard> createState() => _BroadcastCardState();
}

class _BroadcastCardState extends State<_BroadcastCard> {
  late int _likes;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.broadcast.likes;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('broadcast_likes')
        .doc('${widget.broadcast.id}_${user.uid}')
        .get();

    if (doc.exists) {
      setState(() => _isLiked = true);
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to like'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (_isLiked) {
        _likes--;
        _isLiked = false;
      } else {
        _likes++;
        _isLiked = true;
      }
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('broadcast_likes')
          .doc('${widget.broadcast.id}_${user.uid}');

      if (_isLiked) {
        await docRef.set({
          'broadcastId': widget.broadcast.id,
          'userId': user.uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('broadcasts')
            .doc(widget.broadcast.id)
            .update({
          'likes': FieldValue.increment(1),
        });
      } else {
        await docRef.delete();
        await FirebaseFirestore.instance
            .collection('broadcasts')
            .doc(widget.broadcast.id)
            .update({
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      setState(() {
        if (_isLiked) {
          _likes--;
          _isLiked = false;
        } else {
          _likes++;
          _isLiked = true;
        }
      });
    }
  }

  Future<void> _addReply(String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('broadcasts')
          .doc(widget.broadcast.id)
          .collection('replies')
          .add({
        'content': content,
        'authorId': user.uid,
        'authorName': user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('broadcasts')
          .doc(widget.broadcast.id)
          .update({
        'replyCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to add reply: $e');
    }
  }

  void _showReplyDialog() {
    final replyController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> submitReply() async {
            if (replyController.text.trim().isEmpty) return;
            setSheetState(() => isSubmitting = true);
            try {
              await _addReply(replyController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reply added!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } catch (e) {
              setSheetState(() => isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add reply: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          return Container(
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
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
                  'Add Reply',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your reply here...',
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
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
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: _C.border),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _C.darkGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : submitReply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Post Reply',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _timeLabel(Timestamp ts) =>
      DateFormat('h:mm a').format(ts.toDate());

  @override
  Widget build(BuildContext context) {
    final b = widget.broadcast;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author and time
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: Text(
                  b.authorName.isNotEmpty ? b.authorName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.authorName,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.charcoal)),
                    Text(_timeLabel(b.timestamp),
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11, color: _C.textFaint)),
                  ],
                ),
              ),
              if (b.pinned) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text('Pinned',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Message Bubble - IMPROVED WITH BETTER VISIBILITY
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.orange,
                  Color(0xFFFFA726),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.imageUrl != null && b.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image(
                      image: _imageProviderFromUrl(b.imageUrl!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.content.isNotEmpty)
                        Text(b.content,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 15,
                                color: Colors.white,
                                height: 1.6,
                                fontWeight: FontWeight.w400)),
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
          const SizedBox(height: 12),

          // Like and Reply buttons - IMPROVED
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isLiked
                        ? Colors.orange.withOpacity(0.1)
                        : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isLiked
                          ? Colors.orange
                          : const Color(0xFFE8ECF0),
                      width: _isLiked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: _isLiked ? Colors.orange : _C.darkGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_likes',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isLiked ? Colors.orange : _C.darkGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showReplyDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8ECF0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mode_comment_outlined,
                        size: 18,
                        color: _C.darkGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${b.replyCount}',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.darkGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── REPLIES SECTION (IMPROVED) ──
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('broadcasts')
                .doc(b.id)
                .collection('replies')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, replySnapshot) {
              if (replySnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }

              if (!replySnapshot.hasData || replySnapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              final replies = replySnapshot.data!.docs;
              final currentUser = FirebaseAuth.instance.currentUser;

              return Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: const Color(0xFFF0F2F5), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replies',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...replies.map((replyDoc) {
                      final replyData = replyDoc.data() as Map<String, dynamic>;
                      final replyAuthor = replyData['authorName'] ?? 'Anonymous';
                      final replyContent = replyData['content'] ?? '';
                      final replyTime = replyData['timestamp'] as Timestamp?;
                      final isOwnReply = currentUser?.uid == replyData['authorId'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isOwnReply
                                  ? Colors.orange.withOpacity(0.1)
                                  : const Color(0xFFF5F7FA),
                              child: Text(
                                replyAuthor.isNotEmpty ? replyAuthor[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isOwnReply ? Colors.orange : _C.darkGray,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isOwnReply
                                      ? Colors.orange.withOpacity(0.05)
                                      : const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOwnReply
                                        ? Colors.orange.withOpacity(0.2)
                                        : const Color(0xFFE8ECF0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          replyAuthor,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isOwnReply ? Colors.orange : _C.charcoal,
                                          ),
                                        ),
                                        if (isOwnReply) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'You',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        if (replyTime != null)
                                          Text(
                                            DateFormat('h:mm a').format(replyTime.toDate()),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: _C.textFaint,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      replyContent,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _C.charcoal,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachment Link
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentLink extends StatelessWidget {
  final Attachment attachment;

  const _AttachmentLink({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
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
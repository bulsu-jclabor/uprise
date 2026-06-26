// lib/screens/web/org/org_broadcast.dart
// Complete with all features: edit, pin, replies, file/image upload, right/left alignment

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../../services/activity_logger.dart' as activity_log;
import '../../../utils/platform_file_utils.dart' as platform_file_utils;

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const Color primaryDark = Color(0xFFBE4700);
  static const Color accent = Color(0xFFDA6937);
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
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);
}

class _DS {
  static const double radiusSm = 8;
  static const double radiusLg = 16;
  static final List<BoxShadow> cardShadow = [
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static final List<BoxShadow> bubbleShadow = [
    BoxShadow(color: Color.fromRGBO(180, 83, 9, 0.14), blurRadius: 8, offset: Offset(0, 3)),
  ];
}

ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel theme presets ("Change theme")
// ─────────────────────────────────────────────────────────────────────────────
class _ThemePreset {
  final String id;
  final String label;
  final Color primary;
  final Color accent;
  const _ThemePreset(this.id, this.label, this.primary, this.accent);
}

const List<_ThemePreset> _kThemePresets = [
  _ThemePreset('orange', 'Orange', Color(0xFFEA580C), Color(0xFFF97316)),
  _ThemePreset('blue', 'Blue', Color(0xFF2563EB), Color(0xFF3B82F6)),
  _ThemePreset('green', 'Green', Color(0xFF059669), Color(0xFF10B981)),
  _ThemePreset('purple', 'Purple', Color(0xFF7C3AED), Color(0xFFA78BFA)),
  _ThemePreset('pink', 'Pink', Color(0xFFDB2777), Color(0xFFF472B6)),
  _ThemePreset('teal', 'Teal', Color(0xFF0D9488), Color(0xFF2DD4BF)),
];

_ThemePreset _themePresetById(String? id) =>
    _kThemePresets.firstWhere((p) => p.id == id, orElse: () => _kThemePresets.first);

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgBroadcastScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  const OrgBroadcastScreen({super.key, required this.orgId, this.orgName = 'Organization'});

  @override
  State<OrgBroadcastScreen> createState() => _OrgBroadcastScreenState();
}

class _OrgBroadcastScreenState extends State<OrgBroadcastScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  List<Attachment> _pendingAttachments = [];
  String? _pendingImageUrl;
  bool _isSending = false;
  bool _isUploadingFile = false;
  bool _isUploadingImage = false;
  // ValueNotifier (not a plain bool + setState) so this keeps updating even
  // when read from inside showModalBottomSheet — that content lives in a
  // separate route/overlay and never rebuilds from this State's setState.
  final ValueNotifier<bool> _uploadingChannelPhoto = ValueNotifier(false);
  int _memberCount = 0;
  int _lastFeedLength = -1;
  String _searchQuery = '';

  String? _channelName;
  String? _channelPhotoUrl;
  _ThemePreset _theme = _kThemePresets.first;
  StreamSubscription<DocumentSnapshot>? _orgSettingsSub;

  // Created once, not a getter — widget.orgId never changes for this
  // screen's lifetime, and this is read both once in initState and again
  // in a StreamBuilder, so a getter was re-subscribing on every rebuild.
  late final Stream<DocumentSnapshot> _orgDocStream =
      FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).snapshots();

  // Fetched once and reused on every send instead of re-reading the user
  // doc on each message — that round trip was adding a visible delay before
  // the message could even be created.
  String? _authorName;

  @override
  void initState() {
    super.initState();
    _fetchMemberCount();
    _fetchAuthorName();
    _orgSettingsSub = _orgDocStream.listen((doc) {
      if (!mounted) return;
      final d = doc.data() as Map<String, dynamic>?;
      setState(() {
        _channelName = (d?['broadcastChannelName'] as String?)?.trim();
        _channelPhotoUrl = d?['broadcastChannelPhotoUrl'] as String?;
        _theme = _themePresetById(d?['broadcastThemeId'] as String?);
      });
    });
  }

  Future<void> _fetchAuthorName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _orgSettingsSub?.cancel();
    _uploadingChannelPhoto.dispose();
    super.dispose();
  }

  Future<void> _fetchMemberCount() async {
    try {
      // Mirrors the "Members" definition used on the org dashboard.
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('orgId', isEqualTo: widget.orgId)
          .where('role', isEqualTo: 'org')
          .get();
      if (mounted) setState(() => _memberCount = snap.size);
    } catch (_) {}
  }

  // Created once, not a getter — used in four separate StreamBuilders, so
  // a getter here was tearing down and re-subscribing all four on every
  // rebuild (e.g. every keystroke while typing a message or searching).
  late final Stream<QuerySnapshot> _broadcastsStream = FirebaseFirestore.instance
      .collection('broadcasts')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('timestamp', descending: true)
      .snapshots();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── File upload ──────────────────────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    setState(() => _isUploadingFile = true);

    try {
      int uploaded = 0;
      int skipped = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          // Some platforms don't populate `bytes` unless withData is set
          // (now passed above), or the file came from a stream-only source.
          debugPrint('Broadcast file attach: no bytes for "${file.name}" (path: ${file.path})');
          skipped++;
          continue;
        }
        if (bytes.length > 10 * 1024 * 1024) {
          _snack('${file.name} exceeds 10 MB', isError: true);
          skipped++;
          continue;
        }
        try {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final ref = FirebaseStorage.instance.ref().child('broadcasts/${widget.orgId}/files/$fileName');
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          setState(() => _pendingAttachments.add(Attachment(name: file.name, url: url)));
          uploaded++;
        } on FirebaseException catch (e) {
          debugPrint('Broadcast file upload failed for "${file.name}": ${e.code} ${e.message}');
          _snack('Could not upload "${file.name}": ${e.message ?? e.code}', isError: true);
          skipped++;
        }
      }
      if (uploaded > 0) _snack('$uploaded file(s) attached');
      if (uploaded == 0 && skipped == 0) _snack('No files were selected', isError: true);
    } catch (e) {
      debugPrint('Broadcast file picker error: $e');
      _snack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  // ── Image upload ─────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select Image Source', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery', style: GoogleFonts.beVietnamPro()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera', style: GoogleFonts.beVietnamPro()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _isUploadingImage = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1080, imageQuality: 80);
      if (pickedFile == null) {
        setState(() => _isUploadingImage = false);
        return;
      }
      final bytes = await pickedFile.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _snack('Image too large — max 5 MB', isError: true);
        setState(() => _isUploadingImage = false);
        return;
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final ref = FirebaseStorage.instance.ref().child('broadcasts/${widget.orgId}/images/$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      setState(() => _pendingImageUrl = url);
      _snack('Image ready to send');
    } on FirebaseException catch (e) {
      debugPrint('Broadcast image upload failed: ${e.code} ${e.message}');
      _snack('Failed to upload image: ${e.message ?? e.code}', isError: true);
    } catch (e) {
      debugPrint('Broadcast image upload error: $e');
      _snack('Failed to upload image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ── Send message ─────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
  final text = _messageCtrl.text.trim();
  if (text.isEmpty && _pendingAttachments.isEmpty && _pendingImageUrl == null) return;
  setState(() => _isSending = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'No user logged in';
    final authorName = _authorName ?? user.email ?? 'Unknown';

    final data = <String, dynamic>{
      'orgId': widget.orgId,
      'content': text,
      'authorId': user.uid,
      'authorName': authorName,
      'attachments': _pendingAttachments.map((a) => {'name': a.name, 'url': a.url}).toList(),
      'likes': 0,
      'replyCount': 0,
      'pinned': false,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (_pendingImageUrl != null && _pendingImageUrl!.isNotEmpty) {
      data['imageUrl'] = _pendingImageUrl;
    }

    final docRef = await FirebaseFirestore.instance.collection('broadcasts').add(data);

    // The message is already live (the broadcasts stream picks it up as
    // soon as Firestore confirms the write above) — clear the composer and
    // unlock sending right away instead of waiting on the notification
    // fan-out and audit log below, which can take a while with many
    // students and have nothing to do with the message being visible.
    _messageCtrl.clear();
    setState(() {
      _pendingAttachments = [];
      _pendingImageUrl = null;
      _isSending = false;
    });
    _inputFocus.requestFocus();
    Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);

    unawaited(_createNotificationsForBroadcast(docRef.id, widget.orgId, text));
    unawaited(activity_log.ActivityLogger.log(
      action: 'send_broadcast',
      module: 'broadcast',
      details: {'orgId': widget.orgId},
    ));
  } catch (e) {
    _snack('Failed to send: $e', isError: true);
    if (mounted) setState(() => _isSending = false);
  }
}

  Future<void> _createNotificationsForBroadcast(String broadcastId, String orgId, String content) async {
  try {
    // Fetch all students (assuming collection 'students' with field 'uid')
    final students = await FirebaseFirestore.instance.collection('students').get();
    final batch = FirebaseFirestore.instance.batch();

    for (final student in students.docs) {
      final uid = student.data()['uid'] as String?;
      if (uid == null || uid.isEmpty) continue;

      final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': uid,
        'title': 'New Announcement',
        'body': content,
        'type': 'broadcast',
        'broadcastId': broadcastId,
        'orgId': orgId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
  } catch (e) {
    // Log the error but don't fail the broadcast send
    debugPrint('Failed to create notifications for broadcast: $e');
  }
}

  // ── Delete message ───────────────────────────────────────────────────────
  Future<void> _deleteMessage(BroadcastModel broadcast) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: _C.errorBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded, color: _C.error, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text('Delete Message', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: _C.charcoal)),
                ],
              ),
              const SizedBox(height: 14),
              Text('This message will be permanently removed from the broadcast channel.',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: _C.darkGray, height: 1.5)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.borderSoft),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textMid)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Delete', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    try {
      for (final att in broadcast.attachments) {
        try { await FirebaseStorage.instance.refFromURL(att.url).delete(); } catch (_) {}
      }
      if (broadcast.imageUrl != null && broadcast.imageUrl!.isNotEmpty && !broadcast.imageUrl!.startsWith('data:')) {
        try { await FirebaseStorage.instance.refFromURL(broadcast.imageUrl!).delete(); } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('broadcasts').doc(broadcast.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_broadcast',
        module: 'broadcast',
        details: {'orgId': widget.orgId, 'broadcastId': broadcast.id},
      );
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: GoogleFonts.beVietnamPro(fontSize: 13, color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? _C.error : _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatCount(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  void _openInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildInfoPanelContent(scrollController: scrollCtrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isWide = width >= 1100;
    final horizontalPadding = isMobile ? 16.0 : 28.0;

    return Scaffold(
      backgroundColor: _C.pageBg,
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildChannelHeader(isMobile, horizontalPadding),
                Expanded(child: _buildFeedShell(isMobile, horizontalPadding)),
                if (_pendingAttachments.isNotEmpty || _pendingImageUrl != null)
                  _buildAttachmentPreviewBar(horizontalPadding),
                _buildComposeBar(isMobile, horizontalPadding),
              ],
            ),
          ),
          if (isWide)
            Container(
              width: 300,
              decoration: const BoxDecoration(
                color: _C.white,
                border: Border(left: BorderSide(color: _C.border)),
              ),
              child: _buildInfoPanelContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelHeader(bool isMobile, double horizontalPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 18),
      decoration: BoxDecoration(color: _C.white, border: const Border(bottom: BorderSide(color: _C.border)), boxShadow: _DS.cardShadow),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _channelAvatar(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_channelName?.isNotEmpty == true ? _channelName! : 'Broadcast Channel', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w800, color: _theme.primary)),
                          const SizedBox(height: 2),
                          Text(widget.orgName, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openInfoSheet,
                      icon: const Icon(Icons.info_outline_rounded, color: _C.darkGray),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('broadcasts').where('orgId', isEqualTo: widget.orgId).snapshots(),
                  builder: (_, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Wrap(
                      spacing: 10, runSpacing: 10,
                      children: [
                        _HeaderPill(icon: Icons.forum_outlined, label: '$count messages', color: _C.info),
                        if (_memberCount > 0) _HeaderPill(icon: Icons.people_outline_rounded, label: '${_formatCount(_memberCount)} members', color: _C.success),
                      ],
                    );
                  },
                ),
              ],
            )
          : Row(
              children: [
                _channelAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_channelName?.isNotEmpty == true ? _channelName! : 'Broadcast Channel', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w800, color: _theme.primary)),
                      const SizedBox(height: 2),
                      Text(widget.orgName, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray)),
                    ],
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('broadcasts').where('orgId', isEqualTo: widget.orgId).snapshots(),
                  builder: (_, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Row(
                      children: [
                        _HeaderPill(icon: Icons.forum_outlined, label: '$count messages', color: _C.info),
                        const SizedBox(width: 10),
                        if (_memberCount > 0) _HeaderPill(icon: Icons.people_outline_rounded, label: '${_formatCount(_memberCount)} members', color: _C.success),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _openInfoSheet,
                  icon: const Icon(Icons.info_outline_rounded, color: _C.darkGray),
                  tooltip: 'Conversation info',
                ),
              ],
            ),
    );
  }

  Widget _channelAvatar({String? photoUrl, Color? primaryColor}) {
    final url = photoUrl ?? _channelPhotoUrl;
    final color = primaryColor ?? _theme.primary;
    final hasPhoto = url != null && url.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 46, height: 46,
            color: color.withValues(alpha: 0.10),
            child: hasPhoto
                ? Image(image: _imageProviderFromUrl(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.campaign_rounded, color: color, size: 24))
                : Icon(Icons.campaign_rounded, color: color, size: 24),
          ),
        ),
        Positioned(
          bottom: -2, right: -2,
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: _C.success,
              shape: BoxShape.circle,
              border: Border.all(color: _C.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ── Right info panel — channel summary, search, shared photos ────────────
  Widget _buildInfoPanelContent({ScrollController? scrollController}) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Self-contained StreamBuilder so this stays live even when this
        // panel is shown inside a showModalBottomSheet (a separate route
        // that doesn't rebuild from this screen's setState).
        StreamBuilder<DocumentSnapshot>(
          stream: _orgDocStream,
          builder: (context, snap) {
            final d = snap.data?.data() as Map<String, dynamic>?;
            final name = (d?['broadcastChannelName'] as String?)?.trim();
            final photoUrl = d?['broadcastChannelPhotoUrl'] as String?;
            final theme = _themePresetById(d?['broadcastThemeId'] as String?);
            return Center(
              child: Column(
                children: [
                  _channelAvatar(photoUrl: photoUrl, primaryColor: theme.primary),
                  const SizedBox(height: 10),
                  Text(name?.isNotEmpty == true ? name! : 'Broadcast Channel',
                      style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700, color: _C.charcoal), textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(_memberCount > 0 ? '${_formatCount(_memberCount)} members' : widget.orgName, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const Divider(color: _C.borderSoft),
        const SizedBox(height: 14),
        Text('Search in Conversation', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: _C.darkGray)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.borderSoft)),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.beVietnamPro(fontSize: 13),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search messages…',
              hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _C.textFaint),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: _C.textFaint),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _searchQuery = '';
                      }),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: _C.borderSoft),
        const SizedBox(height: 10),
        _InfoSectionLabel('Chat Info'),
        _InfoActionRow(icon: Icons.push_pin_outlined, label: 'View pinned messages', onTap: _viewPinnedMessages),

        const SizedBox(height: 18),
        const Divider(color: _C.borderSoft),
        const SizedBox(height: 10),
        _InfoSectionLabel('Customize Channel'),
        _InfoActionRow(icon: Icons.edit_outlined, label: 'Change channel name', onTap: _changeChannelName),
        ValueListenableBuilder<bool>(
          valueListenable: _uploadingChannelPhoto,
          builder: (_, isUploading, __) => _InfoActionRow(
            icon: Icons.image_outlined,
            label: 'Change channel photo',
            isLoading: isUploading,
            onTap: isUploading ? null : _changeChannelPhoto,
          ),
        ),
        _InfoActionRow(icon: Icons.palette_outlined, label: 'Change theme', onTap: _changeTheme),

        const SizedBox(height: 18),
        const Divider(color: _C.borderSoft),
        const SizedBox(height: 10),
        _InfoSectionLabel('Media, Files & Links'),
        const SizedBox(height: 8),
        Text('Media', style: GoogleFonts.beVietnamPro(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.textMid)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _broadcastsStream,
          builder: (context, snap) {
            final urls = (snap.data?.docs ?? [])
                .map((d) => (d.data() as Map<String, dynamic>)['imageUrl'] as String?)
                .where((u) => u != null && u.isNotEmpty)
                .cast<String>()
                .toList();
            if (urls.isEmpty) {
              return Text('No photos shared yet.', style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.textFaint));
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: urls.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _viewSharedPhoto(urls[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: _imageProviderFromUrl(urls[i]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _C.surface, child: const Icon(Icons.broken_image, color: _C.textFaint, size: 16)),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Files', style: GoogleFonts.beVietnamPro(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.textMid)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _broadcastsStream,
          builder: (context, snap) {
            final files = <Attachment>[];
            for (final doc in snap.data?.docs ?? []) {
              final list = (doc.data() as Map<String, dynamic>)['attachments'] as List? ?? [];
              for (final a in list) {
                files.add(Attachment(name: a['name'] ?? '', url: a['url'] ?? ''));
              }
            }
            if (files.isEmpty) {
              return Text('No files shared yet.', style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.textFaint));
            }
            return Column(children: files.map((f) => _InfoFileRow(attachment: f)).toList());
          },
        ),
        const SizedBox(height: 16),
        Text('Links', style: GoogleFonts.beVietnamPro(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.textMid)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _broadcastsStream,
          builder: (context, snap) {
            final linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
            final links = <String>{};
            for (final doc in snap.data?.docs ?? []) {
              final content = (doc.data() as Map<String, dynamic>)['content'] as String? ?? '';
              for (final m in linkRegex.allMatches(content)) {
                links.add(m.group(0)!);
              }
            }
            if (links.isEmpty) {
              return Text('No links shared yet.', style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.textFaint));
            }
            return Column(children: links.map((l) => _InfoLinkRow(url: l)).toList());
          },
        ),
      ],
    );
  }


  void _viewPinnedMessages() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.push_pin_rounded, size: 18, color: _C.primaryDark),
                  const SizedBox(width: 8),
                  Text('Pinned Messages', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: _C.charcoal)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 8),
                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('broadcasts')
                        .where('orgId', isEqualTo: widget.orgId)
                        .where('pinned', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('No pinned messages yet.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint)),
                        );
                      }
                      final items = docs.map((d) => BroadcastModel.fromFirestore(d)).toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(color: _C.borderSoft),
                        itemBuilder: (_, i) {
                          final m = items[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.authorName, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: _C.charcoal)),
                                const SizedBox(height: 3),
                                Text(m.content, style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textMid, height: 1.5)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeChannelName() async {
    final ctrl = TextEditingController(text: _channelName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Channel Name', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: _C.charcoal)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Broadcast Channel',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
                  filled: true,
                  fillColor: _C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.borderSoft)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: _C.borderSoft)),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textMid)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                    style: ElevatedButton.styleFrom(backgroundColor: _theme.primary, foregroundColor: Colors.white, elevation: 0),
                    child: Text('Save', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).set(
        {'broadcastChannelName': result},
        SetOptions(merge: true),
      );
      await activity_log.ActivityLogger.log(action: 'rename_broadcast_channel', module: 'broadcast', details: {'orgId': widget.orgId, 'name': result});
      if (mounted) _snack('Channel name updated');
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    }
  }

  Future<void> _changeChannelPhoto() async {
    try {
      final picker = ImagePicker();
      // image_picker ignores maxWidth/maxHeight/imageQuality on web, so a
      // phone-camera photo can come back several MB wide — resize it
      // ourselves below instead of uploading it as-is.
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      _uploadingChannelPhoto.value = true;
      final rawBytes = await picked.readAsBytes();
      if (rawBytes.length > 15 * 1024 * 1024) {
        _snack('Image too large — please pick a smaller photo', isError: true);
        _uploadingChannelPhoto.value = false;
        return;
      }

      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        _snack('Could not read that image', isError: true);
        _uploadingChannelPhoto.value = false;
        return;
      }
      final resized = decoded.width > 320 || decoded.height > 320
          ? img.copyResize(decoded, width: decoded.width >= decoded.height ? 320 : null, height: decoded.height > decoded.width ? 320 : null)
          : decoded;
      final jpgBytes = img.encodeJpg(resized, quality: 78);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';

      // Stored directly on the org doc (same pattern as announcement/banner
      // images elsewhere in this app) — no Firebase Storage involved, so
      // this can't hang on Storage CORS/permission issues.
      await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).set(
        {'broadcastChannelPhotoUrl': dataUrl},
        SetOptions(merge: true),
      );
      await activity_log.ActivityLogger.log(action: 'change_broadcast_photo', module: 'broadcast', details: {'orgId': widget.orgId});
      if (mounted) _snack('Channel photo updated');
    } catch (e) {
      if (mounted) _snack('Upload failed: $e', isError: true);
    } finally {
      _uploadingChannelPhoto.value = false;
    }
  }

  Future<void> _changeTheme() async {
    final selected = await showDialog<_ThemePreset>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Theme', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: _C.charcoal)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14, runSpacing: 14,
                children: _kThemePresets.map((p) {
                  final isSelected = p.id == _theme.id;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, p),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [p.primary, p.accent]),
                            border: isSelected ? Border.all(color: _C.charcoal, width: 2.5) : null,
                          ),
                          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(p.label, style: GoogleFonts.beVietnamPro(fontSize: 10, color: _C.darkGray)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).set(
        {'broadcastThemeId': selected.id},
        SetOptions(merge: true),
      );
      await activity_log.ActivityLogger.log(action: 'change_broadcast_theme', module: 'broadcast', details: {'orgId': widget.orgId, 'theme': selected.id});
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    }
  }

  void _viewSharedPhoto(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(image: _imageProviderFromUrl(url), fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedShell(bool isMobile, double horizontalPadding) {
    return Container(
      margin: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      decoration: BoxDecoration(color: _C.feedBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border), boxShadow: _DS.cardShadow),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<QuerySnapshot>(
        stream: _broadcastsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildErrorState(snap.error.toString());
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _C.primaryDark));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          var items = snap.data!.docs
              .map((d) => BroadcastModel.fromFirestore(d))
              .where((m) => m.timestamp != null)
              .toList()
              .reversed
              .toList();

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            items = items.where((m) =>
                m.content.toLowerCase().contains(q) ||
                m.authorName.toLowerCase().contains(q)).toList();
          }
          if (items.isEmpty) {
            return _buildEmptySearchState();
          }

          // Only auto-scroll when the message list actually changes — not on
          // every rebuild (e.g. every keystroke in the compose field), which
          // was forcing a visible scroll-jump/"refresh" on each letter typed.
          if (items.length != _lastFeedLength) {
            _lastFeedLength = items.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollCtrl.hasClients) {
                _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              }
            });
          }

          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final msg = items[i];
              final showSep = i == 0 || !_sameDay(items[i - 1].timestamp.toDate(), msg.timestamp.toDate());
              return Column(
                children: [
                  if (showSep) _DateSeparator(timestamp: msg.timestamp),
                  _BroadcastBubble(
                    broadcast: msg,
                    onDelete: () => _deleteMessage(msg),
                    orgId: widget.orgId,
                    primaryColor: _theme.primary,
                    accentColor: _theme.accent,
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
            width: 80, height: 80,
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(20), boxShadow: _DS.cardShadow),
            child: const Icon(Icons.campaign_outlined, size: 40, color: _C.textFaint),
          ),
          const SizedBox(height: 16),
          Text('No messages yet', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: _C.charcoal)),
          const SizedBox(height: 6),
          Text('Send a broadcast to all members below.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.darkGray)),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: _C.textFaint),
          const SizedBox(height: 12),
          Text('No matching messages', style: GoogleFonts.beVietnamPro(fontSize: 14, color: _C.darkGray)),
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
            width: 56, height: 56,
            decoration: BoxDecoration(color: _C.errorBg, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.error_outline_rounded, color: _C.error, size: 28),
          ),
          const SizedBox(height: 14),
          Text('Failed to load messages', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: _C.charcoal)),
          const SizedBox(height: 6),
          Text(error, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text('Retry', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreviewBar(double horizontalPadding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 0),
      color: _C.white,
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          if (_pendingImageUrl != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: _imageProviderFromUrl(_pendingImageUrl!),
                    width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: _C.errorBg, child: const Icon(Icons.broken_image, color: _C.error)),
                  ),
                ),
                Positioned(
                  top: 3, right: 3,
                  child: InkWell(
                    onTap: () => setState(() => _pendingImageUrl = null),
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ..._pendingAttachments.asMap().entries.map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _C.infoBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.info.withValues(alpha: 0.25))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 14, color: _C.info),
                  const SizedBox(width: 6),
                  Text(e.value.name, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.info, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _pendingAttachments.removeAt(e.key)),
                    child: const Icon(Icons.close_rounded, size: 13, color: _C.info),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.image_outlined, color: _theme.primary),
              title: Text('Photo', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file_rounded, color: _theme.primary),
              title: Text('File', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickFiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEmojiPicker() {
    const emojis = [
      '😀','😂','😍','🥳','👍','🙏','🔥','🎉','❤️','😢',
      '😎','🤔','👏','💯','😅','🙌','✨','😉','😴','🤝',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12, runSpacing: 12,
            children: emojis.map((e) => InkWell(
              onTap: () {
                _messageCtrl.text += e;
                _messageCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _messageCtrl.text.length));
                setState(() {});
                Navigator.pop(ctx);
              },
              child: Text(e, style: const TextStyle(fontSize: 24)),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildComposeBar(bool isMobile, double horizontalPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 18),
      decoration: BoxDecoration(color: _C.white, border: const Border(top: BorderSide(color: _C.border)), boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkWell(
                onTap: (_isUploadingFile || _isUploadingImage) ? null : _openAttachMenu,
                borderRadius: BorderRadius.circular(23),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_theme.primary, _theme.accent]),
                    shape: BoxShape.circle,
                  ),
                  child: (_isUploadingFile || _isUploadingImage)
                      ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _C.borderSoft)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageCtrl,
                          focusNode: _inputFocus,
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.charcoal),
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Aa',
                            hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openEmojiPicker,
                        icon: const Icon(Icons.emoji_emotions_outlined, size: 20, color: _C.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageCtrl,
                builder: (ctx, value, __) {
                  final hasContent = value.text.trim().isNotEmpty || _pendingAttachments.isNotEmpty || _pendingImageUrl != null;
                  final canSend = hasContent && !_isSending;
                  return InkWell(
                    onTap: canSend ? _sendMessage : null,
                    borderRadius: BorderRadius.circular(23),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: canSend ? LinearGradient(colors: [_theme.primary, _theme.accent]) : LinearGradient(colors: [_theme.primary.withValues(alpha: 0.4), _theme.accent.withValues(alpha: 0.4)]),
                        shape: BoxShape.circle,
                        boxShadow: canSend ? [BoxShadow(color: _theme.accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))] : [],
                      ),
                      child: _isSending
                          ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : Icon(Icons.send_rounded, color: canSend ? Colors.white : Colors.white.withValues(alpha: 0.5), size: 20),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people_outline_rounded, size: 13, color: _C.textFaint),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _memberCount > 0 ? 'Sending to ${_formatCount(_memberCount)} members' : 'Sending to all members',
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: _C.textFaint),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Only organization officers can broadcast. Members can react and reply under each message.',
              style: GoogleFonts.beVietnamPro(fontSize: 10, color: _C.textFaint)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Pill
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Right info panel — small reusable rows
// ─────────────────────────────────────────────────────────────────────────────
class _InfoSectionLabel extends StatelessWidget {
  final String text;
  const _InfoSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: _C.darkGray, letterSpacing: 0.4)),
    );
  }
}

class _InfoActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  const _InfoActionRow({required this.icon, required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: _C.darkGray))
            else
              Icon(icon, size: 17, color: _C.textMid),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: _C.charcoal))),
          ],
        ),
      ),
    );
  }
}

class _InfoFileRow extends StatelessWidget {
  final Attachment attachment;
  const _InfoFileRow({required this.attachment});

  Future<void> _open(BuildContext context) async {
    try {
      await platform_file_utils.openUrl(attachment.url);
    } catch (e) {
      Clipboard.setData(ClipboardData(text: attachment.url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file — link copied instead: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 16, color: _C.info),
            const SizedBox(width: 10),
            Expanded(child: Text(attachment.name, style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: _C.textMid), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.open_in_new_rounded, size: 13, color: _C.textFaint),
          ],
        ),
      ),
    );
  }
}

class _InfoLinkRow extends StatelessWidget {
  final String url;
  const _InfoLinkRow({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard'), duration: Duration(seconds: 2)));
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, size: 16, color: _C.info),
            const SizedBox(width: 10),
            Expanded(child: Text(url, style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: _C.info, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compose Toolbar Button
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Date Separator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final Timestamp timestamp;
  const _DateSeparator({required this.timestamp});

  String _label() {
    final now = DateTime.now();
    final date = timestamp.toDate();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Yesterday';
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
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
            child: Text(_label(), style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: _C.darkGray)),
          ),
          const Expanded(child: Divider(color: _C.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Broadcast Bubble - with right/left alignment, edit, pin, delete, replies
// ─────────────────────────────────────────────────────────────────────────────
class _BroadcastBubble extends StatefulWidget {
  final BroadcastModel broadcast;
  final VoidCallback onDelete;
  final String orgId;
  final Color primaryColor;
  final Color accentColor;
  const _BroadcastBubble({
    required this.broadcast,
    required this.onDelete,
    required this.orgId,
    this.primaryColor = _C.primaryDark,
    this.accentColor = _C.accent,
  });

  @override
  State<_BroadcastBubble> createState() => _BroadcastBubbleState();
}

class _BroadcastBubbleState extends State<_BroadcastBubble> {
  bool _hovered = false;
  bool _isPinning = false;
  bool _isEditing = false;
  bool _repliesExpanded = false;

  String _timeLabel(Timestamp ts) => DateFormat('h:mm a').format(ts.toDate());

  Widget _buildReplyMeta() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('broadcasts')
          .doc(widget.broadcast.id)
          .collection('replies')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final replyCount = snap.data?.docs.length ?? widget.broadcast.replyCount;
        return Row(
          children: [
            _MiniActionChip(icon: Icons.favorite_border, label: '${widget.broadcast.likes}'),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _repliesExpanded = !_repliesExpanded),
              child: _MiniActionChip(icon: Icons.mode_comment_outlined, label: '$replyCount'),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _repliesExpanded = !_repliesExpanded),
              child: Text(_repliesExpanded ? 'Hide replies' : 'View replies',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textFaint)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    if (!_repliesExpanded) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('broadcasts')
          .doc(widget.broadcast.id)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('No replies yet. Students can reply under this message.',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.textFaint)),
          );
        }
        final replies = snap.data!.docs.map((d) => BroadcastReply.fromFirestore(d)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            ...replies.map((reply) => _ReplyRow(reply: reply)),
          ],
        );
      },
    );
  }

  Future<void> _togglePinMessage() async {
    if (_isPinning) return;
    setState(() => _isPinning = true);
    try {
      await FirebaseFirestore.instance
          .collection('broadcasts')
          .doc(widget.broadcast.id)
          .update({'pinned': !(widget.broadcast.pinned)});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pin message: $e'), backgroundColor: _C.error),
      );
    } finally {
      if (mounted) setState(() => _isPinning = false);
    }
  }

  Future<void> _editMessage() async {
    final controller = TextEditingController(text: widget.broadcast.content);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Message', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: _C.charcoal)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Update broadcast content',
                  filled: true,
                  fillColor: _C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.borderSoft)),
                ),
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.charcoal),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.borderSoft),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textMid)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () async {
                            if (!mounted) return;
                            setState(() => _isEditing = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('broadcasts')
                                  .doc(widget.broadcast.id)
                                  .update({
                                    'content': controller.text.trim(),
                                    'editedAt': FieldValue.serverTimestamp(),
                                  });
                              if (!mounted) return;
                              Navigator.pop(context, true);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e'), backgroundColor: _C.error),
                              );
                            } finally {
                              if (mounted) setState(() => _isEditing = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Save', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message updated'), backgroundColor: _C.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.broadcast;
    // The broadcast channel speaks with one voice — every top-level message
    // is from the org, so it always sits on the "sent" (right, colored) side,
    // mirroring a standard chat UI. Student replies render as the "received"
    // (left, gray) side inside _buildReplyPreview below.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.authorName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: _C.charcoal)),
                      const SizedBox(width: 8),
                      const Icon(Icons.circle, size: 3, color: _C.textFaint),
                      const SizedBox(width: 8),
                      Text(_timeLabel(b.timestamp), style: GoogleFonts.beVietnamPro(fontSize: 11, color: _C.textFaint)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Message bubble
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [widget.primaryColor, widget.accentColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      boxShadow: _DS.bubbleShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.imageUrl != null && b.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(4),
                            ),
                            child: Image(
                              image: _imageProviderFromUrl(b.imageUrl!),
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 220,
                                color: Colors.black26,
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 40)),
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (b.content.isNotEmpty)
                                Text(b.content, style: GoogleFonts.beVietnamPro(fontSize: 13, color: Colors.white, height: 1.6)),
                              if (b.attachments.isNotEmpty) ...[
                                if (b.content.isNotEmpty) const SizedBox(height: 12),
                                ...b.attachments.map((att) => _AttachmentChip(att: att)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pinned badge
                  if (b.pinned)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: widget.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.push_pin_rounded, size: 12, color: widget.primaryColor),
                          const SizedBox(width: 4),
                          Text('Pinned', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: widget.primaryColor)),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _buildReplyMeta(),
                  _buildReplyPreview(),
                ],
              ),
            ),

            // Org actions — visible on hover, since any officer can manage
            // a channel message.
            if (_hovered) ...[
              const SizedBox(width: 8),
              _ActionButton(icon: Icons.edit_outlined, onTap: _editMessage, color: _C.charcoal),
              const SizedBox(width: 6),
              _ActionButton(
                icon: widget.broadcast.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                onTap: _togglePinMessage,
                color: widget.broadcast.pinned ? widget.primaryColor : _C.charcoal,
              ),
              const SizedBox(width: 6),
              _ActionButton(icon: Icons.delete_outline_rounded, onTap: widget.onDelete, color: _C.error, bgColor: _C.errorBg),
            ] else
              const SizedBox(width: 98),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color? bgColor;
  const _ActionButton({required this.icon, required this.onTap, required this.color, this.bgColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor ?? _C.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.borderSoft),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

class _MiniActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _C.darkGray),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: _C.darkGray)),
        ],
      ),
    );
  }
}

// A student reply renders as the "received" side of the conversation —
// a gray bubble, left-aligned, opposite the org's colored bubble.
class _ReplyRow extends StatelessWidget {
  final BroadcastReply reply;
  const _ReplyRow({required this.reply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: _C.borderSoft, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(
                reply.authorName.isNotEmpty ? reply.authorName[0].toUpperCase() : '?',
                style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textMid),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(color: _C.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(reply.authorName, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: _C.charcoal)),
                      const SizedBox(width: 8),
                      Text(DateFormat('h:mm a').format(reply.timestamp.toDate()), style: GoogleFonts.beVietnamPro(fontSize: 10, color: _C.textFaint)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reply.content, style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: _C.textMid, height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final Attachment att;
  const _AttachmentChip({required this.att});

  Future<void> _open(BuildContext context) async {
    try {
      await platform_file_utils.openUrl(att.url);
    } catch (e) {
      Clipboard.setData(ClipboardData(text: att.url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file — link copied instead: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                att.name,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class BroadcastReply {
  final String id;
  final String content;
  final String authorName;
  final Timestamp timestamp;
  BroadcastReply({required this.id, required this.content, required this.authorName, required this.timestamp});
  factory BroadcastReply.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BroadcastReply(
      id: doc.id,
      content: d['content'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      timestamp: d['timestamp'] as Timestamp,
    );
  }
}

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
    Timestamp? ts = d['timestamp'];
    if (ts == null) ts = Timestamp.now();
    return BroadcastModel(
      id: doc.id,
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      likes: (d['likes'] as int?) ?? 0,
      replyCount: (d['replyCount'] as int?) ?? 0,
      pinned: (d['pinned'] as bool?) ?? false,
      timestamp: ts,
      attachments: ((d['attachments'] as List?) ?? []).map((a) => Attachment(name: a['name'] ?? '', url: a['url'] ?? '')).toList(),
      imageUrl: d['imageUrl'] == '' ? null : d['imageUrl'],
    );
  }
}
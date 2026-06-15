// lib/screens/web/org/org_broadcast.dart
// Complete with all features: edit, pin, replies, file/image upload, right/left alignment

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
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color accent = Color(0xFFF97316);
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
  static const double radiusMd = 12;
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
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  List<Attachment> _pendingAttachments = [];
  String? _pendingImageUrl;
  bool _isSending = false;
  bool _isUploadingFile = false;
  bool _isUploadingImage = false;
  int _memberCount = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchMemberCount();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _currentUserId = user?.uid);
  }

  Future<void> _fetchMemberCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .collection('members')
          .get();
      if (mounted) setState(() => _memberCount = snap.size);
    } catch (_) {}
  }

  Stream<QuerySnapshot> get _broadcastsStream => FirebaseFirestore.instance
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
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() => _isUploadingFile = true);

    try {
      int uploaded = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        if (bytes.length > 10 * 1024 * 1024) {
          _snack('${file.name} exceeds 10 MB', isError: true);
          continue;
        }
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance.ref().child('broadcasts/${widget.orgId}/files/$fileName');
        await ref.putData(bytes);
        final url = await ref.getDownloadURL();
        setState(() => _pendingAttachments.add(Attachment(name: file.name, url: url)));
        uploaded++;
      }
      if (uploaded > 0) _snack('$uploaded file(s) attached');
    } catch (e) {
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
    } catch (e) {
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';

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

      await FirebaseFirestore.instance.collection('broadcasts').add(data);
      await activity_log.ActivityLogger.log(
        action: 'send_broadcast',
        module: 'broadcast',
        details: {'orgId': widget.orgId},
      );

      _messageCtrl.clear();
      setState(() {
        _pendingAttachments = [];
        _pendingImageUrl = null;
      });
      _inputFocus.requestFocus();
      Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);
    } catch (e) {
      _snack('Failed to send: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final horizontalPadding = isMobile ? 16.0 : 28.0;

    return Scaffold(
      backgroundColor: _C.pageBg,
      body: Column(
        children: [
          _buildChannelHeader(isMobile, horizontalPadding),
          Expanded(child: _buildFeedShell(isMobile, horizontalPadding)),
          if (_pendingAttachments.isNotEmpty || _pendingImageUrl != null)
            _buildAttachmentPreviewBar(horizontalPadding),
          _buildComposeBar(isMobile, horizontalPadding),
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
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: _C.primaryDark.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.campaign_rounded, color: _C.primaryDark, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Broadcast Channel', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w800, color: _C.primaryDark)),
                          const SizedBox(height: 2),
                          Text(widget.orgName, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray)),
                        ],
                      ),
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
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: _C.primaryDark.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.campaign_rounded, color: _C.primaryDark, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Broadcast Channel', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w800, color: _C.primaryDark)),
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
              ],
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

          final items = snap.data!.docs
              .map((d) => BroadcastModel.fromFirestore(d))
              .where((m) => m.timestamp != null)
              .toList()
              .reversed
              .toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
            }
          });

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
                    isMine: msg.authorId == _currentUserId,
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

  Widget _buildComposeBar(bool isMobile, double horizontalPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 18),
      decoration: BoxDecoration(color: _C.white, border: const Border(top: BorderSide(color: _C.border)), boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ComposeToolbarBtn(icon: Icons.attach_file_rounded, label: 'Attach', isLoading: _isUploadingFile, onTap: _pickFiles),
              _ComposeToolbarBtn(icon: Icons.image_outlined, label: 'Image', isLoading: _isUploadingImage, onTap: _pickImage),
              SizedBox(
                width: isMobile ? double.infinity : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(_DS.radiusMd), border: Border.all(color: _C.borderSoft)),
                  child: TextField(
                    controller: _messageCtrl,
                    focusNode: _inputFocus,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.charcoal),
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Write a message to all members…',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.textFaint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Builder(
                builder: (ctx) {
                  final hasContent = _messageCtrl.text.trim().isNotEmpty || _pendingAttachments.isNotEmpty || _pendingImageUrl != null;
                  final canSend = hasContent && !_isSending;
                  return InkWell(
                    onTap: canSend ? _sendMessage : null,
                    borderRadius: BorderRadius.circular(_DS.radiusMd),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: canSend ? const LinearGradient(colors: [_C.primaryDark, _C.accent]) : LinearGradient(colors: [_C.primaryDark.withValues(alpha: 0.4), _C.accent.withValues(alpha: 0.4)]),
                        borderRadius: BorderRadius.circular(_DS.radiusMd),
                        boxShadow: canSend ? [BoxShadow(color: _C.accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))] : [],
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
          const SizedBox(height: 6),
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
class _ComposeToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  const _ComposeToolbarBtn({required this.icon, required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.borderSoft)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.darkGray))
            else
              Icon(icon, size: 15, color: _C.darkGray),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.darkGray, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
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
  final bool isMine;
  final String orgId;
  const _BroadcastBubble({required this.broadcast, required this.onDelete, required this.isMine, required this.orgId});

  @override
  State<_BroadcastBubble> createState() => _BroadcastBubbleState();
}

class _BroadcastBubbleState extends State<_BroadcastBubble> {
  bool _hovered = false;
  bool _isPinning = false;
  bool _isEditing = false;

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
            _MiniActionChip(icon: Icons.mode_comment_outlined, label: '$replyCount'),
            const Spacer(),
            Text('Replies', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textFaint)),
          ],
        );
      },
    );
  }

  Widget _buildReplyPreview() {
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
        final preview = replies.length > 2 ? replies.take(2).toList() : replies;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            ...preview.map((reply) => _ReplyRow(reply: reply)),
            if (replies.length > 2) ...[
              const SizedBox(height: 6),
              Text('View all ${replies.length} replies',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.primaryDark, fontWeight: FontWeight.w700)),
            ],
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // Left side actions (for messages from others) - only show on hover
            if (!widget.isMine && _hovered) ...[
              _ActionButton(icon: Icons.edit_outlined, onTap: _editMessage, color: _C.charcoal),
              const SizedBox(width: 6),
              _ActionButton(
                icon: widget.broadcast.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                onTap: _togglePinMessage,
                color: widget.broadcast.pinned ? _C.primaryDark : _C.charcoal,
              ),
              const SizedBox(width: 6),
              _ActionButton(icon: Icons.delete_outline_rounded, onTap: widget.onDelete, color: _C.error, bgColor: _C.errorBg),
              const SizedBox(width: 8),
            ] else if (!widget.isMine) ...[
              const SizedBox(width: 98),
            ],

            Flexible(
              child: Column(
                crossAxisAlignment: widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Author name - only shown for messages from others
                  if (!widget.isMine)
                    Row(
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
                      gradient: const LinearGradient(colors: [_C.primaryDark, _C.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(widget.isMine ? 14 : 4),
                        topRight: Radius.circular(widget.isMine ? 4 : 14),
                        bottomLeft: const Radius.circular(14),
                        bottomRight: const Radius.circular(14),
                      ),
                      boxShadow: _DS.bubbleShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.imageUrl != null && b.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(widget.isMine ? 14 : 4),
                              topRight: Radius.circular(widget.isMine ? 4 : 14),
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
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.push_pin_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('Pinned', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _buildReplyMeta(),
                  _buildReplyPreview(),
                ],
              ),
            ),

            // Right side actions (for my messages) - only show on hover
            if (widget.isMine && _hovered) ...[
              const SizedBox(width: 8),
              _ActionButton(icon: Icons.edit_outlined, onTap: _editMessage, color: _C.charcoal),
              const SizedBox(width: 6),
              _ActionButton(
                icon: widget.broadcast.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                onTap: _togglePinMessage,
                color: widget.broadcast.pinned ? _C.primaryDark : _C.charcoal,
              ),
              const SizedBox(width: 6),
              _ActionButton(icon: Icons.delete_outline_rounded, onTap: widget.onDelete, color: _C.error, bgColor: _C.errorBg),
            ] else if (widget.isMine) ...[
              const SizedBox(width: 98),
            ],
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ReplyRow extends StatelessWidget {
  final BroadcastReply reply;
  const _ReplyRow({required this.reply});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(reply.authorName, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              Text(DateFormat('h:mm a').format(reply.timestamp.toDate()), style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Text(reply.content, style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white, height: 1.5)),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final Attachment att;
  const _AttachmentChip({required this.att});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: att.url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard'), duration: Duration(seconds: 2)),
        );
      },
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
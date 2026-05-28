// lib/screens/web/org/org_broadcast.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// ─── Color Scheme ─────────────────────────────────────────────────────────────
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class OrgBroadcastScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const OrgBroadcastScreen({
    super.key,
    required this.orgId,
    this.orgName = 'Organization',
  });

  @override
  State<OrgBroadcastScreen> createState() => _OrgBroadcastScreenState();
}

class _OrgBroadcastScreenState extends State<OrgBroadcastScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Attachment> _pendingAttachments = [];
  String? _pendingImageUrl;
  bool _isSending = false;
  bool _isUploadingFile = false;
  bool _isUploadingImage = false;

  // Member count — fetch once
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchMemberCount();
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

  Future<void> _pickFiles() async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
  if (result == null) return;
  
  setState(() => _isUploadingFile = true);
  
  try {
    int uploaded = 0;
    final total = result.files.length;
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Uploading files...', style: GoogleFonts.beVietnamPro()),
                const SizedBox(height: 8),
                Text('$uploaded of $total', style: GoogleFonts.beVietnamPro(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
    
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      
      // Check file size (max 10MB)
      const maxSize = 10 * 1024 * 1024; // 10MB
      if (bytes.length > maxSize) {
        _showError('${file.name} is too large. Max 10MB');
        continue;
      }
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('broadcasts/${widget.orgId}/files/$fileName');
      
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      
      setState(() {
        _pendingAttachments.add(Attachment(name: file.name, url: url));
      });
      
      uploaded++;
      
      // Update dialog
      if (mounted) {
        Navigator.pop(context); // Close old
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Uploading files...', style: GoogleFonts.beVietnamPro()),
                const SizedBox(height: 8),
                Text('$uploaded of $total', style: GoogleFonts.beVietnamPro(fontSize: 12)),
              ],
            ),
          ),
        );
      }
    }
    
    // Close dialog
    if (mounted) Navigator.pop(context);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$uploaded files uploaded successfully!'),
          backgroundColor: OrgColors.success,
        ),
      );
    }
  } catch (e) {
    if (mounted) Navigator.pop(context); // Close dialog
    print('File upload error: $e');
    _showError('Upload failed: $e');
  } finally {
    if (mounted) setState(() => _isUploadingFile = false);
  }
}

  Future<void> _pickImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;
  
  setState(() => _isUploadingImage = true);
  
  try {
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) throw 'No image data';
    
    // Check file size (max 5MB)
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (bytes.length > maxSize) {
      _showError('Image too large. Max 5MB');
      return;
    }
    
    // Show loading dialog with progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Uploading image...', style: GoogleFonts.beVietnamPro()),
          ],
        ),
      ),
    );
    
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = FirebaseStorage.instance
        .ref()
        .child('broadcasts/${widget.orgId}/images/$fileName');
    
    // Upload with metadata
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    final downloadUrl = await ref.getDownloadURL();
    
    // Close loading dialog
    Navigator.pop(context);
    
    setState(() => _pendingImageUrl = downloadUrl);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image ready!'), backgroundColor: OrgColors.success),
      );
    }
  } catch (e) {
    if (mounted) Navigator.pop(context); // Close dialog if error
    print('Image upload error: $e');
    _showError('Failed to upload image: $e');
  } finally {
    if (mounted) setState(() => _isUploadingImage = false);
  }
}

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: OrgColors.error),
    );
  }

  Future<void> _sendMessage() async {
  final text = _messageCtrl.text.trim();
  if (text.isEmpty && _pendingAttachments.isEmpty && _pendingImageUrl == null) return;
  
  setState(() => _isSending = true);
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'No user logged in';
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    final authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';
    
    // Prepare data (imageUrl is already a Storage URL if exists)
    final broadcastData = {
      'orgId': widget.orgId,
      'content': text,
      'authorId': user.uid,
      'authorName': authorName,
      'attachments': _pendingAttachments.map((a) => {'name': a.name, 'url': a.url}).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    // Only add imageUrl if it exists
    if (_pendingImageUrl != null && _pendingImageUrl!.isNotEmpty) {
      broadcastData['imageUrl'] = _pendingImageUrl;
    }
    
    await FirebaseFirestore.instance.collection('broadcasts').add(broadcastData);
    
    await activity_log.ActivityLogger.log(
      action: 'send_broadcast',
      module: 'broadcast',
      details: {'orgId': widget.orgId},
    );
    
    // Clear everything
    _messageCtrl.clear();
    setState(() {
      _pendingAttachments = [];
      _pendingImageUrl = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent!'), backgroundColor: OrgColors.success),
      );
    }
    
    _scrollToBottom();
  } catch (e) {
    print('Send error: $e');
    _showError('Failed to send: $e');
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}

  Future<void> _deleteMessage(BroadcastModel broadcast) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OrgColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: OrgColors.error, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Delete Message',
                    style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              Text('This message will be permanently deleted.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro()),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrgColors.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Delete',
                      style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
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
      await activity_log.ActivityLogger.log(action: 'delete_broadcast', module: 'broadcast',
          details: {'orgId': widget.orgId, 'broadcastId': broadcast.id});
    } catch (e) {
      _showError('Error: $e');
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Channel Header ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          decoration: const BoxDecoration(
            color: OrgColors.white,
            border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OrgColors.primaryDark, OrgColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Broadcast Channel',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 17, fontWeight: FontWeight.w800, color: OrgColors.charcoal)),
                  Text(widget.orgName,
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                ],
              ),
            ],
          ),
        ),

        // ── Message Feed ──────────────────────────────────────────────────
        Expanded(
  child: Container(
    color: OrgColors.lightGray,
    child: StreamBuilder<QuerySnapshot>(
      stream: _broadcastsStream,
      builder: (context, snapshot) {
        // ✅ Add error handling
        if (snapshot.hasError) {
          print('❌ Stream error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: OrgColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages: ${snapshot.error}',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() {}), // Refresh
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: OrgColors.accent.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign_outlined, size: 44, color: OrgColors.accent),
                ),
                const SizedBox(height: 16),
                Text('No messages yet',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                const SizedBox(height: 6),
                Text('Send a broadcast to all members below.',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
              ],
            ),
          );
        }

        final items = snapshot.data!.docs
            .map((d) => BroadcastModel.fromFirestore(d))
            .toList();
            
        print('✅ Loaded ${items.length} broadcasts'); // Debug log

        _scrollToBottom();

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final msg = items[i];
            final showDateSep = i == 0 ||
                !_sameDay(items[i - 1].timestamp, msg.timestamp);
            return Column(
              children: [
                if (showDateSep) _DateSeparator(timestamp: msg.timestamp),
                _BroadcastBubble(
                  broadcast: msg,
                  onDelete: () => _deleteMessage(msg),
                ),
              ],
            );
          },
        );
      },
    ),
  ),
),

        // ── Pending Attachments Preview ───────────────────────────────────
        if (_pendingAttachments.isNotEmpty || _pendingImageUrl != null)
          Container(
            color: OrgColors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_pendingImageUrl != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image(
                          image: _imageProviderFromUrl(_pendingImageUrl!),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: InkWell(
                          onTap: () => setState(() => _pendingImageUrl = null),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ..._pendingAttachments.asMap().entries.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: OrgColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OrgColors.primaryLight),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 14, color: OrgColors.info),
                        const SizedBox(width: 6),
                        Text(e.value.name,
                            style: GoogleFonts.beVietnamPro(fontSize: 12),
                            maxLines: 120),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _pendingAttachments.removeAt(e.key)),
                          child: const Icon(Icons.close, size: 12, color: OrgColors.darkGray),
                        ),
                      ]),
                    )),
              ],
            ),
          ),

        // ── Compose Bar ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: const BoxDecoration(
            color: OrgColors.white,
            border: Border(top: BorderSide(color: OrgColors.primaryLight)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toolbar
              Row(
                children: [
                  _ToolbarBtn(
                    icon: Icons.attach_file_rounded,
                    label: 'Attach',
                    isLoading: _isUploadingFile,
                    onTap: _pickFiles,
                  ),
                  const SizedBox(width: 4),
                  _ToolbarBtn(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    isLoading: _isUploadingImage,
                    onTap: _pickImage,
                  ),
                  const SizedBox(width: 4),
                  _ToolbarBtn(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Emoji',
                    onTap: () {}, // placeholder
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Input row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: OrgColors.lightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OrgColors.primaryLight),
                      ),
                      child: TextField(
                        controller: _messageCtrl,
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Click here to type your message to all members...',
                          hintStyle:
                              GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Send button
                  InkWell(
                    onTap: _isSending ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [OrgColors.primaryDark, OrgColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: OrgColors.accent.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Footer note
              Text(
                _memberCount > 0
                    ? 'Your messages will be sent to all ${_memberCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} members. Only you can send messages.'
                    : 'Your messages will be sent to all members. Only you can send messages.',
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _sameDay(Timestamp a, Timestamp b) {
    final da = a.toDate();
    final db = b.toDate();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }
}

// ─── Toolbar Button ───────────────────────────────────────────────────────────
class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: OrgColors.darkGray))
            else
              Icon(icon, size: 16, color: OrgColors.darkGray),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Date Separator ───────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final Timestamp timestamp;
  const _DateSeparator({required this.timestamp});

  String _label() {
    final now = DateTime.now();
    final date = timestamp.toDate();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: OrgColors.mediumGray)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_label(),
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
          ),
          const Expanded(child: Divider(color: OrgColors.mediumGray)),
        ],
      ),
    );
  }
}

// ─── Broadcast Bubble ─────────────────────────────────────────────────────────
class _BroadcastBubble extends StatefulWidget {
  final BroadcastModel broadcast;
  final VoidCallback onDelete;

  const _BroadcastBubble({required this.broadcast, required this.onDelete});

  @override
  State<_BroadcastBubble> createState() => _BroadcastBubbleState();
}

class _BroadcastBubbleState extends State<_BroadcastBubble> {
  bool _hovered = false;

  String _timeLabel(Timestamp ts) {
    return DateFormat('h:mm a').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.broadcast;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OrgColors.accent.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image if any
                    if (b.imageUrl != null && b.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image(
                          image: _imageProviderFromUrl(b.imageUrl!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Text content
                    if (b.content.isNotEmpty)
                      Text(b.content,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13, color: Colors.white, height: 1.55)),
                    // Attachments
                    if (b.attachments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...b.attachments.map((att) => InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: att.url));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied')),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                const Icon(Icons.insert_drive_file_outlined,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(att.name,
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 12, color: Colors.white,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.white),
                                        overflow: TextOverflow.ellipsis)),
                                const Icon(Icons.download_outlined, size: 14, color: Colors.white),
                              ]),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Time + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: OrgColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_outline, size: 14, color: OrgColors.error),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_timeLabel(b.timestamp),
                    style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _mimeTypeFromPath(String? path) {
  if (path == null) return 'image/png';
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'bmp':
      return 'image/bmp';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/png';
  }
}

ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}

// ─── Model Classes ────────────────────────────────────────────────────────────
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
  final Timestamp timestamp;
  final List<Attachment> attachments;
  final String? imageUrl;

  const BroadcastModel({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
    required this.attachments,
    this.imageUrl,
  });

  factory BroadcastModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  
  // ✅ Handle both null and empty string for imageUrl
  String? imageUrl = data['imageUrl'];
  if (imageUrl == '') imageUrl = null;
  
  return BroadcastModel(
    id: doc.id,
    content: data['content'] ?? '',
    authorId: data['authorId'] ?? '',
    authorName: data['authorName'] ?? 'Unknown',
    timestamp: data['timestamp'] as Timestamp,
    attachments: ((data['attachments'] as List?) ?? [])
        .map((a) => Attachment(name: a['name'], url: a['url']))
        .toList(),
    imageUrl: imageUrl,
  );
}
}

// Extension helper for Text max width
extension _TextExt on Text {
  Widget maxWidth(double w) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w),
        child: this,
      );
}



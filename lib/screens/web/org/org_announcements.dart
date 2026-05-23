// lib/screens/web/org/org_announcements.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../services/activity_logger.dart' as activity_log;

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

Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover, Widget? errorWidget}) {
  return Image(
    image: _imageProviderFromUrl(url),
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
  );
}

// ─── Color Scheme ────────────────────────────────────────────────────────────
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
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class OrgAnnouncementsScreen extends StatefulWidget {
  final String orgId;
  const OrgAnnouncementsScreen({super.key, required this.orgId});

  @override
  State<OrgAnnouncementsScreen> createState() => _OrgAnnouncementsScreenState();
}

class _OrgAnnouncementsScreenState extends State<OrgAnnouncementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Stream<QuerySnapshot> get _announcementsStream => FirebaseFirestore.instance
      .collection('announcements')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('timestamp', descending: true)
      .snapshots();

  void _openCreateModal() {
    _showAnnouncementSheet(context, orgId: widget.orgId);
  }

  void _openEditModal(AnnouncementModel announcement) {
    _showAnnouncementSheet(context, orgId: widget.orgId, existing: announcement);
  }

  Future<void> _deleteAnnouncement(AnnouncementModel announcement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: const Icon(Icons.delete_outline, color: OrgColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Delete Announcement',
                    style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "${announcement.title}"? This action cannot be undone.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: OrgColors.darkGray, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Delete', style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
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
      for (final attachment in announcement.attachments) {
        try { await FirebaseStorage.instance.refFromURL(attachment.url).delete(); } catch (_) {}
      }
      if (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty && !announcement.imageUrl!.startsWith('data:image')) {
        try { await FirebaseStorage.instance.refFromURL(announcement.imageUrl!).delete(); } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('announcements').doc(announcement.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_announcement',
        module: 'announcements',
        details: {'orgId': widget.orgId, 'announcementId': announcement.id, 'title': announcement.title},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Announcement deleted successfully'),
            ]),
            backgroundColor: OrgColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: OrgColors.error),
        );
      }
    }
  }

  List<AnnouncementModel> _filterAnnouncements(List<AnnouncementModel> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((a) =>
        a.title.toLowerCase().contains(q) ||
        a.content.toLowerCase().contains(q) ||
        a.category.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Announcements',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 24, fontWeight: FontWeight.w800, color: OrgColors.charcoal)),
                  const SizedBox(height: 3),
                  Text('Share updates, events, and important information with your members',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
                ],
              ),
              const Spacer(),
              // Search
              Container(
                width: 280,
                height: 44,
                margin: const EdgeInsets.only(right: 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.beVietnamPro(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search announcements...',
                    hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: OrgColors.darkGray),
                    filled: true,
                    fillColor: OrgColors.lightGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OrgColors.primaryLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OrgColors.primaryLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
              // Create button
              ElevatedButton.icon(
                onPressed: _openCreateModal,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text('Create Announcement',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Feed ────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _announcementsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _EmptyState(onCreateTap: _openCreateModal);
                }
                final all = snapshot.data!.docs
                    .map((doc) => AnnouncementModel.fromFirestore(doc))
                    .toList();
                final filtered = _filterAnnouncements(all);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No matching announcements',
                        style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (ctx, i) => _AnnouncementCard(
                    announcement: filtered[i],
                    onEdit: () => _openEditModal(filtered[i]),
                    onDelete: () => _deleteAnnouncement(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementSheet(
    BuildContext context, {
    required String orgId,
    AnnouncementModel? existing,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: _AnnouncementSheet(orgId: orgId, existingAnnouncement: existing),
      ),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// ─── Announcement Card ────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrgColors.primaryLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner Image ──────────────────────────────────────────────
          if (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty)
            Stack(
              children: [
                Image.network(
                  announcement.imageUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: OrgColors.lightGray,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: OrgColors.mediumGray, size: 40)),
                  ),
                ),
                // Category tag over image
                if (announcement.category.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: _CategoryChip(label: announcement.category),
                  ),
              ],
            )
          else if (announcement.category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _CategoryChip(label: announcement.category),
            ),

          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 20, fontWeight: FontWeight.w800, color: OrgColors.charcoal),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            const Icon(Icons.edit_outlined, size: 16, color: OrgColors.darkGray),
                            const SizedBox(width: 8),
                            Text('Edit', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            const Icon(Icons.delete_outline, size: 16, color: OrgColors.error),
                            const SizedBox(width: 8),
                            Text('Delete',
                                style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.error)),
                          ]),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz, color: OrgColors.darkGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Author row
                Row(children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: OrgColors.accent.withOpacity(0.15),
                    child: Text(
                      announcement.authorName.isNotEmpty
                          ? announcement.authorName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 12, fontWeight: FontWeight.w700, color: OrgColors.primaryDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(announcement.authorName,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                  const SizedBox(width: 6),
                  Text('·',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
                  const SizedBox(width: 6),
                  Text(_timeAgo(announcement.timestamp),
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                ]),
                const SizedBox(height: 14),

                // Content
                Text(
                  announcement.content,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14, height: 1.65, color: OrgColors.charcoal.withOpacity(0.85)),
                ),

                // Attachments
                if (announcement.attachments.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('ATTACHMENTS (${announcement.attachments.length})',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: OrgColors.darkGray, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  ...announcement.attachments.map((att) => _AttachmentTile(attachment: att)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return DateFormat('MMM dd, yyyy').format(ts.toDate());
  }
}

// ─── Category Chip ────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: OrgColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.beVietnamPro(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
      ),
    );
  }
}

// ─── Attachment Tile ──────────────────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final Attachment attachment;
  const _AttachmentTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: OrgColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.insert_drive_file_outlined, size: 16, color: OrgColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(attachment.name,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: attachment.url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.download_outlined, size: 18, color: OrgColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.campaign_outlined, size: 48, color: OrgColors.accent),
          ),
          const SizedBox(height: 16),
          Text('No Announcements Yet',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 18, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          const SizedBox(height: 8),
          Text('Post updates, news, and important info for your members.',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: Text('Create First Announcement',
                style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Side Sheet Modal ─────────────────────────────────────────────────────────
class _AnnouncementSheet extends StatefulWidget {
  final String orgId;
  final AnnouncementModel? existingAnnouncement;

  const _AnnouncementSheet({required this.orgId, this.existingAnnouncement});

  @override
  State<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends State<_AnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _categoryCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  List<Attachment> _attachments = [];
  String? _imageUrl;
  bool _isSubmitting = false;
  bool _isUploadingFile = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existingAnnouncement;
    if (e != null) {
      _categoryCtrl.text = e.category;
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content;
      _attachments = List.from(e.attachments);
      _imageUrl = e.imageUrl;
    }
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploadingImage = true);
    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw 'Image bytes not available';
      final mimeType = _mimeTypeFromPath(file.path);
      final uri = 'data:$mimeType;base64,${base64Encode(bytes)}';
      setState(() => _imageUrl = uri);
    } catch (e) {
      _showError('Image upload failed: $e');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() => _isUploadingFile = true);
    try {
      final newAtts = <Attachment>[];
      for (final file in result.files) {
        if (file.bytes == null && file.path == null) continue;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('announcements/${widget.orgId}/$fileName');
        if (file.bytes != null) {
          await ref.putData(file.bytes!);
        } else if (file.path != null) {
          await ref.putFile(File(file.path!));
        }
        final url = await ref.getDownloadURL();
        newAtts.add(Attachment(name: file.name, url: url));
      }
      setState(() => _attachments.addAll(newAtts));
    } catch (e) {
      _showError('File upload failed: $e');
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: OrgColors.error),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';

      final data = <String, dynamic>{
        'orgId': widget.orgId,
        'category': _categoryCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'authorId': user.uid,
        'authorName': authorName,
        'attachments': _attachments.map((a) => {'name': a.name, 'url': a.url}).toList(),
        'imageUrl': _imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existingAnnouncement != null) {
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(widget.existingAnnouncement!.id)
            .update(data);
        await activity_log.ActivityLogger.log(
          action: 'edit_announcement',
          module: 'announcements',
          details: {'orgId': widget.orgId, 'announcementId': widget.existingAnnouncement!.id},
        );
      } else {
        data['timestamp'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('announcements').add(data);
        await activity_log.ActivityLogger.log(
          action: 'create_announcement',
          module: 'announcements',
          details: {'orgId': widget.orgId, 'title': data['title']},
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingAnnouncement != null;
    return Material(
      elevation: 16,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
      color: OrgColors.white,
      child: SizedBox(
        width: 440,
        height: double.infinity,
        child: Column(
          children: [
            // ── Sheet Header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit Announcement' : 'Create New Announcement',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 17, fontWeight: FontWeight.w800, color: OrgColors.charcoal)),
                  const SizedBox(height: 2),
                  Text('Share updates, events, and important information with your members',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                ]),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: OrgColors.lightGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: OrgColors.darkGray),
                  ),
                ),
              ]),
            ),

            // ── Form Body ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      _FieldLabel(label: 'Category', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _categoryCtrl,
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        decoration: _inputDecoration('e.g., Event Update, General Assembly, Competition'),
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      // Title
                      _FieldLabel(label: 'Title', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleCtrl,
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        decoration: _inputDecoration('Enter announcement title'),
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      // Content
                      _FieldLabel(label: 'Content', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contentCtrl,
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        maxLines: 6,
                        decoration: _inputDecoration('Write your announcement content...'),
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      // Attachments
                      _FieldLabel(label: 'Attachment'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isUploadingFile ? null : _pickFiles,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: OrgColors.lightGray,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: OrgColors.primaryLight),
                          ),
                          child: Column(children: [
                            if (_isUploadingFile)
                              const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: OrgColors.primaryDark))
                            else
                              const Icon(Icons.upload_outlined, size: 24, color: OrgColors.darkGray),
                            const SizedBox(height: 6),
                            Text('Click to upload files',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                            Text('Size up to 5MB',
                                style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                          ]),
                        ),
                      ),
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._attachments.asMap().entries.map((e) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: OrgColors.primaryLight),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                const Icon(Icons.insert_drive_file_outlined,
                                    size: 14, color: OrgColors.info),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(e.value.name,
                                        style: GoogleFonts.beVietnamPro(fontSize: 12),
                                        overflow: TextOverflow.ellipsis)),
                                InkWell(
                                  onTap: () => setState(() => _attachments.removeAt(e.key)),
                                  child: const Icon(Icons.close, size: 14, color: OrgColors.darkGray),
                                ),
                              ]),
                            )),
                      ],
                      const SizedBox(height: 18),

                      // Image Upload
                      _FieldLabel(label: 'Image', required: true),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isUploadingImage ? null : _pickImage,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          height: _imageUrl != null ? null : 110,
                          decoration: BoxDecoration(
                            color: OrgColors.lightGray,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: OrgColors.primaryLight),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _imageUrl != null
                              ? Stack(children: [
                                  Image.network(_imageUrl!,
                                      width: double.infinity,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox()),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: InkWell(
                                      onTap: () => setState(() => _imageUrl = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ])
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isUploadingImage)
                                      const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: OrgColors.primaryDark))
                                    else
                                      const Icon(Icons.image_outlined, size: 28, color: OrgColors.darkGray),
                                    const SizedBox(height: 6),
                                    Text('Click to upload announcement image',
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                                    Text('Recommended: 1200×630px (PNG, JPG up to 5MB)',
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 10, color: OrgColors.darkGray)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: OrgColors.primaryLight),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.beVietnamPro(
                              fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _isUploadingFile || _isUploadingImage) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrgColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              isEdit ? 'Save Changes' : 'Post Announcement',
                              style: GoogleFonts.beVietnamPro(
                                  color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
        filled: true,
        fillColor: OrgColors.lightGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.error)),
      );
}

// ─── Field Label Helper ───────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
      if (required) ...[
        const SizedBox(width: 3),
        const Text('*', style: TextStyle(color: OrgColors.error, fontSize: 13)),
      ],
    ]);
  }
}

// ─── Model Classes ────────────────────────────────────────────────────────────
class Attachment {
  final String name;
  final String url;
  const Attachment({required this.name, required this.url});
}

class AnnouncementModel {
  final String id;
  final String category;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final Timestamp timestamp;
  final List<Attachment> attachments;
  final String? imageUrl;

  const AnnouncementModel({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
    required this.attachments,
    this.imageUrl,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      category: data['category'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      timestamp: data['timestamp'] as Timestamp,
      attachments: ((data['attachments'] as List?) ?? [])
          .map((a) => Attachment(name: a['name'], url: a['url']))
          .toList(),
      imageUrl: data['imageUrl'] as String?,
    );
  }
}




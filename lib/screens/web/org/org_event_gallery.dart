// lib/screens/web/org/org_event_gallery.dart
//
// Event Gallery panel — lets an org upload photos for the event it's
// currently managing. Embedded as a sub-tab inside org_attendance_qr.dart's
// per-event screen (next to Attendance / Registered Participants) rather
// than as its own top-level dashboard tab, since the event is already
// selected there — no need for a second, redundant event picker.
//
// Photos live in Firebase Storage (event_photos/{eventId}/...) with a
// matching Firestore doc per photo in events/{eventId}/photos, so
// students/guests can view them from the event detail screen.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class _DS {
  static const double radiusMd = 12;
}

class EventGalleryPanel extends StatefulWidget {
  final String orgId;
  final String eventId;
  final String eventTitle;
  const EventGalleryPanel({
    super.key,
    required this.orgId,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventGalleryPanel> createState() => _EventGalleryPanelState();
}

class _EventGalleryPanelState extends State<EventGalleryPanel> {
  bool _uploading = false;

  Stream<QuerySnapshot> get _photosStream => FirebaseFirestore.instance
      .collection('events')
      .doc(widget.eventId)
      .collection('photos')
      .orderBy('uploadedAt', descending: true)
      .snapshots();

  Future<void> _uploadPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    int succeeded = 0;
    int failed = 0;

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        failed++;
        continue;
      }
      try {
        final ext = (file.extension ?? 'jpg').toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${succeeded + failed}.$ext';
        final path = 'event_photos/${widget.eventId}/$fileName';
        final ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}'),
        );
        final url = await ref.getDownloadURL();
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('photos')
            .add({
          'url': url,
          'storagePath': path,
          'uploadedBy': widget.orgId,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
        succeeded++;
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed == 0
            ? 'Uploaded $succeeded photo${succeeded == 1 ? '' : 's'}.'
            : 'Uploaded $succeeded photo${succeeded == 1 ? '' : 's'}, $failed failed.'),
        backgroundColor: failed == 0 ? UpriseColors.success : UpriseColors.warning,
      ));
    }
  }

  Future<void> _deletePhoto(DocumentSnapshot photoDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete photo?', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Text('This removes it from the event gallery for everyone.',
            style: GoogleFonts.beVietnamPro(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: UpriseColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final data = photoDoc.data() as Map<String, dynamic>;
      final storagePath = data['storagePath'] as String?;
      if (storagePath != null) {
        try {
          await FirebaseStorage.instance.ref().child(storagePath).delete();
        } catch (_) {
          // Storage object may already be gone — still remove the Firestore record.
        }
      }
      await photoDoc.reference.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not delete photo: $e'),
          backgroundColor: UpriseColors.error,
        ));
      }
    }
  }

  void _viewPhotoFullscreen(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: Stack(clipBehavior: Clip.none, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: -16,
            right: -16,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54, shape: const CircleBorder()),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('Photos for "${widget.eventTitle}"',
                style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
          ),
          ElevatedButton.icon(
            onPressed: _uploading ? null : _uploadPhotos,
            icon: _uploading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text(_uploading ? 'Uploading...' : 'Upload Photos',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UpriseColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _photosStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark)),
              );
            }
            final photos = snapshot.data!.docs;
            if (photos.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.photo_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No photos yet for this event.',
                        style: GoogleFonts.beVietnamPro(color: Colors.grey.shade500, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Upload some to share with students and guests.',
                        style: GoogleFonts.beVietnamPro(color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                ),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final doc = photos[i];
                final data = doc.data() as Map<String, dynamic>;
                final url = data['url'] as String? ?? '';
                return _PhotoTile(
                  url: url,
                  onTap: () => _viewPhotoFullscreen(url),
                  onDelete: () => _deletePhoto(doc),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatefulWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PhotoTile({required this.url, required this.onTap, required this.onDelete});

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(
              widget.url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
            if (_hovering)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

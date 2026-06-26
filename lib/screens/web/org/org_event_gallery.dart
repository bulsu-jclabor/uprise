// lib/screens/web/org/org_event_gallery.dart
//
// Event Gallery panel — lets an org upload photos for a chosen event.
// Embedded inside org_profile.dart (with an event picker wrapper, see
// EventGallerySection below) rather than as its own dashboard tab or
// per-event attendance sub-tab.
//
// Photos are stored as base64 data URLs directly on the Firestore doc in
// events/{eventId}/photos — no Firebase Storage — mirroring the pattern
// already used for org logos/cover photos in org_profile.dart, so there's
// no Storage billing involved.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class _DS {
  static const double radiusMd = 12;
}

String _mimeTypeFromBytes(List<int> bytes) {
  if (bytes.length < 4) return 'image/png';
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'image/bmp';
  if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'image/webp';
  return 'image/png';
}

ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
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

  // Firestore caps a document at 1MB; base64 inflates raw bytes by ~33%,
  // so anything much over ~700KB risks failing the write outright.
  static const int _maxBytes = 700 * 1024;

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
    int tooLarge = 0;

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        failed++;
        continue;
      }
      if (bytes.length > _maxBytes) {
        tooLarge++;
        continue;
      }
      try {
        final mime = _mimeTypeFromBytes(bytes);
        final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('photos')
            .add({
          'url': dataUrl,
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
      final parts = <String>[];
      if (succeeded > 0) parts.add('Uploaded $succeeded photo${succeeded == 1 ? '' : 's'}.');
      if (tooLarge > 0) parts.add('$tooLarge photo${tooLarge == 1 ? '' : 's'} too large (max ~700KB).');
      if (failed > 0) parts.add('$failed failed.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(parts.isEmpty ? 'No photos uploaded.' : parts.join(' ')),
        backgroundColor: (failed == 0 && tooLarge == 0) ? UpriseColors.success : UpriseColors.warning,
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
              child: Image(image: _imageProviderFromUrl(url), fit: BoxFit.contain),
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
            Image(
              image: _imageProviderFromUrl(widget.url),
              fit: BoxFit.cover,
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

// ─────────────────────────────────────────────────────────────────────────────
// EventGallerySection — the event-picker + panel combo embedded directly
// into org_profile.dart. The gallery is per-event, but Profile is org-wide,
// so this picks which of the org's events to manage before showing the
// panel above.
// ─────────────────────────────────────────────────────────────────────────────
class EventGallerySection extends StatefulWidget {
  final String orgId;
  const EventGallerySection({super.key, required this.orgId});

  @override
  State<EventGallerySection> createState() => _EventGallerySectionState();
}

class _EventGallerySectionState extends State<EventGallerySection> {
  String? _selectedEventId;
  String _selectedEventTitle = '';

  late final Stream<QuerySnapshot> _eventsStream = FirebaseFirestore.instance
      .collection('events')
      .where('orgId', isEqualTo: widget.orgId)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark)),
          );
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map)['date'];
            final tb = (b.data() as Map)['date'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E6EA)),
            ),
            child: Center(
              child: Text('No events yet. Create one to start a gallery.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
            ),
          );
        }

        if (_selectedEventId == null || !docs.any((d) => d.id == _selectedEventId)) {
          _selectedEventId = docs.first.id;
          _selectedEventTitle = ((docs.first.data() as Map)['title'] ?? 'Untitled Event').toString();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(_DS.radiusMd),
                border: Border.all(color: const Color(0xFFE2E6EA)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedEventId,
                  icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF64748B)),
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                  items: docs.map((d) {
                    final title = ((d.data() as Map)['title'] ?? 'Untitled Event').toString();
                    return DropdownMenuItem(value: d.id, child: Text(title, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final doc = docs.firstWhere((d) => d.id == id);
                    setState(() {
                      _selectedEventId = id;
                      _selectedEventTitle = ((doc.data() as Map)['title'] ?? 'Untitled Event').toString();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            EventGalleryPanel(
              key: ValueKey(_selectedEventId),
              orgId: widget.orgId,
              eventId: _selectedEventId!,
              eventTitle: _selectedEventTitle,
            ),
          ],
        );
      },
    );
  }
}

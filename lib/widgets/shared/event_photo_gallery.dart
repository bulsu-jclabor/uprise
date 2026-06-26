// lib/widgets/shared/event_photo_gallery.dart
//
// Read-only photo grid for events/{eventId}/photos, used by both the
// student and guest event detail screens. Renders nothing (not even an
// empty-state) when there are no photos yet, so it stays invisible on
// events the org hasn't uploaded anything for.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}

class EventPhotoGallery extends StatelessWidget {
  final String eventId;
  final Color accentColor;

  const EventPhotoGallery({
    super.key,
    required this.eventId,
    this.accentColor = Colors.orange,
  });

  void _viewFullscreen(BuildContext context, List<String> urls, int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: _FullscreenGallery(urls: urls, initialIndex: startIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (eventId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('photos')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final urls = docs
            .map((d) => (d.data() as Map<String, dynamic>)['url'] as String? ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
        if (urls.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.photo_library_outlined, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text('Event Photos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(width: 6),
              Text('(${urls.length})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: urls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _viewFullscreen(context, urls, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(
                      image: _imageProviderFromUrl(urls[i]),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullscreenGallery({required this.urls, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => Center(
          child: InteractiveViewer(
            child: Image(image: _imageProviderFromUrl(widget.urls[i]), fit: BoxFit.contain),
          ),
        ),
      ),
      Positioned(
        top: 16,
        right: 16,
        child: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      Positioned(
        bottom: 24,
        left: 0,
        right: 0,
        child: Center(
          child: Text('${_index + 1} / ${widget.urls.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ),
    ]);
  }
}

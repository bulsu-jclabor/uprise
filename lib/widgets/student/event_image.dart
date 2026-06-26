// lib/widgets/student/event_image.dart
//
// Shared event banner image widget (base64 + network), used by
// student_events_screen.dart and student_event_details_screen.dart.
// Network failures are disambiguated against actual device connectivity
// so "no internet" and "broken/missing image" show distinct, accurate
// states instead of one generic placeholder, with a working retry.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_colors.dart';

class EventImage extends StatefulWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool showLoadingIndicator;

  const EventImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.showLoadingIndicator = true,
  });

  @override
  State<EventImage> createState() => _EventImageState();
}

class _EventImageState extends State<EventImage> {
  int _retryToken = 0;
  bool _offline = false;

  int? get _cacheWidth => widget.width != null ? (widget.width! * 2).round() : null;
  int? get _cacheHeight => widget.height != null ? (widget.height! * 2).round() : null;

  bool _isBase64Image(String url) =>
      url.startsWith('data:image') ||
      (url.isNotEmpty && !url.startsWith('http') && !url.startsWith('assets'));

  bool _isValidImageUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://') || url.startsWith('assets/');

  Future<void> _checkOffline() async {
    final result = await Connectivity().checkConnectivity();
    final offline = result.isEmpty || result.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  Future<void> _retry() async {
    NetworkImage(widget.imageUrl).evict();
    await _checkOffline();
    if (mounted) setState(() => _retryToken++);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) return _buildFallback();
    if (_isBase64Image(widget.imageUrl)) return _buildBase64Image();
    if (_isValidImageUrl(widget.imageUrl)) return _buildNetworkImage();
    return _buildFallback();
  }

  Widget _buildBase64Image() {
    try {
      String base64String = widget.imageUrl;
      if (base64String.contains(',')) base64String = base64String.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        cacheWidth: _cacheWidth,
        cacheHeight: _cacheHeight,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } catch (_) {
      return _buildFallback();
    }
  }

  Widget _buildNetworkImage() {
    return Image.network(
      widget.imageUrl,
      key: ValueKey('${widget.imageUrl}_$_retryToken'),
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      cacheWidth: _cacheWidth,
      cacheHeight: _cacheHeight,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        if (!widget.showLoadingIndicator) return child;
        return Container(
          height: widget.height,
          width: widget.width,
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        _checkOffline();
        return _buildFallback(isNetworkError: true);
      },
    );
  }

  Widget _buildFallback({bool isNetworkError = false}) {
    final h = widget.height ?? 100;
    final showOffline = isNetworkError && _offline;
    return Container(
      height: widget.height,
      width: widget.width,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showOffline ? Icons.wifi_off_rounded : Icons.image_not_supported,
            size: h * 0.35,
            color: Colors.grey[600],
          ),
          if (h > 80) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
              child: Text(
                showOffline ? 'No internet connection' : 'Image not available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: h * 0.075, color: Colors.grey[600]),
              ),
            ),
            if (isNetworkError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: _retry,
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: h * 0.08,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

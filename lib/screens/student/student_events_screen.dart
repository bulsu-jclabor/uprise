// lib/screens/student/student_events_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────
//  CUSTOM COLORS
// ─────────────────────────────────────────────
class AppColors {
  static const Color primaryDark  = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent       = Color(0xFFFF9800);
  static const Color background   = Color(0xFFF5F5F5);
}

// ─────────────────────────────────────────────
//  EVENT IMAGE WIDGET (WITH BASE64 SUPPORT)
// ─────────────────────────────────────────────
class EventImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  const EventImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _noImage();
    }

    // Check if it's a base64 image
    if (_isBase64Image(imageUrl)) {
      return _buildBase64Image();
    }

    // Check if it's a valid network URL
    if (_isValidImageUrl(imageUrl)) {
      return _buildNetworkImage();
    }

    return _noImage();
  }

  bool _isBase64Image(String url) {
    return url.startsWith('data:image') || 
           (url.isNotEmpty && !url.startsWith('http') && !url.startsWith('assets'));
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    if (url == 'www' || url == 'https://www' || url == 'http://www') return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Widget _buildBase64Image() {
    try {
      String base64String = imageUrl;
      if (imageUrl.contains(',')) {
        base64String = imageUrl.split(',').last;
      }
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _noImage(),
      );
    } catch (_) {
      return _noImage();
    }
  }

  Widget _buildNetworkImage() {
    return Image.network(
      imageUrl,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 30, height: 30,
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: Colors.orange,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _noImage(),
    );
  }

  Widget _noImage() => Container(
    height: height, width: width,
    color: Colors.grey[300],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported, size: (height ?? 100) * 0.3, color: Colors.grey[600]),
        if ((height ?? 0) > 60)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('No Image', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  EVENT DATA MODEL
// ─────────────────────────────────────────────
class EventData {
  final String id;
  final String proposalId;
  final String title;
  final String subtitle;
  final String organizer;
  final String organizerSub;
  final String logoUrl;
  final String bannerUrl;
  final String date;
  final String time;
  final String location;
  final String description;
  final String category;
  final bool isRegistered;
  final int slots;
  final int slotsLeft;
  final bool isPublic;
  final bool isPast;
  final DateTime rawDate;

  const EventData({
    required this.id,
    this.proposalId = '',
    required this.title,
    required this.subtitle,
    required this.organizer,
    required this.organizerSub,
    required this.logoUrl,
    required this.bannerUrl,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    required this.category,
    this.isRegistered = false,
    required this.slots,
    required this.slotsLeft,
    this.isPublic = true,
    required this.isPast,
    required this.rawDate,
  });

  factory EventData.fromFirestore(DocumentSnapshot doc, {bool isRegistered = false}) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = d['date'];
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now();
    final capacity  = d['capacity']  as int? ?? 0;
    final slotsLeft = d['slotsLeft'] as int? ?? capacity;
    return EventData(
      id:           doc.id,
      proposalId:   d['createdFromProposalId'] ?? '',
      title:        d['title']       ?? '',
      subtitle:     d['subtitle']    ?? '',
      organizer:    d['orgName']     ?? '',
      organizerSub: 'ORGANIZATION',
      logoUrl: (d['logoUrl'] ?? '').toString(),
      bannerUrl: (d['bannerUrl'] ?? '').toString(),
      date:         DateFormat('MMM dd, yyyy').format(dateTime),
      time:         '${d['startTime'] ?? ''} – ${d['endTime'] ?? ''}',
      location:     d['location']    ?? '',
      description:  d['description'] ?? '',
      category:     d['category']    ?? 'Other',
      isRegistered: isRegistered,
      slots:        capacity,
      slotsLeft:    slotsLeft,
      isPublic:     d['isPublic']    ?? true,
      isPast:       dateTime.isBefore(DateTime.now()),
      rawDate:      dateTime,
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class StudentEventsScreen extends StatefulWidget {
  final int initialTabIndex;

  const StudentEventsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  // ── Certificate tab state ──
  String _certFilter            = 'All';
  List<String> _certFilters     = ['All', 'Others'];
  List<Map<String, dynamic>> _allCertificates = [];
  bool _certLoading             = true;
  bool _orgFiltersLoading       = true;
  String? _certError;
  final Set<String> _feedbackGiven = {};
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.index == 2 && _certLoading) _fetchCertificates();
    });
    _fetchCertificates();
    _fetchOrganizationFilters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  //  CERTIFICATE HELPERS
  // ══════════════════════════════════════════════
  Future<void> _fetchCertificates() async {
    setState(() { _certLoading = true; _certError = null; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('certificates').get();
      var docs = snapshot.docs;
      if (_currentUid != null) {
        docs = docs.where((d) {
          final r = d.data()['recipientUid'];
          return r == null || r == _currentUid;
        }).toList();
      }
      docs.sort((a, b) {
        final aTs = a.data()['issuedAt'];
        final bTs = b.data()['issuedAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return (bTs as Timestamp).compareTo(aTs as Timestamp);
      });
      setState(() {
        _allCertificates = docs.map(_docToMap).toList();
        _certLoading = false;
      });
    } catch (e) {
      setState(() { _certError = e.toString(); _certLoading = false; });
    }
  }

  Future<void> _fetchOrganizationFilters() async {
    setState(() => _orgFiltersLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('organizations')
          .where('status', isEqualTo: 'active')
          .get();
      final names = snap.docs
          .map((d) => (d.data()['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      names.sort();
      setState(() {
        _certFilters = ['All', ...names, 'Others'];
        _orgFiltersLoading = false;
      });
    } catch (_) {
      setState(() {
        _certFilters = ['All', 'Others'];
        _orgFiltersLoading = false;
      });
    }
  }

  Map<String, dynamic> _docToMap(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return {
      'id'              : doc.id,
      'title'           : d['eventName']      ?? 'Untitled Certificate',
      'date'            : _formatCertDate(d['issuedAt']),
      'category'        : d['type']           ?? d['templateType'] ?? 'General',
      'organization'    : d['organization']   ?? '',
      'signatories'     : d['signatories']    ?? '',
      'status'          : d['status']         ?? 'draft',
      'recipients'      : d['recipients']     ?? 0,
      'templateType'    : d['templateType']   ?? '',
      'imageUrl'        : d['imageUrl']       ?? '',
      'isUploaded'      : d['isUploaded']     ?? false,
      'verificationCode': d['verificationCode'] ?? '',
      'autoGenerated'   : d['autoGenerated']  ?? false,
    };
  }

  String _formatCertDate(dynamic ts) {
    if (ts == null) return 'Just now';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = ['January','February','March','April','May','June',
                 'July','August','September','October','November','December'];
      return '${m[dt.month - 1]} ${dt.day.toString().padLeft(2,'0')}, ${dt.year}';
    }
    return ts.toString();
  }

  bool _isBase64Image(String url) =>
      url.startsWith('data:image') || (!url.startsWith('http') && url.isNotEmpty);

  Widget _buildCertImage(String imageUrl, {double height = 180}) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    if (_isBase64Image(imageUrl)) {
      try {
        final b64 = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, height: height, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return Image.network(imageUrl, height: height, width: double.infinity, fit: BoxFit.cover,
        loadingBuilder: (ctx, child, p) {
          if (p == null) return child;
          return Container(height: height, color: Colors.orange.shade50,
              child: const Center(child: CircularProgressIndicator(color: Colors.orange)));
        },
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  // ── Upload dialog ──
  Future<void> _showUploadDialog() async {
    final eventNameCtrl = TextEditingController();

    final orgOptions = _certFilters.where((f) => f != 'All').toList();
    String selectedType = orgOptions.isNotEmpty ? orgOptions.first : '';
    File? pickedFile;
    bool isUploading = false;

    InputDecoration fd(String label, {String? hint}) => InputDecoration(
      labelText: label, hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickImage(ImageSource src) async {
            final picked = await ImagePicker()
                .pickImage(source: src, imageQuality: 60, maxWidth: 800);
            if (picked != null) setSheet(() => pickedFile = File(picked.path));
          }

          Future<void> doUpload() async {
            if (pickedFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select a certificate image.'),
                backgroundColor: Colors.orange));
              return;
            }
            if (eventNameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Certificate name is required.'),
                backgroundColor: Colors.orange));
              return;
            }
            if (selectedType.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select an organization.'),
                backgroundColor: Colors.orange));
              return;
            }
            setSheet(() => isUploading = true);
            try {
              final bytes  = await pickedFile!.readAsBytes();
              final b64Img = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (b64Img.length > 900000) {
                setSheet(() => isUploading = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Image is too large. Please pick a smaller image.'),
                  backgroundColor: Colors.red, duration: Duration(seconds: 4)));
                return;
              }
              final docRef = await FirebaseFirestore.instance.collection('certificates').add({
                'eventName'    : eventNameCtrl.text.trim(),
                'type'         : selectedType,
                'organization' : selectedType,
                'imageUrl'     : b64Img,
                'issuedAt'     : FieldValue.serverTimestamp(),
                'recipientUid' : _currentUid,
                'isUploaded'   : true,
                'status'       : 'issued',
              });
              final now = DateTime.now();
              const months = ['January','February','March','April','May','June',
                              'July','August','September','October','November','December'];
              final newCert = {
                'id'          : docRef.id,
                'title'       : eventNameCtrl.text.trim(),
                'date'        : '${months[now.month-1]} ${now.day.toString().padLeft(2,'0')}, ${now.year}',
                'category'    : selectedType,
                'organization': selectedType,
                'signatories' : '',
                'status'      : 'issued',
                'recipients'  : 1,
                'templateType': '',
                'imageUrl'    : b64Img,
                'isUploaded'  : true,
                'verificationCode': '',
              };
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() { _allCertificates.insert(0, newCert); _certFilter = 'All'; });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Certificate uploaded successfully!'),
                  backgroundColor: Colors.green));
                _fetchCertificates();
              }
            } catch (e) {
              setSheet(() => isUploading = false);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red, duration: const Duration(seconds: 6)));
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const Text('Upload Certificate',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Add the image, name, and type of your certificate.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: ctx,
                      builder: (c) => SafeArea(child: Wrap(children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library_rounded),
                          title: const Text('Choose from Gallery'),
                          onTap: () { Navigator.pop(c); pickImage(ImageSource.gallery); },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_rounded),
                          title: const Text('Take a Photo'),
                          onTap: () { Navigator.pop(c); pickImage(ImageSource.camera); },
                        ),
                      ])),
                    ),
                    child: Container(
                      height: 160, width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.shade200, width: 1.5),
                      ),
                      child: pickedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Stack(fit: StackFit.expand, children: [
                                Image.file(pickedFile!, fit: BoxFit.cover),
                                Positioned(bottom: 8, right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Tap to change',
                                        style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                              ]),
                            )
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.cloud_upload_rounded, size: 44, color: Colors.orange.shade400),
                              const SizedBox(height: 8),
                              Text('Tap to upload image',
                                  style: TextStyle(color: Colors.orange.shade400, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('Keep image under 700KB for best results',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _certSectionLabel('Certificate Details'),
                  const SizedBox(height: 12),
                  TextField(controller: eventNameCtrl, decoration: fd('Certificate Name *', hint: 'e.g. Codecraft')),
                  const SizedBox(height: 12),
                  orgOptions.isNotEmpty
                      ? DropdownButtonFormField<String>(
                          value: selectedType, decoration: fd('Organization *'),
                          items: orgOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                          onChanged: (v) { if (v != null) setSheet(() => selectedType = v); },
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Expanded(child: Text('No organizations available yet.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                          ]),
                        ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: isUploading ? null : doUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        disabledBackgroundColor: Colors.orange.shade200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isUploading
                          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                              SizedBox(width: 12),
                              Text('Uploading...', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                            ])
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Upload Certificate',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Feedback dialog ──
  Future<void> _showFeedbackDialog(Map<String, dynamic> cert) async {
    int selectedRating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            if (selectedRating == 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select a star rating.'), backgroundColor: Colors.orange));
              return;
            }
            setSheet(() => submitting = true);
            try {
              await FirebaseFirestore.instance.collection('event_feedback').add({
                'certId'      : cert['id'],
                'eventName'   : cert['title'],
                'organization': cert['organization'],
                'rating'      : selectedRating,
                'comment'     : commentCtrl.text.trim(),
                'userId'      : _currentUid,
                'submittedAt' : FieldValue.serverTimestamp(),
              });
              if (mounted) setState(() => _feedbackGiven.add(cert['id'] as String));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Feedback submitted. Thank you!'), backgroundColor: Colors.green));
            } catch (e) {
              setSheet(() => submitting = false);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Failed to submit: $e'), backgroundColor: Colors.red));
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const Text('Rate This Event',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(cert['title'], style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: () => setSheet(() => selectedRating = star),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 40,
                              color: star <= selectedRating ? Colors.orange : Colors.grey.shade300,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: commentCtrl, maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience (optional)...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: submitting
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Submit Feedback',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Verification QR dialog ──
  void _showVerifyDialog(Map<String, dynamic> cert) {
    final code = cert['verificationCode'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            )),
            const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 36),
            const SizedBox(height: 10),
            const Text('Certificate Verification',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(cert['title'],
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Center(child: QrImageView(data: code, version: QrVersions.auto, size: 180, backgroundColor: Colors.white)),
            const SizedBox(height: 16),
            Text('Verification Code',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Code copied to clipboard'),
                  backgroundColor: Colors.green, duration: Duration(seconds: 2)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(code, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'monospace',
                      letterSpacing: 2, color: Color(0xFFB45309))),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFB45309)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Share this QR or code to verify authenticity.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Certificate card ──
  Widget _buildCertificateCard(Map<String, dynamic> cert) {
    final isDraft    = cert['status']     == 'draft';
    final isUploaded = cert['isUploaded'] == true;
    final imageUrl   = cert['imageUrl']   as String;
    final vCode      = cert['verificationCode'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? _buildCertImage(imageUrl)
                : _certPlaceholderBanner(isDraft, isUploaded, cert),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cert['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(cert['category'],
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 4),
                      Text(cert['date'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      if (isUploaded) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('Uploaded by you',
                              style: TextStyle(color: Colors.blue.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${cert['title']} downloaded'), backgroundColor: Colors.orange)),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          if (cert['status'] != 'draft') ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _feedbackGiven.contains(cert['id'])
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, size: 15, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Text('Feedback submitted',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
                    ])
                  : GestureDetector(
                      onTap: () => _showFeedbackDialog(cert),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_outline, size: 16, color: Colors.orange.shade600),
                        const SizedBox(width: 6),
                        Text('Rate this event',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade600, fontWeight: FontWeight.w600)),
                      ]),
                    ),
            ),
          ],
          if (vCode.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            GestureDetector(
              onTap: () => _showVerifyDialog(cert),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  QrImageView(data: vCode, version: QrVersions.auto, size: 44, backgroundColor: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Verify Certificate',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                    const SizedBox(height: 2),
                    Text('Code: $vCode',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace',
                            letterSpacing: 1.1, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                  ])),
                  Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey.shade400),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _certPlaceholderBanner(bool isDraft, bool isUploaded, Map<String, dynamic> cert) {
    return Container(
      height: 180, width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUploaded
              ? [Colors.blue.shade200, Colors.blue.shade500]
              : [Colors.orange.shade200, Colors.orange.shade500],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(isUploaded ? Icons.upload_file_rounded : Icons.workspace_premium, size: 70, color: Colors.white24),
        if (isDraft)
          Positioned(top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
              child: const Text('DRAFT',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),
        if ((cert['organization'] as String).isNotEmpty)
          Positioned(bottom: 10, left: 14,
            child: Text(cert['organization'],
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
      ]),
    );
  }

  Widget _certSectionLabel(String label) => Text(label,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Colors.orange.shade700, letterSpacing: 0.4));

  // ══════════════════════════════════════════════
  //  CALENDAR / EVENT HELPERS
  // ══════════════════════════════════════════════
  void _previousMonth() =>
      setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1));

  void _nextMonth() =>
      setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1));

  void _openDetail(EventData event) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        event: event, onRegistered: () => setState(() {}), isPastEvent: event.isPast),
    ));
  }

  Future<Set<String>> _getRegisteredEventIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await FirebaseFirestore.instance
        .collection('registrations').where('userId', isEqualTo: user.uid).get();
    return snap.docs.map((d) => d['eventId'] as String).toSet();
  }

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Events',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.black45,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Certificate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildUpcomingTab(),
          _buildCertificateTab(),
        ],
      ),
    );
  }

  // ── TAB 0: Calendar ──
  Widget _buildCalendarTab() {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: Colors.orange), onPressed: _previousMonth),
            Text(DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.chevron_right, color: Colors.orange), onPressed: _nextMonth),
          ],
        ),
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _CalendarGrid(
          selectedDate: _selectedDate,
          onDateSelected: (date) => setState(() => _selectedDate = date),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('Events for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
          const Spacer(),
          FutureBuilder<Set<String>>(
            future: _getRegisteredEventIds(),
            builder: (context, regSnap) {
              final regIds = regSnap.data ?? {};
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final count = snap.data!.docs
                      .map((d) => EventData.fromFirestore(d, isRegistered: regIds.contains(d.id)))
                      .where((e) => e.rawDate.year == _selectedDate.year &&
                          e.rawDate.month == _selectedDate.month &&
                          e.rawDate.day == _selectedDate.day)
                      .length;
                  return Text('$count events',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade600));
                },
              );
            },
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<Set<String>>(
          future: _getRegisteredEventIds(),
          builder: (context, regSnap) {
            final regIds = regSnap.data ?? {};
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                final todayEvents = snap.data!.docs
                    .map((d) => EventData.fromFirestore(d, isRegistered: regIds.contains(d.id)))
                    .where((e) => e.rawDate.year == _selectedDate.year &&
                        e.rawDate.month == _selectedDate.month &&
                        e.rawDate.day == _selectedDate.day)
                    .toList();
                if (todayEvents.isEmpty) {
                  return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No events for this day',
                        style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ]));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: todayEvents.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CompactEventCard(event: todayEvents[i], onTap: () => _openDetail(todayEvents[i])),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  // ── TAB 1: Upcoming Events ──
  Widget _buildUpcomingTab() {
    return FutureBuilder<Set<String>>(
      future: _getRegisteredEventIds(),
      builder: (context, regSnap) {
        final regIds = regSnap.data ?? {};
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator(color: Colors.orange));
            final events = snap.data!.docs
                .map((d) => EventData.fromFirestore(d, isRegistered: regIds.contains(d.id)))
                .where((e) => !e.isPast)
                .toList();
            if (events.isEmpty) {
              return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.event_available, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('No upcoming events',
                    style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500)),
              ]));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _UpcomingEventCard(event: events[i], onTap: () => _openDetail(events[i])),
              ),
            );
          },
        );
      },
    );
  }

  // ── TAB 2: Certificate ──
  Widget _buildCertificateTab() {
    final filtered = _certFilter == 'All'
        ? _allCertificates
        : _allCertificates.where((c) => c['organization'] == _certFilter).toList();

    return Stack(children: [
      Column(children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _certFilters.length,
            itemBuilder: (_, i) {
              final f = _certFilters[i];
              final sel = _certFilter == f;
              return GestureDetector(
                onTap: () => setState(() => _certFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: sel ? Colors.orange : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.orange : Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: Text(f,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.grey.shade600,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Content
        Expanded(
          child: _certLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : _certError != null
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Failed to load certificates',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(_certError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchCertificates,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ]))
                  : filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.workspace_premium_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No certificates found',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ]))
                      : RefreshIndicator(
                          color: Colors.orange,
                          onRefresh: _fetchCertificates,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _buildCertificateCard(filtered[i]),
                          ),
                        ),
        ),
      ]),

      // Upload FAB — icon only, circular
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton(
          heroTag: 'cert_upload_fab',
          shape: const CircleBorder(),
          onPressed: _showUploadDialog,
          backgroundColor: Colors.orange,
          child: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
//  CALENDAR GRID
// ─────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _CalendarGrid({required this.selectedDate, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    final first      = DateTime(selectedDate.year, selectedDate.month, 1);
    final firstWday  = first.weekday % 7;
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;

    final widgets = <Widget>[];
    for (final d in ['S','M','T','W','T','F','S']) {
      widgets.add(Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600))));
    }
    for (int i = 0; i < firstWday; i++) widgets.add(const SizedBox.shrink());
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(selectedDate.year, selectedDate.month, day);
      final isSel  = date.year == selectedDate.year && date.month == selectedDate.month && date.day == selectedDate.day;
      final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
      widgets.add(GestureDetector(
        onTap: () => onDateSelected(date),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSel ? Colors.orange : isToday ? Colors.grey.shade200 : Colors.transparent,
          ),
          child: Center(child: Text(day.toString(), style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: isSel ? Colors.white : isToday ? Colors.orange : Colors.black87,
          ))),
        ),
      ));
    }
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7, childAspectRatio: 1.2, children: widgets,
    );
  }
}

// ─────────────────────────────────────────────
//  COMPACT EVENT CARD
// ─────────────────────────────────────────────
class _CompactEventCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;
  const _CompactEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 70, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            ),
            child: Column(children: [
              Text(DateFormat('MMM').format(event.rawDate),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange)),
              Text(DateFormat('dd').format(event.rawDate),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.orange)),
            ]),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time, size: 12, color: Colors.grey), const SizedBox(width: 4),
                Text(event.time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey), const SizedBox(width: 4),
                Expanded(child: Text(event.location,
                    style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  UPCOMING EVENT CARD (WITH IMAGE SUPPORT)
// ─────────────────────────────────────────────
class _UpcomingEventCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;
  const _UpcomingEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Event Image ──
          EventImage(
            imageUrl: event.bannerUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _CategoryBadge(category: event.category),
                const Spacer(),
                if (event.isRegistered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green), SizedBox(width: 4),
                      Text('Registered', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(event.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey), const SizedBox(width: 4),
                Text(event.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 12, color: Colors.grey), const SizedBox(width: 4),
                Expanded(child: Text(event.time,
                    style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey), const SizedBox(width: 4),
                Expanded(child: Text(event.location,
                    style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: event.isRegistered ? Colors.green : Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text(event.isRegistered ? 'Registered ✓' : 'View Details',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CATEGORY BADGE
// ─────────────────────────────────────────────
class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  Color get _color {
    switch (category.toLowerCase()) {
      case 'competition': return Colors.orange;
      case 'workshop':    return const Color(0xFF1565C0);
      case 'seminar':     return const Color(0xFF6A1B9A);
      default:            return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(4)),
      child: Text(category.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

// ─────────────────────────────────────────────
//  EVENT DETAIL SCREEN
// ─────────────────────────────────────────────
class EventDetailScreen extends StatefulWidget {
  final EventData event;
  final VoidCallback onRegistered;
  final bool isPastEvent;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.onRegistered,
    required this.isPastEvent,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = false;
  bool _loadingForm = true;
  Map<String, dynamic>? _formDef;
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, String?> _singleChoice = {};
  final Map<String, Set<String>> _multiChoice = {};

  @override
  void initState() {
    super.initState();
    _loadRegistrationForm();
  }

  @override
  void dispose() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // The org's Registration Form Builder writes to `registration_forms/{proposalId}`.
  // Look it up via the event's source proposal so students see the org's actual form.
  Future<void> _loadRegistrationForm() async {
    if (widget.event.proposalId.isEmpty) {
      if (mounted) setState(() => _loadingForm = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('registration_forms')
          .doc(widget.event.proposalId)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        final fields = (d['fields'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (d['isPublished'] == true && fields.isNotEmpty) {
          for (final f in fields) {
            final id = f['id'] as String;
            final type = (f['type'] ?? 'short_text') as String;
            if (type == 'multiple_choice' || type == 'dropdown') {
              _singleChoice[id] = null;
            } else if (type == 'checkboxes') {
              _multiChoice[id] = {};
            } else {
              _fieldControllers[id] = TextEditingController();
            }
          }
          _formDef = {...d, 'fields': fields};
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingForm = false);
  }

  String? _validateDynamicFields() {
    if (_formDef == null) return null;
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    for (final f in fields) {
      if (f['required'] != true) continue;
      final id = f['id'] as String;
      final type = (f['type'] ?? 'short_text') as String;
      final label = (f['label'] ?? 'This question').toString();
      if (type == 'multiple_choice' || type == 'dropdown') {
        if (_singleChoice[id] == null) return 'Please answer: $label';
      } else if (type == 'checkboxes') {
        if ((_multiChoice[id] ?? {}).isEmpty) return 'Please answer: $label';
      } else {
        if ((_fieldControllers[id]?.text ?? '').trim().isEmpty) return 'Please answer: $label';
      }
    }
    return null;
  }

  Map<String, dynamic> _collectFormResponses() {
    if (_formDef == null) return {};
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    final out = <String, dynamic>{};
    for (final f in fields) {
      final id = f['id'] as String;
      final type = (f['type'] ?? 'short_text') as String;
      final label = f['label'] ?? '';
      if (type == 'multiple_choice' || type == 'dropdown') {
        out[id] = {'label': label, 'value': _singleChoice[id]};
      } else if (type == 'checkboxes') {
        out[id] = {'label': label, 'value': (_multiChoice[id] ?? {}).toList()};
      } else {
        out[id] = {'label': label, 'value': _fieldControllers[id]?.text.trim() ?? ''};
      }
    }
    return out;
  }

  Future<void> _registerForEvent() async {
    if (widget.isPastEvent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot register for past events'), backgroundColor: Colors.red));
      return;
    }
    if (widget.event.slotsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Event is full! No slots available.'), backgroundColor: Colors.red));
      return;
    }
    final formError = _validateDynamicFields();
    if (formError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(formError), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to register')));
      setState(() => _isLoading = false);
      return;
    }
    try {
      final formResponses = _collectFormResponses();
      final regRef = FirebaseFirestore.instance
          .collection('registrations').doc('${user.uid}_${widget.event.id}');
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final regDoc = await tx.get(regRef);
        if (regDoc.exists) throw Exception('You are already registered for this event');
        final evRef  = FirebaseFirestore.instance.collection('events').doc(widget.event.id);
        final evDoc  = await tx.get(evRef);
        if (!evDoc.exists) throw Exception('Event not found');
        final slots  = evDoc.data()!['slotsLeft'] as int? ?? 0;
        if (slots <= 0) throw Exception('No slots available for this event');
        tx.update(evRef, {'slotsLeft': slots - 1});
        tx.set(regRef, {
          'userId': user.uid, 'eventId': widget.event.id,
          'registeredAt': FieldValue.serverTimestamp(), 'status': 'registered',
          if (formResponses.isNotEmpty) 'formResponses': formResponses,
        });
      });
      widget.onRegistered();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Successfully registered for event!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primaryDark, width: 1.5)),
  );

  Widget _buildDynamicField(Map<String, dynamic> field) {
    final id = field['id'] as String;
    final type = (field['type'] ?? 'short_text') as String;
    final label = (field['label'] ?? '').toString();
    final desc = (field['description'] ?? '').toString();
    final required = field['required'] == true;
    final options = (field['options'] as List?)?.map((o) => o.toString()).toList() ?? [];

    Widget input;
    switch (type) {
      case 'paragraph':
        input = TextField(controller: _fieldControllers[id], maxLines: 4, decoration: _fieldDecoration('Your answer'));
        break;
      case 'email':
        input = TextField(controller: _fieldControllers[id], keyboardType: TextInputType.emailAddress, decoration: _fieldDecoration('someone@email.com'));
        break;
      case 'number':
        input = TextField(controller: _fieldControllers[id], keyboardType: TextInputType.number, decoration: _fieldDecoration('0'));
        break;
      case 'date':
        input = TextField(
          controller: _fieldControllers[id],
          readOnly: true,
          decoration: _fieldDecoration('Select date').copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context, initialDate: DateTime.now(),
              firstDate: DateTime(2020), lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => _fieldControllers[id]!.text = DateFormat('MMM dd, yyyy').format(picked));
            }
          },
        );
        break;
      case 'multiple_choice':
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options.map((o) => RadioListTile<String>(
            value: o, groupValue: _singleChoice[id],
            title: Text(o, style: const TextStyle(fontSize: 13)),
            dense: true, contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _singleChoice[id] = v),
          )).toList(),
        );
        break;
      case 'dropdown':
        input = DropdownButtonFormField<String>(
          initialValue: _singleChoice[id],
          decoration: _fieldDecoration('Select an option'),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _singleChoice[id] = v),
        );
        break;
      case 'checkboxes':
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options.map((o) => CheckboxListTile(
            value: _multiChoice[id]?.contains(o) ?? false,
            title: Text(o, style: const TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true, contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() {
              _multiChoice.putIfAbsent(id, () => {});
              if (v == true) {
                _multiChoice[id]!.add(o);
              } else {
                _multiChoice[id]!.remove(o);
              }
            }),
          )).toList(),
        );
        break;
      default:
        input = TextField(controller: _fieldControllers[id], decoration: _fieldDecoration('Your answer'));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(children: [
          TextSpan(text: label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        ])),
        if (desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          )
        else
          const SizedBox(height: 6),
        input,
      ]),
    );
  }

  Widget _buildRegistrationFormSection() {
    if (_formDef == null) return const SizedBox.shrink();
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    final title = (_formDef!['title'] ?? 'Registration Form').toString();
    final desc = (_formDef!['description'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
        const SizedBox(height: 14),
        ...fields.map(_buildDynamicField),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Event Details', style: TextStyle(color: Colors.black87)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EventImage(imageUrl: widget.event.bannerUrl, height: 220, width: double.infinity, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CategoryBadge(category: widget.event.category),
              const SizedBox(height: 12),
              Text(widget.event.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(widget.event.subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 20),
              _InfoRow(icon: Icons.calendar_today_outlined, text: widget.event.date),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.access_time, text: widget.event.time),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.location_on_outlined, text: widget.event.location),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.people_outline,
                  text: '${widget.event.slotsLeft} / ${widget.event.slots} slots remaining'),
              const SizedBox(height: 20),
              const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(widget.event.description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
              const SizedBox(height: 30),
              if (!widget.isPastEvent && !widget.event.isRegistered && _loadingForm)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              if (!widget.isPastEvent && !widget.event.isRegistered && !_loadingForm)
                _buildRegistrationFormSection(),
              if (!widget.isPastEvent && !widget.event.isRegistered)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || _loadingForm ? null : _registerForEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.event.slotsLeft > 0 ? Colors.orange : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            widget.event.slotsLeft > 0
                                ? 'Register Now (${widget.event.slotsLeft} slots left)'
                                : 'Event Full',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              if (widget.event.isRegistered && !widget.isPastEvent)
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                  child: const Center(child: Text('✓ You are registered',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green))),
                ),
              if (widget.isPastEvent)
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Past Event',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey))),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.grey.shade600), const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87))),
    ]);
  }
}
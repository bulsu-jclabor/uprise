import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/certificate_preview.dart';
import '../../widgets/student/app_colors.dart';
import 'dart:math' as math;  // ← For math.max
import 'package:google_fonts/google_fonts.dart';  // ← For GoogleFonts

// ─────────────────────────────────────────────────────────────────────────────
// COPY THESE FROM OrgCertificatesScreen
// ─────────────────────────────────────────────────────────────────────────────

class SignatoryData {
  final String id;
  final String placeholderKey;
  final String fullName;
  final String title;
  final String? signatureBase64;

  const SignatoryData({
    required this.id,
    required this.placeholderKey,
    required this.fullName,
    required this.title,
    this.signatureBase64,
  });

  factory SignatoryData.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return SignatoryData(
      id: doc.id,
      placeholderKey: (d['placeholderKey'] ?? '').toString(),
      fullName: (d['fullName'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      signatureBase64: d['signatureBase64'] as String?,
    );
  }
}

class _CertificateComposite extends StatelessWidget {
  final ImageProvider background;
  final String recipientName;
  final CertNamePlacement namePlacement;
  final Map<String, CertNamePlacement> signatoryPlacements;
  final Map<String, SignatoryData> signatories;

  const _CertificateComposite({
    required this.background,
    required this.recipientName,
    required this.namePlacement,
    this.signatoryPlacements = const {},
    this.signatories = const {},
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest;
        final fittedFontSize = _autoFitFontSize(
          text: recipientName,
          baseFontSize: namePlacement.fontSize,
          maxWidthPx: boxSize.width * 0.65,
        );
        final effectivePlacement = namePlacement.copyWith(
          fontSize: fittedFontSize,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CertificateImageWithName(
                recipientName: recipientName,
                placement: effectivePlacement,
                background: Image(image: background, fit: BoxFit.cover),
              ),
            ),
            for (final entry in signatoryPlacements.entries)
              if (signatories.containsKey(entry.key))
                _buildSignatoryOverlay(
                  boxSize: boxSize,
                  placement: entry.value,
                  signatory: signatories[entry.key]!,
                ),
          ],
        );
      },
    );
  }

  Widget _buildSignatoryOverlay({
    required Size boxSize,
    required CertNamePlacement placement,
    required SignatoryData signatory,
  }) {
    const overlayWidth = 130.0;
    final left = (placement.xPct * boxSize.width - overlayWidth / 2)
        .clamp(0.0, math.max(0.0, boxSize.width - overlayWidth))
        .toDouble();
    final top = (placement.yPct * boxSize.height - 30)
        .clamp(0.0, math.max(0.0, boxSize.height - 60))
        .toDouble();
    final textColor = placement.light ? Colors.white : const Color(0xFF1A202C);

    return Positioned(
      left: left,
      top: top,
      width: overlayWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (signatory.signatureBase64 != null && 
              signatory.signatureBase64!.isNotEmpty)
            SizedBox(
              height: 40,
              child: Image.memory(
                base64Decode(signatory.signatureBase64!),
                fit: BoxFit.contain,
              ),
            ),
          Text(
            signatory.fullName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.beVietnamPro(
              fontSize: (placement.fontSize * 0.7).clamp(9, 14),
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (signatory.title.isNotEmpty)
            Text(
              signatory.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.beVietnamPro(
                fontSize: (placement.fontSize * 0.55).clamp(8, 12),
                color: textColor.withOpacity(0.85),
              ),
            ),
        ],
      ),
    );
  }
}

double _autoFitFontSize({
  required String text,
  required double baseFontSize,
  required double maxWidthPx,
  double minFontSize = 11,
  double avgCharWidthFactor = 0.56,
}) {
  if (text.isEmpty || maxWidthPx <= 0) return baseFontSize;
  double fs = baseFontSize;
  double estWidth() => text.length * fs * avgCharWidthFactor;
  while (fs > minFontSize && estWidth() > maxWidthPx) {
    fs -= 1;
  }
  return fs;
}
// ─────────────────────────────────────────────────────────────
//  STANDALONE SCREEN
// ─────────────────────────────────────────────────────────────
class StudentCertificatesScreen extends StatelessWidget {
  const StudentCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Certificates',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const CertificatesContent(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED CONTENT WIDGET
// ─────────────────────────────────────────────────────────────
class CertificatesContent extends StatefulWidget {
  const CertificatesContent({super.key});

  @override
  State<CertificatesContent> createState() => _CertificatesContentState();
}

class _CertificatesContentState extends State<CertificatesContent> {
  String _orgFilter = 'All';
  List<String> _orgFilters = ['All'];
  
  List<Map<String, dynamic>> _allCertificates = [];
  bool _isLoading = true;
  bool _orgFiltersLoading = true;
  String? _error;

  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
    _fetchOrganizationFilters();
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH ORGANIZATION FILTERS
  // ─────────────────────────────────────────────────────────────
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
      
      // ✅ Add "Uploaded by you" filter (walang icon)
      final filters = ['All', ...names, 'Uploaded by you'];
      
      setState(() {
        _orgFilters = filters;
        _orgFiltersLoading = false;
      });
    } catch (_) {
      setState(() {
        _orgFilters = ['All', 'Uploaded by you'];
        _orgFiltersLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH CERTIFICATES
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchCertificates() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final query = _currentUid != null
          ? FirebaseFirestore.instance
              .collection('certificates')
              .where('recipientUid', isEqualTo: _currentUid)
          : FirebaseFirestore.instance.collection('certificates');
      final snapshot = await query.get();

      var docs = snapshot.docs;

      // Filter out drafts client‑side (avoids composite index)
      docs = docs.where((doc) => (doc.data()['status'] ?? '') != 'draft').toList();

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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _docToMap(QueryDocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return {
    'id'          : doc.id,
    'title'       : data['eventName'] ?? 'Untitled Certificate',
    'date'        : _formatDate(data['issuedAt']),
    'category'    : data['type'] ?? data['templateType'] ?? 'General',
    'organization': data['organization'] ?? '',
    'recipientName': data['recipientName'] ?? '',
    'signatories' : data['signatories'] is List ? data['signatories'] : const [],
    'status'      : data['status'] ?? 'draft',
    'recipients'  : data['recipients'] ?? 0,
    'templateType': data['templateType'] ?? '',
    'imageUrl'    : data['templateFileUrl'] ?? data['imageUrl'] ?? '',
    'namePlacement': data['namePlacement'] is Map ? data['namePlacement'] : null,
    'signatoryPlacements': data['signatoryPlacements'] is Map ? data['signatoryPlacements'] : null, // ← ADD THIS
    'isUploaded'  : data['isUploaded'] ?? false,
    'verificationCode' : data['verificationCode'] ?? '',
    'autoGenerated'    : data['autoGenerated'] ?? false,
    'eventId'     : data['eventId'] ?? '',
  };
}

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      const months = [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
      ];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2,'0')}, ${dt.year}';
    }
    return timestamp.toString();
  }

  // ── Helper: decode base64 image safely ─────────────────────────
  bool _isBase64Image(String url) =>
      url.startsWith('data:image') || (!url.startsWith('http') && url.isNotEmpty);

  Widget _buildImage(String imageUrl, {double height = 180}) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    if (_isBase64Image(imageUrl)) {
      try {
        final base64Str = imageUrl.contains(',')
            ? imageUrl.split(',').last
            : imageUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: height,
          color: AppColors.primaryDark.shade50,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryDark),
          ),
        );
      },
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  // ── Filter Bottom Sheet ──────────────────────────────────────────
  void _showOrgFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Filter Certificates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 8),
                    if (_orgFiltersLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: AppColors.primaryDark),
                        ),
                      )
                    else
                      ...List.generate(_orgFilters.length, (i) {
                        final filter = _orgFilters[i];
                        final isSelected = _orgFilter == filter;
                        
                        return InkWell(
                          onTap: () {
                            setSheetState(() {});
                            setState(() => _orgFilter = filter);
                            Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : Colors.grey.shade400,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    filter,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primaryDark : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryDark,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // UPLOAD FEATURE
  // ════════════════════════════════════════════════════════════════
  Future<void> _showUploadDialog() async {
    final eventNameCtrl = TextEditingController();
    File? pickedFile;
    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
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
                backgroundColor: AppColors.primaryDark));
              return;
            }
            if (eventNameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Certificate name is required.'),
                backgroundColor: AppColors.primaryDark));
              return;
            }
            setSheet(() => isUploading = true);
            try {
              final bytes = await pickedFile!.readAsBytes();
              final b64Img = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (b64Img.length > 900000) {
                setSheet(() => isUploading = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Image is too large. Please pick a smaller image.'),
                  backgroundColor: Colors.red, duration: Duration(seconds: 4)));
                return;
              }
              final docRef = await FirebaseFirestore.instance.collection('certificates').add({
                'eventName': eventNameCtrl.text.trim(),
                'imageUrl': b64Img,
                'issuedAt': FieldValue.serverTimestamp(),
                'recipientUid': _currentUid,
                'isUploaded': true,
                'status': 'issued',
              });
              final now = DateTime.now();
              const months = ['January','February','March','April','May','June',
                              'July','August','September','October','November','December'];
              final newCert = {
                'id': docRef.id,
                'title': eventNameCtrl.text.trim(),
                'date': '${months[now.month-1]} ${now.day.toString().padLeft(2,'0')}, ${now.year}',
                'category': 'General',
                'organization': '',
                'signatories': '',
                'status': 'issued',
                'recipients': 1,
                'templateType': '',
                'imageUrl': b64Img,
                'isUploaded': true,
                'verificationCode': '',
              };
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() { 
                  _allCertificates.insert(0, newCert); 
                  _orgFilter = 'All';
                });
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

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                maxWidth: 480,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 24, right: 24, top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Upload Certificate',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text('Add the image and name of your certificate.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
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
                          color: AppColors.primaryDark.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryDark.shade200, width: 1.5),
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
                                Icon(Icons.cloud_upload_rounded, size: 44, color: AppColors.primaryDark.shade400),
                                const SizedBox(height: 8),
                                Text('Tap to upload image',
                                    style: TextStyle(color: AppColors.primaryDark.shade400, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text('Keep image under 700KB for best results',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                              ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Certificate Details'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: eventNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Certificate Name *',
                        hintText: 'e.g. Codecraft',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: isUploading ? null : doUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          disabledBackgroundColor: AppColors.primaryDark.shade200,
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

 Widget _buildCertificateCard(Map<String, dynamic> cert) {
  final isDraft    = cert['status'] == 'draft';
  final isUploaded = cert['isUploaded'] == true;
  final imageUrl   = cert['imageUrl'] as String;
  final canRenderLive = !isUploaded && (cert['organization'] as String).isNotEmpty;

  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: imageUrl.isNotEmpty
              ? (isUploaded
                  ? _buildImage(imageUrl)
                  : FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('signatories').get(),
                      builder: (context, snap) {
                        // Build signatories map
                        final signatories = <String, SignatoryData>{};
                        for (final doc in (snap.data?.docs ?? [])) {
                          final data = doc.data() as Map<String, dynamic>? ?? {};
                          final id = doc.id;
                          signatories[id] = SignatoryData(
                            id: id,
                            placeholderKey: (data['placeholderKey'] ?? '').toString(),
                            fullName: (data['fullName'] ?? '').toString(),
                            title: (data['title'] ?? '').toString(),
                            signatureBase64: data['signatureBase64'] as String?,
                          );
                        }
                        
                        // Get signatory placements from certificate
                        final sigPlacements = cert['signatoryPlacements'] as Map<String, dynamic>? ?? {};
                        final placements = <String, CertNamePlacement>{};
                        for (final entry in sigPlacements.entries) {
                          placements[entry.key] = CertNamePlacement.fromMap(
                            Map<String, dynamic>.from(entry.value as Map),
                          );
                        }
                        
                        // Also need the namePlacement from cert
                        final namePlacement = cert['namePlacement'] as Map<String, dynamic>?;
                        
                        return _CertificateComposite(
                          recipientName: cert['recipientName'] as String? ?? 'Recipient',
                          namePlacement: CertNamePlacement.fromMap(namePlacement),
                          signatoryPlacements: placements,
                          signatories: signatories,
                          background: NetworkImage(imageUrl),
                        );
                      },
                    ))
              : canRenderLive
                  ? _buildLivePreview(cert)
                  : _placeholderBanner(isDraft, isUploaded, cert),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                    if (cert['organization'].toString().isNotEmpty)
                      Text(
                        cert['organization'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      cert['date'],
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    if (isUploaded) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Uploaded by you',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Download button
              GestureDetector(
                onTap: () => _showMessage('✅ ${cert['title']} downloaded!'),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ── Live preview for non‑uploaded certificates ──────────────────
  Widget _buildLivePreview(Map<String, dynamic> cert) {
    final signatories = (cert['signatories'] as List)
        .whereType<Map>()
        .map((s) => CertSignatory(
              name: (s['name'] ?? '').toString(),
              title: (s['title'] ?? '').toString(),
              signatureImageBase64: s['signatureImage'] as String?,
            ))
        .toList();
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFFF7F8FA),
      padding: const EdgeInsets.all(12),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 600,
          height: 424,
          child: CertificatePreview(
            theme: CertTheme.forType(cert['templateType'] as String?,
                primaryDark: UpriseColors.primaryDark, primaryLight: UpriseColors.primaryLight, accentColor: UpriseColors.accent),
            orgName: cert['organization'] as String,
            eventTitle: cert['title'] as String,
            eventDate: cert['date'] as String,
            recipient: (cert['recipientName'] as String).isNotEmpty ? cert['recipientName'] as String : 'Recipient',
            signatories: signatories,
            verificationCode: null,
          ),
        ),
      ),
    );
  }

  Widget _placeholderBanner(bool isDraft, bool isUploaded, Map<String, dynamic> cert) {
    return Container(
      height: 180, width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUploaded
              ? [Colors.blue.shade200, Colors.blue.shade500]
              : [AppColors.primaryDark.shade200, AppColors.primaryDark.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isUploaded ? Icons.upload_file_rounded : Icons.workspace_premium,
            size: 70, color: Colors.white24,
          ),
          if (isDraft)
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                child: const Text('DRAFT',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
          if ((cert['organization'] as String).isNotEmpty)
            Positioned(
              bottom: 10, left: 14,
              child: Text(cert['organization'],
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark.shade700, letterSpacing: 0.4));
  }

  // ─── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Filter certificates
    List<Map<String, dynamic>> filtered;
    
    if (_orgFilter == 'All') {
      filtered = _allCertificates;
    } else if (_orgFilter == 'Uploaded by you') {
      // Show only certificates uploaded by the current user
      filtered = _allCertificates.where((c) => c['isUploaded'] == true).toList();
    } else {
      // Filter by organization
      filtered = _allCertificates.where((c) => c['organization'] == _orgFilter).toList();
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER: "All Certificates" + Filter Icon ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _orgFilter == 'All' 
                          ? 'All Certificates' 
                          : _orgFilter == 'Uploaded by you'
                              ? 'Uploaded by you'
                              : _orgFilter,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showOrgFilterSheet,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _orgFilter != 'All'
                            ? AppColors.primaryDark
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _orgFilter != 'All'
                              ? AppColors.primaryDark
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Icon(
                        Icons.filter_list_rounded,
                        size: 22,
                        color: _orgFilter != 'All'
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // ── Show count of uploaded certificates ──
            if (_orgFilter == 'Uploaded by you')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${filtered.length} certificate${filtered.length != 1 ? 's' : ''} uploaded by you',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // ── CONTENT ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text('Failed to load certificates',
                                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() { _isLoading = true; _error = null; });
                                  _fetchCertificates();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                                child: const Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _orgFilter == 'Uploaded by you'
                                          ? Icons.cloud_upload_rounded
                                          : Icons.workspace_premium_outlined,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _orgFilter == 'Uploaded by you'
                                          ? 'No uploaded certificates'
                                          : 'No Certificates Yet',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _orgFilter == 'Uploaded by you'
                                          ? 'You haven\'t uploaded any certificates yet.\nTap the + button to upload one.'
                                          : 'Your participation certificates will appear here after:\n\n'
                                          '• Your organization sends an evaluation request.\n'
                                          '• You complete the event evaluation.\n'
                                          '• Your organization uploads your certificate.\n\n'
                                          'Once available, you can preview and download your certificates from this page.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.primaryDark,
                              onRefresh: _fetchCertificates,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => _buildCertificateCard(filtered[i]),
                              ),
                            ),
            ),
          ],
        ),
        // ── FAB to add a new certificate ──
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            heroTag: 'cert_upload_fab',
            onPressed: _showUploadDialog,
            backgroundColor: AppColors.primaryDark,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
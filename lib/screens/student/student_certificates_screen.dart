import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StudentCertificatesScreen extends StatefulWidget {
  const StudentCertificatesScreen({super.key});

  @override
  State<StudentCertificatesScreen> createState() =>
      _StudentCertificatesScreenState();
}

class _StudentCertificatesScreenState
    extends State<StudentCertificatesScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Academic', 'Workshops', 'Events'];

  List<Map<String, dynamic>> _allCertificates = [];
  bool _isLoading = true;
  String? _error;

  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchCertificates() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .get();

      var docs = snapshot.docs;

      if (_currentUid != null) {
        docs = docs.where((doc) {
          final recipient = doc.data()['recipientUid'];
          return recipient == null || recipient == _currentUid;
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
      'signatories' : data['signatories'] ?? '',
      'status'      : data['status'] ?? 'draft',
      'recipients'  : data['recipients'] ?? 0,
      'templateType': data['templateType'] ?? '',
      'imageUrl'    : data['imageUrl'] ?? '',
      'isUploaded'  : data['isUploaded'] ?? false,
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

  // ─────────────────────────────────────────────────────────────
  // UPLOAD DIALOG
  // ─────────────────────────────────────────────────────────────
  Future<void> _showUploadDialog() async {
    final eventNameCtrl    = TextEditingController();
    final organizationCtrl = TextEditingController();
    final orgIdCtrl        = TextEditingController();
    final signatoriesCtrl  = TextEditingController();
    final recipientsCtrl   = TextEditingController(text: '1');

    String selectedType         = 'Participation';
    String selectedTemplateType = 'Formal Academic';
    String selectedStatus       = 'issued';
    File? pickedFile;
    bool isUploading = false;

    const typeOptions         = ['Participation','Achievement','Completion','Recognition'];
    const templateTypeOptions = ['Formal Academic','Simple','Modern','Elegant'];
    const statusOptions       = ['issued','draft'];

    InputDecoration fieldDeco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {

          Future<void> pickImage(ImageSource src) async {
            final picked = await ImagePicker()
                .pickImage(source: src, imageQuality: 85);
            if (picked != null) setSheet(() => pickedFile = File(picked.path));
          }

          Future<void> doUpload() async {
            if (pickedFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select a certificate image.'),
                backgroundColor: Colors.orange,
              ));
              return;
            }
            if (eventNameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Event name is required.'),
                backgroundColor: Colors.orange,
              ));
              return;
            }

            setSheet(() => isUploading = true);

            try {
              // 1. Upload image to Storage
              final fileName =
                  '${_currentUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('certificates/$fileName');
              await ref.putFile(pickedFile!);
              final imageUrl = await ref.getDownloadURL();

              // 2. Save to Firestore
              final docRef = await FirebaseFirestore.instance
                  .collection('certificates')
                  .add({
                'eventName'    : eventNameCtrl.text.trim(),
                'organization' : organizationCtrl.text.trim(),
                'orgId'        : orgIdCtrl.text.trim(),
                'signatories'  : signatoriesCtrl.text.trim(),
                'recipients'   : int.tryParse(recipientsCtrl.text.trim()) ?? 1,
                'type'         : selectedType,
                'templateType' : selectedTemplateType,
                'status'       : selectedStatus,
                'imageUrl'     : imageUrl,
                'issuedAt'     : FieldValue.serverTimestamp(),
                'recipientUid' : _currentUid,
                'isUploaded'   : true,
              });

              // 3. Build local map immediately so it shows at top NOW
              final now = DateTime.now();
              const months = [
                'January','February','March','April','May','June',
                'July','August','September','October','November','December'
              ];
              final newCert = {
                'id'          : docRef.id,
                'title'       : eventNameCtrl.text.trim(),
                'date'        : '${months[now.month - 1]} ${now.day.toString().padLeft(2,'0')}, ${now.year}',
                'category'    : selectedType,
                'organization': organizationCtrl.text.trim(),
                'signatories' : signatoriesCtrl.text.trim(),
                'status'      : selectedStatus,
                'recipients'  : int.tryParse(recipientsCtrl.text.trim()) ?? 1,
                'templateType': selectedTemplateType,
                'imageUrl'    : imageUrl,
                'isUploaded'  : true,
              };

              // 4. Insert at top of list instantly
              if (mounted) {
                setState(() {
                  _allCertificates.insert(0, newCert);
                });
              }

              if (ctx.mounted) Navigator.pop(ctx);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Certificate uploaded successfully!'),
                  backgroundColor: Colors.green,
                ));
              }
            } catch (e) {
              setSheet(() => isUploading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Upload failed: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const Text('Upload Certificate',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Fill in the details as shown on your certificate.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  // ── IMAGE PICKER ──
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: ctx,
                        builder: (c) => SafeArea(
                          child: Wrap(children: [
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
                          ]),
                        ),
                      );
                    },
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
                              child: Image.file(pickedFile!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 44, color: Colors.orange.shade400),
                                const SizedBox(height: 8),
                                Text('Tap to select image',
                                    style: TextStyle(
                                        color: Colors.orange.shade400,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _sectionLabel('Certificate Details'),
                  const SizedBox(height: 12),

                  // eventName *
                  TextField(
                    controller: eventNameCtrl,
                    decoration: fieldDeco('Event Name *', hint: 'e.g. Codecraft'),
                  ),
                  const SizedBox(height: 12),

                  // organization
                  TextField(
                    controller: organizationCtrl,
                    decoration: fieldDeco('Organization', hint: 'e.g. SWITS'),
                  ),
                  const SizedBox(height: 12),

                  // orgId
                  TextField(
                    controller: orgIdCtrl,
                    decoration: fieldDeco('Org ID',
                        hint: 'e.g. vJgko6vPRvJ0bGkJa0xg'),
                  ),
                  const SizedBox(height: 12),

                  // signatories
                  TextField(
                    controller: signatoriesCtrl,
                    decoration: fieldDeco('Signatories', hint: 'e.g. Jayson Batoon'),
                  ),
                  const SizedBox(height: 12),

                  // recipients
                  TextField(
                    controller: recipientsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: fieldDeco('Recipients', hint: '1'),
                  ),
                  const SizedBox(height: 20),

                  _sectionLabel('Classification'),
                  const SizedBox(height: 12),

                  // type
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: fieldDeco('Type'),
                    items: typeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // templateType
                  DropdownButtonFormField<String>(
                    value: selectedTemplateType,
                    decoration: fieldDeco('Template Type'),
                    items: templateTypeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => selectedTemplateType = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // status
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: fieldDeco('Status'),
                    items: statusOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── UPLOAD BUTTON ──
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: isUploading ? null : doUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        disabledBackgroundColor: Colors.orange.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isUploading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Upload Certificate',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
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

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = selectedFilter == 'All'
        ? _allCertificates
        : _allCertificates
            .where((c) => c['category'] == selectedFilter)
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Certificate',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.upload_rounded, color: Colors.white),
        label: const Text('Upload Certificate',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── FILTER CHIPS ──
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey.shade300,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(filter,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── CONTENT ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text('Failed to load certificates',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() { _isLoading = true; _error = null; });
                                _fetchCertificates();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange),
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium_outlined,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('No certificates found',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, top: 4, bottom: 90),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildCertificateCard(filtered[index]),
                          ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CERTIFICATE CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildCertificateCard(Map<String, dynamic> cert) {
    final isDraft    = cert['status'] == 'draft';
    final isUploaded = cert['isUploaded'] == true;
    final imageUrl   = cert['imageUrl'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 180, width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : _placeholderBanner(isDraft, isUploaded, cert),
                    errorBuilder: (_, __, ___) =>
                        _placeholderBanner(isDraft, isUploaded, cert),
                  )
                : _placeholderBanner(isDraft, isUploaded, cert),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(cert['date'],
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      if (isUploaded) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Uploaded by you',
                              style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${cert['title']} downloaded'),
                      backgroundColor: Colors.orange,
                    ));
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBanner(
      bool isDraft, bool isUploaded, Map<String, dynamic> cert) {
    return Container(
      height: 180, width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUploaded
              ? [Colors.blue.shade200, Colors.blue.shade500]
              : [Colors.orange.shade200, Colors.orange.shade500],
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
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('DRAFT',
                    style: TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
          if ((cert['organization'] as String).isNotEmpty)
            Positioned(
              bottom: 10, left: 14,
              child: Text(cert['organization'],
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: Colors.orange.shade700, letterSpacing: 0.4));
  }
}
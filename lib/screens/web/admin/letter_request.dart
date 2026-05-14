import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../../services/activity_logger.dart' as activity_log;

class LetterRequest extends StatefulWidget {
  const LetterRequest({super.key});

  @override
  _LetterRequestState createState() => _LetterRequestState();
}

class _LetterRequestState extends State<LetterRequest> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      // FloatingActionButton removed – documents are uploaded by organizations
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatsRow(),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------- HEADER (responsive) ----------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Letter Request',
                  style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and access centralized student organization documentations and requirements.',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- REAL‑TIME STATS ROW ----------
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('letter_requests').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, archived = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          total = docs.length;
          for (var doc in docs) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            switch (status) {
              case 'pending': pending++; break;
              case 'approved': approved++; break;
              case 'rejected': rejected++; break;
              case 'archived': archived++; break;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            _statCard('TOTAL DOCUMENTS', '$total', UpriseColors.primaryDark),
            const SizedBox(width: 16),
            _statCard('PENDING', '$pending', UpriseColors.warning),
            const SizedBox(width: 16),
            _statCard('APPROVED', '$approved', UpriseColors.success),
            const SizedBox(width: 16),
            _statCard('REJECTED', '$rejected', UpriseColors.error),
            const SizedBox(width: 16),
            _statCard('ARCHIVED', '$archived', UpriseColors.darkGray),
          ]),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.primaryDark, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: UpriseColors.darkGray, fontWeight: FontWeight.w500)),
            SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: UpriseColors.primaryDark)),
          ],
        ),
      ),
    );
  }

  // ---------- TOOLBAR ----------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(fontSize: 13, color: UpriseColors.darkGray),
                  prefixIcon: Icon(Icons.search, size: 20, color: UpriseColors.darkGray),
                  filled: true,
                  fillColor: UpriseColors.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (_) => setState(() => _currentPage = 1),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                border: Border.all(color: UpriseColors.primaryDark, width: 1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: DropdownButton<String>(
                value: _statusFilter,
                hint: Text('Filter', style: TextStyle(fontSize: 13, color: UpriseColors.darkGray)),
                underline: SizedBox(),
                items: ['All', 'Pending', 'Approved', 'Rejected', 'Archived']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _statusFilter = value!;
                  _currentPage = 1;
                }),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export feature coming soon')),
                );
              },
              icon: Icon(Icons.download, size: 18),
              label: Text('Export', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UpriseColors.white,
                foregroundColor: UpriseColors.primaryDark,
                side: BorderSide(color: UpriseColors.primaryDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TABLE (unchanged) ----------
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('letter_requests').orderBy('uploadDate', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: UpriseColors.error)));
        }

        var docs = snapshot.data!.docs;
        if (_statusFilter != 'All') {
          docs = docs.where((d) => (d.data() as Map)['status'] == _statusFilter.toLowerCase()).toList();
        }
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final requestedBy = (data['requestedBy'] ?? '').toString().toLowerCase();
            return title.contains(term) || requestedBy.contains(term);
          }).toList();
        }

        if (docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UpriseColors.primaryDark, width: 1),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: UpriseColors.lightGray,
                    border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('DOCUMENT NAME', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('UPLOAD DATE', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                  ]),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: UpriseColors.mediumGray),
                        const SizedBox(height: 16),
                        Text('No documents found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final totalPages = (docs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, docs.length);
        final pageDocs = docs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.primaryDark, width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: UpriseColors.lightGray,
                  border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(children: [
                  Expanded(flex: 3, child: Text('DOCUMENT NAME', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('UPLOAD DATE', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pageDocs.length,
                  itemBuilder: (_, i) {
                    final data = pageDocs[i].data() as Map<String, dynamic>;
                    final doc = Document(
                      id: pageDocs[i].id,
                      title: data['title'] ?? 'Untitled',
                      fileName: data['fileName'] ?? '',
                      fileType: data['fileType'] ?? 'pdf',
                      fileSize: (data['fileSize'] ?? 0).toInt(),
                      uploadDate: (data['uploadDate'] as Timestamp).toDate(),
                      status: data['status'] ?? 'pending',
                      requestedBy: data['requestedBy'] ?? '',
                      department: data['department'] ?? '',
                      content: data['content'] ?? '',
                      revisionNotes: data['revisionNotes'] ?? '',
                    );
                    return _buildRow(doc);
                  },
                ),
              ),
              _buildFooter(docs.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(
      fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
        color: UpriseColors.lightGray,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total documents',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: _currentPage > 1 ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          ...pages.map((page) => GestureDetector(
                onTap: () => setState(() => _currentPage = page),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: page == _currentPage ? UpriseColors.primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$page',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: page == _currentPage ? Colors.white : UpriseColors.charcoal,
                        fontWeight: page == _currentPage ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              )),
          if (lastPage < totalPages) ...[
            Text('...', style: TextStyle(color: UpriseColors.darkGray)),
            GestureDetector(
              onTap: () => setState(() => _currentPage = totalPages),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('$totalPages',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.charcoal)),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            color: _currentPage < totalPages ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ]),
      ]),
    );
  }

  Widget _buildRow(Document doc) {
    final statusColor = doc.status == 'approved'
        ? UpriseColors.success
        : doc.status == 'rejected'
            ? UpriseColors.error
            : doc.status == 'archived'
                ? UpriseColors.darkGray
                : UpriseColors.warning;
    final formattedDate = DateFormat('MMM dd, yyyy').format(doc.uploadDate);
    final fileInfo = '${doc.fileType.toUpperCase()} • ${_formatFileSize(doc.fileSize)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 14, color: UpriseColors.charcoal)),
            const SizedBox(height: 4),
            Text(fileInfo, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
          ]),
        ),
        Expanded(flex: 1, child: Text(formattedDate, style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(doc.status.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ),
        Expanded(
          flex: 1,
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.visibility_outlined, size: 18, color: UpriseColors.darkGray),
              onPressed: () => _showViewDialog(doc),
              tooltip: 'View',
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: UpriseColors.primaryDark),
              onPressed: () => _showEditDialog(doc),
              tooltip: 'Edit',
            ),
            if (doc.status == 'pending')
              IconButton(
                icon: Icon(Icons.check_circle_outline, size: 18, color: UpriseColors.success),
                onPressed: () => _setStatus(doc.id, 'approved'),
                tooltip: 'Approve',
              ),
            if (doc.status == 'pending')
              IconButton(
                icon: Icon(Icons.cancel_outlined, size: 18, color: UpriseColors.error),
                onPressed: () => _setStatus(doc.id, 'rejected'),
                tooltip: 'Reject',
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: UpriseColors.error),
              onPressed: () => _confirmDelete(doc),
              tooltip: 'Delete',
            ),
          ]),
        ),
      ]),
    );
  }

  // ---------- CRUD OPERATIONS WITH LOGGING ----------
  Future<void> _setStatus(String docId, String newStatus) async {
    // Fetch document title before update
    String title = '';
    try {
      final docSnap = await FirebaseFirestore.instance.collection('letter_requests').doc(docId).get();
      title = docSnap.data()?['title'] ?? 'Unknown document';
    } catch (e) {
      title = 'Unknown document';
    }

    await FirebaseFirestore.instance.collection('letter_requests').doc(docId).update({'status': newStatus});

    await activity_log.ActivityLogger.log(
      action: '${newStatus.toUpperCase()} letter request: $title',
      module: 'Letter Request',
      severity: newStatus == 'rejected' ? 'warning' : 'info',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${newStatus.toUpperCase()}')));
    }
  }

  void _showAddDocumentDialog() => _showDocumentForm(isEdit: false, doc: null);
  void _showEditDialog(Document doc) => _showDocumentForm(isEdit: true, doc: doc);

  void _showDocumentForm({required bool isEdit, required Document? doc}) {
    final titleCtrl = TextEditingController(text: isEdit ? doc!.title : '');
    final requestedByCtrl = TextEditingController(text: isEdit ? doc!.requestedBy : '');
    final departmentCtrl = TextEditingController(text: isEdit ? doc!.department : '');
    final contentCtrl = TextEditingController(text: isEdit ? doc!.content : '');
    String fileType = isEdit ? doc!.fileType : 'pdf';
    int fileSize = isEdit ? doc!.fileSize : 0;
    String fileName = isEdit ? doc!.fileName : '';
    String status = isEdit ? doc!.status : 'pending';

    Future<void> pickFile() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result != null) {
        final file = result.files.single;
        setState(() {
          fileName = file.name;
          fileType = file.extension ?? 'pdf';
          fileSize = file.size;
        });
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            title: Row(children: [
              Icon(isEdit ? Icons.edit : Icons.upload_file, color: UpriseColors.primaryDark),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Document' : 'Upload New Document', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Document Title')),
                  const SizedBox(height: 12),
                  if (!isEdit)
                    OutlinedButton.icon(
                      onPressed: pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(fileName.isEmpty ? 'Choose File (PDF/DOCX)' : fileName),
                    ),
                  if (!isEdit && fileName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('$fileType • ${_formatFileSize(fileSize)}', style: GoogleFonts.beVietnamPro(fontSize: 11)),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(controller: requestedByCtrl, decoration: const InputDecoration(labelText: 'Requested By')),
                  const SizedBox(height: 12),
                  TextFormField(controller: departmentCtrl, decoration: const InputDecoration(labelText: 'Department')),
                  const SizedBox(height: 12),
                  TextFormField(controller: contentCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'Document Content / Description')),
                  if (isEdit)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: ['pending', 'approved', 'rejected', 'archived'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                      onChanged: (v) => setDlg(() => status = v!),
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  final data = {
                    'title': titleCtrl.text,
                    'fileName': fileName,
                    'fileType': fileType,
                    'fileSize': fileSize,
                    'uploadDate': FieldValue.serverTimestamp(),
                    'status': status,
                    'requestedBy': requestedByCtrl.text,
                    'department': departmentCtrl.text,
                    'content': contentCtrl.text,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (!isEdit) data['createdAt'] = FieldValue.serverTimestamp();
                  try {
                    if (isEdit) {
                      await FirebaseFirestore.instance.collection('letter_requests').doc(doc!.id).update(data);
                      await activity_log.ActivityLogger.log(
                        action: 'Updated letter request: ${titleCtrl.text}',
                        module: 'Letter Request',
                        severity: 'info',
                      );
                    } else {
                      if (fileName.isEmpty) throw 'Please select a file';
                      await FirebaseFirestore.instance.collection('letter_requests').add(data);
                      await activity_log.ActivityLogger.log(
                        action: 'Uploaded new letter request: ${titleCtrl.text}',
                        module: 'Letter Request',
                        severity: 'info',
                      );
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Document updated' : 'Document uploaded')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                child: Text(isEdit ? 'Save Changes' : 'Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showViewDialog(Document doc) {
    final statusColor = doc.status == 'approved'
        ? UpriseColors.success
        : doc.status == 'rejected'
            ? UpriseColors.error
            : UpriseColors.warning;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.description, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(child: Text(doc.title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold))),
        ]),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: UpriseColors.primaryDark.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('BULACAN STATE UNIVERSITY',
                      style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.bold, color: UpriseColors.primaryDark)),
                  Text('City of Malolos, Bulacan',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
                ]),
              ),
              const SizedBox(height: 16),
              Text(doc.content.isNotEmpty ? doc.content : 'No detailed content provided.', style: GoogleFonts.beVietnamPro(fontSize: 13, height: 1.5)),
              const SizedBox(height: 20),
              const Divider(),
              _detailRow('Request Number', '#${doc.id.substring(0, 8)}'),
              _detailRow('Requested By', doc.requestedBy),
              _detailRow('Department', doc.department),
              _detailRow('Upload Date', DateFormat('MMM dd, yyyy').format(doc.uploadDate)),
              _detailRow('Status', doc.status.toUpperCase(), isStatus: true, statusColor: statusColor),
              if (doc.revisionNotes.isNotEmpty) _detailRow('Revision Notes', doc.revisionNotes),
            ]),
          ),
        ),
        actions: [
          if (doc.status == 'pending')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRevisionDialog(doc);
              },
              icon: Icon(Icons.edit_note, color: UpriseColors.warning),
              label: Text('Request Revision', style: TextStyle(color: UpriseColors.warning)),
            ),
          if (doc.status == 'pending')
            TextButton.icon(
              onPressed: () async {
                await _setStatus(doc.id, 'approved');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.check_circle, color: UpriseColors.success),
              label: Text('Approve', style: TextStyle(color: UpriseColors.success)),
            ),
          if (doc.status == 'pending')
            TextButton.icon(
              onPressed: () async {
                await _setStatus(doc.id, 'rejected');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.cancel, color: UpriseColors.error),
              label: Text('Reject', style: TextStyle(color: UpriseColors.error)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRevisionDialog(Document doc) {
    final notesCtrl = TextEditingController(text: doc.revisionNotes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request Revision', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Please specify the changes or additional information needed for this document.'),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter revision notes here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('letter_requests').doc(doc.id).update({
                'revisionNotes': notesCtrl.text,
                'status': 'pending',
              });
              await activity_log.ActivityLogger.log(
                action: 'Requested revision for letter request: ${doc.title}',
                module: 'Letter Request',
                severity: 'info',
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision request sent')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: const Text('Send Revision Request'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text('$label:', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray))),
        Expanded(
          child: isStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor?.withOpacity(0.1) ?? Colors.transparent, borderRadius: BorderRadius.circular(4)),
                  child: Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                )
              : Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12)),
        ),
      ]),
    );
  }

  void _confirmDelete(Document doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('letter_requests').doc(doc.id).delete();
              await activity_log.ActivityLogger.log(
                action: 'Deleted letter request: ${doc.title}',
                module: 'Letter Request',
                severity: 'warning',
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------- EXPORT ----------
  Future<void> _exportToCSV() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('letter_requests').get();
      final lines = <String>['Title,Requested By,Department,Upload Date,Status,File Name,File Size,Content'];
      for (var doc in snap.docs) {
        final d = doc.data();
        lines.add([
          d['title'] ?? '',
          d['requestedBy'] ?? '',
          d['department'] ?? '',
          (d['uploadDate'] as Timestamp).toDate().toString(),
          d['status'] ?? '',
          d['fileName'] ?? '',
          d['fileSize'] ?? '',
          (d['content'] ?? '').replaceAll(',', ';'),
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/letter_requests.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Letter Requests Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// Document model (unchanged)
class Document {
  final String id;
  final String title;
  final String fileName;
  final String fileType;
  final int fileSize;
  final DateTime uploadDate;
  final String status;
  final String requestedBy;
  final String department;
  final String content;
  final String revisionNotes;

  Document({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadDate,
    required this.status,
    required this.requestedBy,
    required this.department,
    required this.content,
    required this.revisionNotes,
  });
}
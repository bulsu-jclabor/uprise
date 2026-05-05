// lib/screens/admin/letter_request.dart – fixed fileSize type
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class LetterRequest extends StatefulWidget {
  @override
  _LetterRequestState createState() => _LetterRequestState();
}

class _LetterRequestState extends State<LetterRequest> {
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<Document> _allDocs = [];
  List<Document> _filteredDocs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('letter_requests')
          .orderBy('uploadDate', descending: true)
          .get();
      _allDocs = snapshot.docs.map((doc) {
        final data = doc.data();
        return Document(
          id: doc.id,
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
      }).toList();
      _applyFilters();
    } catch (e) {
      print('Error loading docs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDocs = _allDocs.where((doc) {
        if (_statusFilter != 'All' && doc.status != _statusFilter) return false;
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          return doc.title.toLowerCase().contains(term) ||
              doc.requestedBy.toLowerCase().contains(term);
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    int total = _allDocs.length;
    int pending = _allDocs.where((d) => d.status == 'pending').length;
    int approved = _allDocs.where((d) => d.status == 'approved').length;
    int rejected = _allDocs.where((d) => d.status == 'rejected').length;
    int archived = _allDocs.where((d) => d.status == 'archived').length;

    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocumentDialog,
        backgroundColor: UpriseColors.primaryDark,
        child: Icon(Icons.add, color: UpriseColors.white),
        tooltip: 'Upload Document',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatsRow(total, pending, approved, rejected, archived),
          _buildToolbar(),
          Expanded(child: _buildTable()),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Letter Request',
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
          ),
          SizedBox(height: 4),
          Text(
            'Manage and access centralized student organization documentations and requirements.',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int total, int pending, int approved, int rejected, int archived) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Row(children: [
        _statCard('TOTAL DOCUMENTS', '$total', UpriseColors.primaryDark),
        SizedBox(width: 16),
        _statCard('PENDING', '$pending', UpriseColors.warning),
        SizedBox(width: 16),
        _statCard('APPROVED', '$approved', UpriseColors.success),
        SizedBox(width: 16),
        _statCard('REJECTED', '$rejected', UpriseColors.error),
        SizedBox(width: 16),
        _statCard('ARCHIVED', '$archived', UpriseColors.darkGray),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _buildToolbar() {
    final tabs = ['All', 'Pending', 'Approved', 'Rejected', 'Archived'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((tab) {
                  final selected = (_statusFilter == tab) ||
                      (tab == 'All' && _statusFilter == 'All') ||
                      (tab == 'Pending' && _statusFilter == 'pending') ||
                      (tab == 'Approved' && _statusFilter == 'approved') ||
                      (tab == 'Rejected' && _statusFilter == 'rejected') ||
                      (tab == 'Archived' && _statusFilter == 'archived');
                  return Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _filterChip(tab, selected, () {
                      setState(() {
                        if (tab == 'All') _statusFilter = 'All';
                        else if (tab == 'Pending') _statusFilter = 'pending';
                        else if (tab == 'Approved') _statusFilter = 'approved';
                        else if (tab == 'Rejected') _statusFilter = 'rejected';
                        else if (tab == 'Archived') _statusFilter = 'archived';
                        _applyFilters();
                      });
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(width: 16),
          Container(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                filled: true,
                fillColor: UpriseColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: UpriseColors.mediumGray),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: UpriseColors.white,
      selectedColor: UpriseColors.primaryDark.withOpacity(0.1),
      checkmarkColor: UpriseColors.primaryDark,
      labelStyle: GoogleFonts.beVietnamPro(
        color: selected ? UpriseColors.primaryDark : UpriseColors.darkGray,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: StadiumBorder(side: BorderSide(color: UpriseColors.mediumGray)),
    );
  }

  Widget _buildTable() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark));
    }
    if (_filteredDocs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open, size: 64, color: UpriseColors.mediumGray),
          SizedBox(height: 16),
          Text('No documents found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
        ]),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: UpriseColors.lightGray,
            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
            itemCount: _filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = _filteredDocs[index];
              return _buildRow(doc);
            },
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
            color: UpriseColors.lightGray,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Showing ${_filteredDocs.length} of ${_allDocs.length} documents',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
              Row(
                children: [
                  IconButton(icon: Icon(Icons.chevron_left, size: 20), onPressed: () {}),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: UpriseColors.primaryDark, borderRadius: BorderRadius.circular(4)),
                    child: Text('1', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  IconButton(icon: Icon(Icons.chevron_right, size: 20), onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(
    fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildRow(Document doc) {
    final statusColor = doc.status == 'approved' ? UpriseColors.success
        : doc.status == 'rejected' ? UpriseColors.error
        : doc.status == 'archived' ? UpriseColors.darkGray
        : UpriseColors.warning;
    final formattedDate = DateFormat('MMM dd, yyyy').format(doc.uploadDate);
    final fileInfo = '${doc.fileType.toUpperCase()} • ${_formatFileSize(doc.fileSize)}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 14, color: UpriseColors.charcoal)),
            SizedBox(height: 4),
            Text(fileInfo, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
          ]),
        ),
        Expanded(flex: 1, child: Text(formattedDate, style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(doc.status.toUpperCase(), textAlign: TextAlign.center,
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

  Future<void> _setStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('letter_requests').doc(docId).update({'status': newStatus});
    _loadDocuments();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${newStatus.toUpperCase()}')));
  }

  void _showAddDocumentDialog() => _showDocumentForm(isEdit: false, doc: null);
  void _showEditDialog(Document doc) => _showDocumentForm(isEdit: true, doc: doc);

  // Fixed method – fileSize is int
  void _showDocumentForm({required bool isEdit, required Document? doc}) {
    final titleCtrl = TextEditingController(text: isEdit ? doc!.title : '');
    final requestedByCtrl = TextEditingController(text: isEdit ? doc!.requestedBy : 'Admin User');
    final departmentCtrl = TextEditingController(text: isEdit ? doc!.department : 'Legal Department');
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
              SizedBox(width: 8),
              Text(isEdit ? 'Edit Document' : 'Upload New Document', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Document Title')),
                  SizedBox(height: 12),
                  if (!isEdit)
                    OutlinedButton.icon(
                      onPressed: pickFile,
                      icon: Icon(Icons.attach_file),
                      label: Text(fileName.isEmpty ? 'Choose File (PDF/DOCX)' : fileName),
                    ),
                  if (!isEdit && fileName.isNotEmpty)
                    Padding(padding: EdgeInsets.only(top: 8), child: Text('$fileType • ${_formatFileSize(fileSize)}', style: GoogleFonts.beVietnamPro(fontSize: 11))),
                  SizedBox(height: 12),
                  TextFormField(controller: requestedByCtrl, decoration: InputDecoration(labelText: 'Requested By')),
                  SizedBox(height: 12),
                  TextFormField(controller: departmentCtrl, decoration: InputDecoration(labelText: 'Department')),
                  SizedBox(height: 12),
                  TextFormField(controller: contentCtrl, maxLines: 5, decoration: InputDecoration(labelText: 'Document Content / Description')),
                  if (isEdit)
                    DropdownButtonFormField<String>(
                      value: status,
                      items: ['pending', 'approved', 'rejected', 'archived'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                      onChanged: (v) => setDlg(() => status = v!),
                      decoration: InputDecoration(labelText: 'Status'),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
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
                    } else {
                      if (fileName.isEmpty) throw 'Please select a file';
                      await FirebaseFirestore.instance.collection('letter_requests').add(data);
                    }
                    _loadDocuments();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Document updated' : 'Document uploaded')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error));
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
    final statusColor = doc.status == 'approved' ? UpriseColors.success
        : doc.status == 'rejected' ? UpriseColors.error
        : UpriseColors.warning;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.description, color: UpriseColors.primaryDark),
          SizedBox(width: 8),
          Expanded(child: Text(doc.title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold))),
        ]),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: UpriseColors.primaryDark.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('BULACAN STATE UNIVERSITY',
                      style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.bold, color: UpriseColors.primaryDark)),
                  Text('City of Malolos, Bulacan',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
                ]),
              ),
              SizedBox(height: 16),
              Text(doc.content.isNotEmpty ? doc.content : 'No detailed content provided.', style: GoogleFonts.beVietnamPro(fontSize: 13, height: 1.5)),
              SizedBox(height: 20),
              Divider(),
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
            child: Text('Close', style: TextStyle(color: Colors.white)),
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
          SizedBox(height: 12),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('letter_requests').doc(doc.id).update({
                'revisionNotes': notesCtrl.text,
                'status': 'pending',
              });
              _loadDocuments();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Revision request sent')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: Text('Send Revision Request'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text('$label:', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray))),
        Expanded(
          child: isStatus
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('letter_requests').doc(doc.id).delete();
              _loadDocuments();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

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
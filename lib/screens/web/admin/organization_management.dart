import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../theme/app_theme.dart'; // adjust path if needed
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// ---------- Data Models ----------
class Officer {
  final String id;
  final String name;
  final String position;
  final String email;
  Officer({required this.id, required this.name, required this.position, required this.email});
  factory Officer.fromMap(Map<String, dynamic> map) => Officer(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    position: map['position'] ?? '',
    email: map['email'] ?? '',
  );
}

class Organization {
  final String id;
  final String name;
  final String shortName;
  final String type;
  final String description;
  final String adviserName;
  final String adviserTitle;
  final String adviserEmail;
  final String logoUrl;
  final String status;
  final DateTime? createdAt;
  final List<String> categories;
  final List<Officer> officers;
  Organization({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.description,
    required this.adviserName,
    required this.adviserTitle,
    required this.adviserEmail,
    required this.logoUrl,
    required this.status,
    this.createdAt,
    required this.categories,
    required this.officers,
  });
}

// ---------- Main Widget ----------
class OrganizationManagement extends StatefulWidget {
  @override
  _OrganizationManagementState createState() => _OrganizationManagementState();
}

class _OrganizationManagementState extends State<OrganizationManagement> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // 'All' or 'Archived'
  String _typeFilter = 'All Types';
  Organization? _selectedOrganization;

  final List<String> _orgTypes = [
    'All Types',
    'Academic Organization',
    'Student Government',
    'Special Interest Group',
    'Cultural Organization',
    'Sports Organization',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: _selectedOrganization != null
          ? OrganizationDetailPage(
              organization: _selectedOrganization!,
              onBack: () => setState(() => _selectedOrganization = null),
            )
          : _buildOrganizationList(),
    );
  }

  Widget _buildOrganizationList() {
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organization Management',
                        style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
                    SizedBox(height: 4),
                    Text('Manage student organization status, advisers, and core details.',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateOrganizationDialog(),
                icon: Icon(Icons.add, size: 18),
                label: Text('Create Organization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: UpriseColors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Stats Cards (All and Archived)
        Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(child: _buildStatCard('All', _allOrgsStream, UpriseColors.primaryDark, Icons.business)),
              SizedBox(width: 16),
              Expanded(child: _buildStatCard('Archived', _archivedOrgsStream, UpriseColors.darkGray, Icons.archive)),
            ],
          ),
        ),

        // Search, Filter, Export Bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: 24),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: Row(
            children: [
              // Status Tabs (All / Archived)
              Row(
                children: [
                  _buildTabButton('All', _statusFilter == 'All'),
                  SizedBox(width: 8),
                  _buildTabButton('Archived', _statusFilter == 'Archived'),
                ],
              ),
              SizedBox(width: 16),
              // Type Filter Dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: UpriseColors.mediumGray),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<String>(
                  value: _typeFilter,
                  underline: SizedBox(),
                  icon: Icon(Icons.filter_list, size: 18, color: UpriseColors.darkGray),
                  items: _orgTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) => setState(() => _typeFilter = val!),
                ),
              ),
              SizedBox(width: 16),
              // Search Field
              Expanded(
                child: Container(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search organization, adviser...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                      prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                      filled: true,
                      fillColor: UpriseColors.lightGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Export Button
              OutlinedButton.icon(
                onPressed: () => _exportOrganizations(),
                icon: Icon(Icons.download, size: 18),
                label: Text('Export'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UpriseColors.darkGray,
                  side: BorderSide(color: UpriseColors.mediumGray),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Organizations Table
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                    color: UpriseColors.lightGray,
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('ORGANIZATION NAME', style: _headerStyle())),
                      Expanded(flex: 2, child: Text('ADVISER', style: _headerStyle())),
                      Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                      Expanded(flex: 1, child: Text('DATE CREATED', style: _headerStyle())),
                      Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                    ],
                  ),
                ),

                // Table Body (Firestore stream with filters)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('organizations').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business, size: 64, color: UpriseColors.mediumGray),
                              SizedBox(height: 16),
                              Text('No organizations found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                              SizedBox(height: 8),
                              Text('Click "Create Organization" to add one',
                                  style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      var docs = snapshot.data!.docs;
                      // Search filter
                      if (_searchController.text.isNotEmpty) {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name']?.toLowerCase() ?? '';
                          final adviser = data['adviserName']?.toLowerCase() ?? '';
                          final term = _searchController.text.toLowerCase();
                          return name.contains(term) || adviser.contains(term);
                        }).toList();
                      }
                      // Status filter (All / Archived)
                      if (_statusFilter == 'Archived') {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['status'] == 'archived';
                        }).toList();
                      } else {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['status'] != 'archived';
                        }).toList();
                      }
                      // Type filter
                      if (_typeFilter != 'All Types') {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['type'] == _typeFilter;
                        }).toList();
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final org = Organization(
                            id: docs[index].id,
                            name: data['name'] ?? '',
                            shortName: data['shortName'] ?? '',
                            type: data['type'] ?? '',
                            description: data['description'] ?? '',
                            adviserName: data['adviserName'] ?? 'No Adviser',
                            adviserTitle: data['adviserTitle'] ?? '',
                            adviserEmail: data['adviserEmail'] ?? '',
                            logoUrl: data['logoUrl'] ?? '',
                            status: data['status'] ?? 'active',
                            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                            categories: List<String>.from(data['categories'] ?? []),
                            officers: (data['officers'] as List?)?.map((e) => Officer.fromMap(e as Map<String, dynamic>)).toList() ?? [],
                          );
                          return _buildOrganizationRow(org);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  // Streams for stats cards
  Stream<QuerySnapshot> get _allOrgsStream => FirebaseFirestore.instance.collection('organizations').snapshots();
  Stream<QuerySnapshot> get _archivedOrgsStream => FirebaseFirestore.instance.collection('organizations').where('status', isEqualTo: 'archived').snapshots();

  Widget _buildStatCard(String title, Stream<QuerySnapshot> stream, Color color, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) count = snapshot.data!.docs.length;
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
                  Text(count.toString(), style: GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildTabButton(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? null : Border.all(color: UpriseColors.mediumGray),
        ),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? UpriseColors.white : UpriseColors.darkGray,
            )),
      ),
    );
  }

  Widget _buildOrganizationRow(Organization org) {
    return GestureDetector(
      onTap: () => setState(() => _selectedOrganization = org),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray))),
        child: Row(
          children: [
            // Organization Name + Type
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(org.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 14, color: UpriseColors.charcoal)),
                  SizedBox(height: 4),
                  Text(org.type, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
              ),
            ),
            // Adviser Name + Title
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(org.adviserName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: UpriseColors.charcoal)),
                  SizedBox(height: 2),
                  Text(org.adviserTitle.isNotEmpty ? org.adviserTitle : 'Faculty Adviser',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
              ),
            ),
            // Status badge
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: org.status == 'active' ? UpriseColors.success.withOpacity(0.1) : UpriseColors.darkGray.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  org.status.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: org.status == 'active' ? UpriseColors.success : UpriseColors.darkGray,
                  ),
                ),
              ),
            ),
            // Date Created
            Expanded(
              flex: 1,
              child: Text(
                org.createdAt != null ? _formatDate(org.createdAt!) : 'N/A',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
              ),
            ),
            // Action buttons
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: UpriseColors.darkGray),
                    onPressed: () => _showEditOrganizationDialog(org),
                  ),
                  IconButton(
                    icon: Icon(org.status == 'archived' ? Icons.restore_outlined : Icons.archive_outlined, size: 18, color: UpriseColors.darkGray),
                    onPressed: () => _toggleArchiveOrganization(org),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOrganizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateOrganizationDialog(onCreated: () => setState(() {})),
    );
  }

  void _showEditOrganizationDialog(Organization org) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditOrganizationDialog(organization: org, onUpdated: () => setState(() {})),
    );
  }

  Future<void> _toggleArchiveOrganization(Organization org) async {
    final isArchived = org.status == 'archived';
    final newStatus = isArchived ? 'active' : 'archived';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArchived ? 'Restore Organization' : 'Archive Organization'),
        content: Text('Are you sure you want to ${isArchived ? 'restore' : 'archive'} "${org.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('organizations').doc(org.id).update({'status': newStatus});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${org.name} has been ${isArchived ? 'restored' : 'archived'}')),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: isArchived ? UpriseColors.success : UpriseColors.primaryDark),
            child: Text(isArchived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
  }

  void _exportOrganizations() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export feature coming soon')));
  }

  String _formatDate(DateTime date) => '${_monthAbbr(date.month)} ${date.day}, ${date.year}';
  String _monthAbbr(int m) => ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][m-1];
}

// ---------- CREATE ORGANIZATION DIALOG ----------
class CreateOrganizationDialog extends StatefulWidget {
  final VoidCallback onCreated;
  CreateOrganizationDialog({required this.onCreated});
  @override
  _CreateOrganizationDialogState createState() => _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  String _type = 'Academic Organization';
  final _descCtrl = TextEditingController();
  final _advNameCtrl = TextEditingController();
  final _advTitleCtrl = TextEditingController();
  final _advEmailCtrl = TextEditingController();
  List<String> _categories = [];
  final _catCtrl = TextEditingController();
  File? _logoFile;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 560,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_business, color: UpriseColors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Create New Organization',
                        style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.white)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: UpriseColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Organization Logo', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              color: UpriseColors.lightGray,
                              border: Border.all(color: UpriseColors.mediumGray, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _logoFile != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_logoFile!, fit: BoxFit.cover))
                                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.cloud_upload, size: 32, color: UpriseColors.darkGray),
                                    SizedBox(height: 8),
                                    Text('Click to upload', style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                                  ]),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(labelText: 'Organization Name', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _shortNameCtrl,
                        decoration: InputDecoration(labelText: 'Short Name (e.g., SWITS)', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: InputDecoration(labelText: 'Organization Type', border: OutlineInputBorder()),
                        items: ['Academic Organization','Student Government','Special Interest Group','Cultural Organization','Sports Organization']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12),
                      Text('Categories', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._categories.map((c) => Chip(
                            label: Text(c),
                            onDeleted: () => setState(() => _categories.remove(c)),
                            backgroundColor: UpriseColors.lightGray,
                          )),
                          Container(
                            width: 120,
                            child: TextField(
                              controller: _catCtrl,
                              decoration: InputDecoration(
                                hintText: 'Add',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onSubmitted: (v) {
                                if (v.isNotEmpty && !_categories.contains(v)) {
                                  setState(() => _categories.add(v));
                                  _catCtrl.clear();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 32),
                      Text('Faculty Adviser', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      TextFormField(controller: _advNameCtrl, decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                      SizedBox(height: 12),
                      TextFormField(controller: _advTitleCtrl, decoration: InputDecoration(labelText: 'Title/Department', border: OutlineInputBorder())),
                      SizedBox(height: 12),
                      TextFormField(controller: _advEmailCtrl, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: UpriseColors.mediumGray))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: UpriseColors.darkGray))),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: UpriseColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: UpriseColors.white))
                        : Text('Create Organization'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('organizations').add({
        'name': _nameCtrl.text,
        'shortName': _shortNameCtrl.text,
        'type': _type,
        'description': _descCtrl.text,
        'adviserName': _advNameCtrl.text,
        'adviserTitle': _advTitleCtrl.text,
        'adviserEmail': _advEmailCtrl.text,
        'logoUrl': '',
        'status': 'active',
        'categories': _categories,
        'officers': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('activity_logs').add({
        'title': 'New Organization Created',
        'description': '${_nameCtrl.text} was created',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Organization created successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ---------- EDIT ORGANIZATION DIALOG ----------
class EditOrganizationDialog extends StatefulWidget {
  final Organization organization;
  final VoidCallback onUpdated;
  EditOrganizationDialog({required this.organization, required this.onUpdated});
  @override
  _EditOrganizationDialogState createState() => _EditOrganizationDialogState();
}

class _EditOrganizationDialogState extends State<EditOrganizationDialog> {
  late TextEditingController _nameCtrl, _shortCtrl, _typeCtrl, _descCtrl, _advNameCtrl, _advTitleCtrl, _advEmailCtrl;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.organization.name);
    _shortCtrl = TextEditingController(text: widget.organization.shortName);
    _typeCtrl = TextEditingController(text: widget.organization.type);
    _descCtrl = TextEditingController(text: widget.organization.description);
    _advNameCtrl = TextEditingController(text: widget.organization.adviserName);
    _advTitleCtrl = TextEditingController(text: widget.organization.adviserTitle);
    _advEmailCtrl = TextEditingController(text: widget.organization.adviserEmail);
    _status = widget.organization.status;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: UpriseColors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Edit Organization', style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.white)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: UpriseColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                  SizedBox(height: 12),
                  TextFormField(controller: _shortCtrl, decoration: InputDecoration(labelText: 'Short Name', border: OutlineInputBorder())),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _typeCtrl.text,
                    items: ['Academic Organization','Student Government','Special Interest Group','Cultural Organization','Sports Organization']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => _typeCtrl.text = v!,
                    decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: ['active','suspended','archived'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                    decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 12),
                  TextFormField(controller: _descCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                  SizedBox(height: 12),
                  TextFormField(controller: _advNameCtrl, decoration: InputDecoration(labelText: 'Adviser Name', border: OutlineInputBorder())),
                  SizedBox(height: 12),
                  TextFormField(controller: _advTitleCtrl, decoration: InputDecoration(labelText: 'Adviser Title', border: OutlineInputBorder())),
                  SizedBox(height: 12),
                  TextFormField(controller: _advEmailCtrl, decoration: InputDecoration(labelText: 'Adviser Email', border: OutlineInputBorder())),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: UpriseColors.mediumGray))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: UpriseColors.darkGray))),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _update,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: UpriseColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: UpriseColors.white))
                        : Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _update() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.organization.id).update({
        'name': _nameCtrl.text,
        'shortName': _shortCtrl.text,
        'type': _typeCtrl.text,
        'description': _descCtrl.text,
        'adviserName': _advNameCtrl.text,
        'adviserTitle': _advTitleCtrl.text,
        'adviserEmail': _advEmailCtrl.text,
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      widget.onUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Organization updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ---------- ORGANIZATION DETAIL PAGE (Fully dynamic, no hardcoded data) ----------
class OrganizationDetailPage extends StatefulWidget {
  final Organization organization;
  final VoidCallback onBack;

  const OrganizationDetailPage({Key? key, required this.organization, required this.onBack}) : super(key: key);

  @override
  _OrganizationDetailPageState createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage> {
  late ScrollController _scrollController;
  final GlobalKey _atGlanceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAtGlance() {
    Scrollable.ensureVisible(
      _atGlanceKey.currentContext!,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _archiveOrganization() async {
    final isArchived = widget.organization.status == 'archived';
    final newStatus = isArchived ? 'active' : 'archived';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArchived ? 'Restore Organization' : 'Archive Organization'),
        content: Text('Are you sure you want to ${isArchived ? 'restore' : 'archive'} "${widget.organization.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isArchived ? UpriseColors.success : UpriseColors.primaryDark),
            child: Text(isArchived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.organization.id).update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.organization.name} has been ${isArchived ? 'restored' : 'archived'}')),
      );
      widget.onBack(); // Go back to list to refresh
    }
  }

  void _manageOfficers() {
    // TODO: Navigate to Officers Management screen
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manage Officers feature coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back, color: UpriseColors.darkGray),
            onPressed: widget.onBack,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          SizedBox(height: 16),

          // Header Card
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo placeholder
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: UpriseColors.lightGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: widget.organization.logoUrl.isNotEmpty
                      ? Image.network(widget.organization.logoUrl, fit: BoxFit.cover)
                      : Icon(Icons.business, size: 50, color: UpriseColors.primaryDark),
                ),
                SizedBox(width: 24),
                // Title & type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.organization.name,
                        style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${widget.organization.type} • College of Information and Communications Technology',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                      ),
                      SizedBox(height: 16),
                      // Status badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.organization.status == 'active'
                              ? UpriseColors.success.withOpacity(0.1)
                              : UpriseColors.darkGray.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.organization.status.toUpperCase(),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.organization.status == 'active' ? UpriseColors.success : UpriseColors.darkGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _archiveOrganization,
                      icon: Icon(widget.organization.status == 'archived' ? Icons.restore_outlined : Icons.archive_outlined, size: 18),
                      label: Text(widget.organization.status == 'archived' ? 'Restore' : 'Archive'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.white,
                        foregroundColor: UpriseColors.darkGray,
                        side: BorderSide(color: UpriseColors.mediumGray),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _scrollToAtGlance,
                      icon: Icon(Icons.analytics_outlined, size: 18),
                      label: Text('At a Glance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.white,
                        foregroundColor: UpriseColors.darkGray,
                        side: BorderSide(color: UpriseColors.mediumGray),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _manageOfficers,
                      icon: Icon(Icons.people_outline, size: 18),
                      label: Text('Manage Officers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
                        foregroundColor: UpriseColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _infoCard(
                      'ABOUT THE ORGANIZATION',
                      Icons.info_outline,
                      Text(
                        widget.organization.description.isNotEmpty ? widget.organization.description : 'No description provided.',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, height: 1.5, color: UpriseColors.darkGray),
                      ),
                    ),
                    SizedBox(height: 24),
                    _infoCard(
                      'FACULTY ADVISER',
                      Icons.school_outlined,
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: UpriseColors.lightGray,
                            radius: 32,
                            child: Text(
                              widget.organization.adviserName.isNotEmpty
                                  ? widget.organization.adviserName.split(' ').map((e) => e[0]).take(2).join()
                                  : 'NA',
                              style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.organization.adviserName.isNotEmpty ? widget.organization.adviserName : 'No Adviser Assigned',
                                  style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  widget.organization.adviserTitle.isNotEmpty ? widget.organization.adviserTitle : 'Department of Computer Science',
                                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                                ),
                                if (widget.organization.adviserEmail.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    widget.organization.adviserEmail,
                                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.primaryDark),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    // AT A GLANCE section (dynamic)
                    Container(
                      key: _atGlanceKey,
                      child: _buildAtGlanceStats(),
                    ),
                    SizedBox(height: 24),
                    _infoCard(
                      'CATEGORIES',
                      Icons.label_outline,
                      Wrap(
                        spacing: 8,
                        children: widget.organization.categories.isEmpty
                            ? [Text('No categories added', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray))]
                            : widget.organization.categories.map((cat) => Chip(
                                label: Text(cat, style: GoogleFonts.beVietnamPro(fontSize: 12)),
                                backgroundColor: UpriseColors.lightGray,
                              )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24),
              // RIGHT COLUMN
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _infoCard(
                      'CURRENT OFFICERS (2025-2026)',
                      Icons.people_outline,
                      widget.organization.officers.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text('No officers assigned yet', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                            )
                          : Column(
                              children: widget.organization.officers.map((o) => Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(o.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 14)),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: UpriseColors.lightGray,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        o.position.toUpperCase(),
                                        style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                    ),
                    SizedBox(height: 24),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- DYNAMIC "AT A GLANCE" STATS (Live from Firestore) -----
  Widget _buildAtGlanceStats() {
    return Column(
      children: [
        _infoCard(
          'AT A GLANCE',
          Icons.timeline_outlined,
          StreamBuilder<Map<String, int>>(
            stream: _fetchOrganizationStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Error loading stats', style: GoogleFonts.beVietnamPro(color: UpriseColors.error)),
                );
              }
              final stats = snapshot.data ?? {'events': 0, 'pending': 0, 'achievements': 0};
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.event, 'Events Held', stats['events']!.toString()),
                  _statItem(Icons.pending_actions, 'Pending Req', stats['pending']!.toString()),
                  _statItem(Icons.emoji_events, 'Achievements', stats['achievements']!.toString()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<Map<String, int>> _fetchOrganizationStats() async* {
    // Get completed events count
    final eventsQuery = await FirebaseFirestore.instance
        .collection('events')
        .where('organizationId', isEqualTo: widget.organization.id)
        .where('status', isEqualTo: 'completed')
        .count()
        .get();
    final eventsCount = eventsQuery.count;

    // Get pending event proposals count
    final proposalsQuery = await FirebaseFirestore.instance
        .collection('event_proposals')
        .where('organizationId', isEqualTo: widget.organization.id)
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    final pendingCount = proposalsQuery.count;

    // Get achievements count (assuming an 'achievements' collection)
    final achievementsQuery = await FirebaseFirestore.instance
        .collection('achievements')
        .where('organizationId', isEqualTo: widget.organization.id)
        .count()
        .get();
    final achievementsCount = achievementsQuery.count;

    yield {
      'events': ?eventsCount,
      'pending': ?pendingCount,
      'achievements': ?achievementsCount,
    };
  }

  // ----- RECENT ACTIVITY (Live stream) -----
  Widget _buildRecentActivity() {
    return _infoCard(
      'RECENT ACTIVITY',
      Icons.history,
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .where('organizationId', isEqualTo: widget.organization.id)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No recent activity', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray), textAlign: TextAlign.center),
            );
          }
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _activityItem(
                data['title'] ?? 'Activity',
                data['description'] ?? '',
                data['createdAt'] as Timestamp?,
              );
            }).toList(),
          );
        },
      ),
      footer: TextButton(
        onPressed: () {},
        child: Text('View History', style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark)),
      ),
    );
  }

  // Helper widgets
  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: UpriseColors.primaryDark, size: 28),
        SizedBox(height: 8),
        Text(value, style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
      ],
    );
  }

  Widget _infoCard(String title, IconData icon, Widget child, {Widget? footer}) {
    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: UpriseColors.primaryDark),
                SizedBox(width: 12),
                Text(title, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: UpriseColors.darkGray, letterSpacing: 0.5)),
              ],
            ),
          ),
          Divider(height: 0, color: UpriseColors.mediumGray),
          Padding(padding: EdgeInsets.all(16), child: child),
          if (footer != null) ...[
            Divider(height: 0, color: UpriseColors.mediumGray),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: footer),
          ],
        ],
      ),
    );
  }

  Widget _activityItem(String title, String subtitle, Timestamp? ts) {
    String time = _formatTimeAgo(ts);
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: UpriseColors.lightGray, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.event_available, color: UpriseColors.primaryDark, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 13)),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
                SizedBox(height: 2),
                Text(time, style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(Timestamp? ts) {
    if (ts == null) return 'Just now';
    DateTime date = ts.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() == 1 ? '' : 's'} ago';
  }
}
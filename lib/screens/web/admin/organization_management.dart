import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../theme/app_theme.dart';

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
  String _filterType = 'All';
  Organization? _selectedOrganization;

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
                    Text(
                      'Organization Management',
                      style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage student organization status, advisers, and core details.',
                      style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                    ),
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

        // Stats Cards (dynamic from Firestore)
        Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(child: _buildStatsCardStream('Total Organizations', _allOrgsStream, UpriseColors.primaryDark, Icons.business)),
              SizedBox(width: 16),
              Expanded(child: _buildStatsCardStream('Active', _activeOrgsStream, UpriseColors.success, Icons.check_circle)),
              SizedBox(width: 16),
              Expanded(child: _buildStatsCardStream('Suspended', _suspendedOrgsStream, UpriseColors.warning, Icons.warning)),
              SizedBox(width: 16),
              Expanded(child: _buildStatsCardStream('Archived', _archivedOrgsStream, UpriseColors.darkGray, Icons.archive)),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Search, Filter and Export Bar
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ),
              SizedBox(width: 16),
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => _filterType = value),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'All', child: Text('All')),
                  PopupMenuItem(value: 'Archived', child: Text('Archived')),
                ],
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: UpriseColors.mediumGray),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 18, color: UpriseColors.darkGray),
                      SizedBox(width: 6),
                      Text('Filter', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
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
                      Expanded(flex: 2, child: Text('FACULTY ADVISER', style: _headerStyle())),
                      Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                      Expanded(flex: 1, child: Text('DATE CREATED', style: _headerStyle())),
                      Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                    ],
                  ),
                ),

                // Table Body - Firestore Data
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('organizations')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
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
                      // Archived filter
                      if (_filterType == 'Archived') {
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
                            officers: (data['officers'] as List?)
                                    ?.map((e) => Officer.fromMap(e as Map<String, dynamic>))
                                    .toList() ??
                                [],
                          );
                          return _buildOrganizationRow(org);
                        },
                      );
                    },
                  ),
                ),

                // Pagination Info
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
                    color: UpriseColors.lightGray,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Showing results', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                      Row(
                        children: [
                          IconButton(icon: Icon(Icons.chevron_left, size: 20), onPressed: () {}),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: UpriseColors.primaryDark,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('1', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          IconButton(icon: Icon(Icons.chevron_right, size: 20), onPressed: () {}),
                        ],
                      ),
                    ],
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

  // Streams for stats cards (live counts)
  Stream<QuerySnapshot> get _allOrgsStream => FirebaseFirestore.instance.collection('organizations').snapshots();
  Stream<QuerySnapshot> get _activeOrgsStream => FirebaseFirestore.instance.collection('organizations').where('status', isEqualTo: 'active').snapshots();
  Stream<QuerySnapshot> get _suspendedOrgsStream => FirebaseFirestore.instance.collection('organizations').where('status', isEqualTo: 'suspended').snapshots();
  Stream<QuerySnapshot> get _archivedOrgsStream => FirebaseFirestore.instance.collection('organizations').where('status', isEqualTo: 'archived').snapshots();

  Widget _buildStatsCardStream(String title, Stream<QuerySnapshot> stream, Color color, IconData icon) {
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
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
                  Text(
                    count.toString(),
                    style: GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.beVietnamPro(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: UpriseColors.darkGray,
      letterSpacing: 0.5,
    );
  }

  Widget _buildOrganizationRow(Organization org) {
    return GestureDetector(
      onTap: () => setState(() => _selectedOrganization = org),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
        ),
        child: Row(
          children: [
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
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(org.adviserName, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal)),
                  SizedBox(height: 2),
                  Text(org.adviserTitle, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: org.status == 'active' ? UpriseColors.success.withOpacity(0.1) : UpriseColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  org.status.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: org.status == 'active' ? UpriseColors.success : UpriseColors.warning,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                org.createdAt != null ? _formatDate(org.createdAt!) : 'N/A',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
              ),
            ),
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

// ---------- CREATE ORGANIZATION DIALOG (with UPRISE colors) ----------
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
  final _typeCtrl = TextEditingController();
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
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: UpriseColors.primaryDark),
              child: Row(
                children: [
                  Icon(Icons.add_business, color: UpriseColors.white, size: 24),
                  SizedBox(width: 12),
                  Text('Create New Organization', style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.white)),
                  Spacer(),
                  IconButton(icon: Icon(Icons.close, color: UpriseColors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Logo upload (simplified)
                      Text('Organization Logo', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            color: UpriseColors.lightGray,
                            border: Border.all(color: UpriseColors.mediumGray),
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
                      SizedBox(height: 20),
                      TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Organization Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                      SizedBox(height: 12),
                      TextFormField(controller: _shortNameCtrl, decoration: InputDecoration(labelText: 'Short Name (e.g., SWITS)')),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _typeCtrl.text.isNotEmpty ? _typeCtrl.text : null,
                        decoration: InputDecoration(labelText: 'Organization Type'),
                        items: ['Academic Organization','Student Government','Special Interest Group','Cultural Organization','Sports Organization']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => _typeCtrl.text = v!,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      SizedBox(height: 12),
                      TextFormField(controller: _descCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Description')),
                      SizedBox(height: 12),
                      Text('Categories', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                      Wrap(
                        spacing: 8,
                        children: [
                          ..._categories.map((c) => Chip(label: Text(c), onDeleted: () => setState(() => _categories.remove(c)))),
                          Container(
                            width: 120,
                            child: TextField(
                              controller: _catCtrl,
                              decoration: InputDecoration(hintText: 'Add', border: OutlineInputBorder()),
                              onSubmitted: (v) { if(v.isNotEmpty) setState(() => _categories.add(v)); _catCtrl.clear(); },
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 32),
                      Text('Faculty Adviser', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      TextFormField(controller: _advNameCtrl, decoration: InputDecoration(labelText: 'Full Name')),
                      SizedBox(height: 12),
                      TextFormField(controller: _advTitleCtrl, decoration: InputDecoration(labelText: 'Title/Department')),
                      SizedBox(height: 12),
                      TextFormField(controller: _advEmailCtrl, decoration: InputDecoration(labelText: 'Email')),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _create,
                    style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                    child: _isLoading ? SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:UpriseColors.white)) : Text('Create Organization'),
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
        'type': _typeCtrl.text,
        'description': _descCtrl.text,
        'adviserName': _advNameCtrl.text,
        'adviserTitle': _advTitleCtrl.text,
        'adviserEmail': _advEmailCtrl.text,
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
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              color: UpriseColors.primaryDark,
              child: Row(
                children: [
                  Icon(Icons.edit, color: UpriseColors.white),
                  SizedBox(width: 12),
                  Text('Edit Organization', style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: UpriseColors.white)),
                  Spacer(),
                  IconButton(icon: Icon(Icons.close, color: UpriseColors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Name')),
                  SizedBox(height: 12),
                  TextFormField(controller: _shortCtrl, decoration: InputDecoration(labelText: 'Short Name')),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _typeCtrl.text,
                    items: ['Academic Organization','Student Government','Special Interest Group','Cultural Organization','Sports Organization']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => _typeCtrl.text = v!,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: ['active','suspended','archived'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  SizedBox(height: 12),
                  TextFormField(controller: _descCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Description')),
                  SizedBox(height: 12),
                  TextFormField(controller: _advNameCtrl, decoration: InputDecoration(labelText: 'Adviser Name')),
                  SizedBox(height: 12),
                  TextFormField(controller: _advTitleCtrl, decoration: InputDecoration(labelText: 'Adviser Title')),
                  SizedBox(height: 12),
                  TextFormField(controller: _advEmailCtrl, decoration: InputDecoration(labelText: 'Adviser Email')),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _update,
                    style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                    child: _isLoading ? SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:UpriseColors.white)) : Text('Save Changes'),
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

// ---------- ORGANIZATION DETAIL PAGE (UPRISE colors) ----------
class OrganizationDetailPage extends StatelessWidget {
  final Organization organization;
  final VoidCallback onBack;

  OrganizationDetailPage({required this.organization, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(icon: Icon(Icons.arrow_back, color: UpriseColors.darkGray), onPressed: onBack),
          SizedBox(height: 16),
          // Header
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
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(color: UpriseColors.lightGray, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.business, size: 50, color: UpriseColors.primaryDark),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(organization.name, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
                      SizedBox(height: 8),
                      Text('${organization.type} • College of Information and Communications Technology',
                          style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: organization.status == 'active' ? UpriseColors.success.withOpacity(0.1) : UpriseColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(organization.status.toUpperCase(),
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: organization.status == 'active' ? UpriseColors.success : UpriseColors.warning,
                            )),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _actionButton('Archive', Icons.archive_outlined, () {}),
                    SizedBox(height: 8),
                    _actionButton('At a Glance', Icons.analytics_outlined, () {}),
                    SizedBox(height: 8),
                    _actionButton('Manage Officers', Icons.people_outline, () {}, filled: true),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _infoCard('ABOUT THE ORGANIZATION', Icons.info_outline,
                        Text(organization.description.isNotEmpty ? organization.description : 'No description provided.',
                            style: GoogleFonts.beVietnamPro(fontSize: 14, height: 1.5, color: UpriseColors.darkGray))),
                    SizedBox(height: 24),
                    _infoCard('FACULTY ADVISER', Icons.school_outlined,
                        Row(children: [
                          CircleAvatar(
                            backgroundColor: UpriseColors.lightGray,
                            radius: 25,
                            child: Text(organization.adviserName.isNotEmpty ? organization.adviserName.split(' ').map((e) => e[0]).take(2).join() : 'NA',
                                style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark, fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(organization.adviserName.isNotEmpty ? organization.adviserName : 'No Adviser Assigned',
                                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 16)),
                                Text(organization.adviserTitle.isNotEmpty ? organization.adviserTitle : 'Department of Computer Science',
                                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                              ],
                            ),
                          ),
                        ])),
                    SizedBox(height: 24),
                    _infoCard('CATEGORIES', Icons.label_outline,
                        Wrap(spacing: 8, children: organization.categories.isEmpty
                            ? [Text('No categories added', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray))]
                            : organization.categories.map((cat) => Chip(label: Text(cat, style: GoogleFonts.beVietnamPro(fontSize: 12)), backgroundColor: UpriseColors.lightGray)).toList())),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _infoCard('CURRENT OFFICERS (2025-2026)', Icons.people_outline,
                        organization.officers.isEmpty
                            ? Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Text('No officers assigned yet', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)))
                            : Column(children: organization.officers.map((o) => Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(o.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                                    Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(color: UpriseColors.lightGray, borderRadius: BorderRadius.circular(12)),
                                      child: Text(o.position.toUpperCase(), style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark))),
                                  ],
                                ))).toList())),
                    SizedBox(height: 24),
                    _infoCard('RECENT ACTIVITY', Icons.history,
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('activity_logs')
                              .where('organizationId', isEqualTo: organization.id)
                              .orderBy('createdAt', descending: true).limit(3).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                            if (snapshot.data!.docs.isEmpty) return Padding(padding: EdgeInsets.symmetric(vertical: 32),
                                child: Text('No recent activity', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray), textAlign: TextAlign.center));
                            return Column(children: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _activityItem(data['title'] ?? 'Activity', data['description'] ?? '', data['createdAt'] as Timestamp?);
                            }).toList());
                          },
                        ),
                        footer: TextButton(onPressed: () {}, child: Text('View History', style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark)))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed, {bool filled = false}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: filled
          ? ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark, foregroundColor: UpriseColors.white)
          : ElevatedButton.styleFrom(backgroundColor: UpriseColors.white, foregroundColor: UpriseColors.darkGray, side: BorderSide(color: UpriseColors.mediumGray)),
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
          Padding(padding: EdgeInsets.all(16),
              child: Row(children: [Icon(icon, size: 20, color: UpriseColors.primaryDark), SizedBox(width: 12),
                Text(title, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: UpriseColors.darkGray, letterSpacing: 0.5))])),
          Divider(height: 0, color: UpriseColors.mediumGray),
          Padding(padding: EdgeInsets.all(16), child: child),
          if (footer != null) ...[Divider(height: 0, color: UpriseColors.mediumGray), Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: footer)],
        ],
      ),
    );
  }

  Widget _activityItem(String title, String subtitle, Timestamp? ts) {
    String time = _formatTimeAgo(ts);
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: UpriseColors.lightGray, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.event_available, color: UpriseColors.primaryDark, size: 18)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 13)),
            if (subtitle.isNotEmpty) ...[SizedBox(height: 2), Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray))],
            SizedBox(height: 2), Text(time, style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
          ])),
      ]),
    );
  }

  String _formatTimeAgo(Timestamp? ts) {
    if (ts == null) return 'Just now';
    DateTime date = ts.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }
}
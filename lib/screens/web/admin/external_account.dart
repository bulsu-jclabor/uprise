// lib/screens/admin/external_account.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class ExternalAccount extends StatefulWidget {
  @override
  _ExternalAccountState createState() => _ExternalAccountState();
}

class _ExternalAccountState extends State<ExternalAccount> {
  String _statusFilter = 'All'; // All, pending, approved, rejected
  final TextEditingController _searchController = TextEditingController();
  List<ExternalRequest> _allRequests = [];
  List<ExternalRequest> _filteredRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('external_requests')
          .orderBy('requestDate', descending: true)
          .get();
      _allRequests = snapshot.docs.map((doc) {
        final data = doc.data();
        return ExternalRequest(
          id: doc.id,
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? '',
          email: data['email'] ?? '',
          university: data['university'] ?? '',
          status: data['status'] ?? 'pending',
          requestDate: (data['requestDate'] as Timestamp).toDate(),
          purpose: data['purpose'] ?? '',
        );
      }).toList();
      _applyFilters();
    } catch (e) {
      print('Error loading requests: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _allRequests.where((req) {
        if (_statusFilter != 'All' && req.status != _statusFilter) return false;
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          return req.userName.toLowerCase().contains(term) ||
              req.email.toLowerCase().contains(term) ||
              req.university.toLowerCase().contains(term);
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    int total = _allRequests.length;
    int pending = _allRequests.where((r) => r.status == 'pending').length;
    int approved = _allRequests.where((r) => r.status == 'approved').length;
    int rejected = _allRequests.where((r) => r.status == 'rejected').length;

    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRequestDialog,
        backgroundColor: UpriseColors.primaryDark,
        child: Icon(Icons.add, color: UpriseColors.white),
        tooltip: 'Add External Account',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatsRow(total, pending, approved, rejected),
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
            'External Account Management',
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
          ),
          SizedBox(height: 4),
          Text(
            'Manage Non-CICT / Guest Accounts',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int total, int pending, int approved, int rejected) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Row(children: [
        _statCard('TOTAL REQUESTS', '$total', UpriseColors.primaryDark),
        SizedBox(width: 16),
        _statCard('PENDING', '$pending', UpriseColors.warning),
        SizedBox(width: 16),
        _statCard('APPROVED', '$approved', UpriseColors.success),
        SizedBox(width: 16),
        _statCard('REJECTED', '$rejected', UpriseColors.error),
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
    final tabs = ['All', 'Pending', 'Approved', 'Rejected'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Filter tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((tab) {
                  final selected = (_statusFilter == tab) ||
                      (tab == 'All' && _statusFilter == 'All') ||
                      (tab == 'Pending' && _statusFilter == 'pending') ||
                      (tab == 'Approved' && _statusFilter == 'approved') ||
                      (tab == 'Rejected' && _statusFilter == 'rejected');
                  return Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _filterChip(tab, selected, () {
                      setState(() {
                        if (tab == 'All') _statusFilter = 'All';
                        else if (tab == 'Pending') _statusFilter = 'pending';
                        else if (tab == 'Approved') _statusFilter = 'approved';
                        else if (tab == 'Rejected') _statusFilter = 'rejected';
                        _applyFilters();
                      });
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(width: 16),
          // Search field
          Container(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, email, university...',
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
    if (_filteredRequests.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_off, size: 64, color: UpriseColors.mediumGray),
          SizedBox(height: 16),
          Text('No external requests found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
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
        // Table Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: UpriseColors.lightGray,
            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(flex: 1, child: Text('ID', style: _headerStyle())),
            Expanded(flex: 2, child: Text('USER NAME', style: _headerStyle())),
            Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
            Expanded(flex: 1, child: Text('UNIVERSITY', style: _headerStyle())),
            Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
            Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
          ]),
        ),
        // Table Body
        Expanded(
          child: ListView.builder(
            itemCount: _filteredRequests.length,
            itemBuilder: (context, index) {
              final req = _filteredRequests[index];
              return _buildRow(req);
            },
          ),
        ),
        // Footer
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
              Text('Showing ${_filteredRequests.length} of ${_allRequests.length} requests',
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

  Widget _buildRow(ExternalRequest req) {
    final statusColor = req.status == 'approved' ? UpriseColors.success
        : req.status == 'rejected' ? UpriseColors.error
        : UpriseColors.warning;
    final formattedDate = DateFormat('yyyy-MM-dd HH').format(req.requestDate);
    // First two letters of name as ID (simplified)
    String shortId = req.userName.isNotEmpty ? req.userName.split(' ').map((e) => e[0]).take(2).join() : '??';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(flex: 1, child: Text(shortId, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(req.userName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 2),
          Text(req.email, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
        ])),
        Expanded(flex: 1, child: Text(formattedDate, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray))),
        Expanded(flex: 1, child: Text(req.university, style: GoogleFonts.beVietnamPro(fontSize: 12))),
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(req.status.toUpperCase(), textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ),
        Expanded(
          flex: 1,
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.visibility_outlined, size: 18, color: UpriseColors.darkGray),
              onPressed: () => _showDetails(req),
              tooltip: 'View Details',
            ),
            if (req.status == 'pending')
              IconButton(
                icon: Icon(Icons.check_circle_outline, size: 18, color: UpriseColors.success),
                onPressed: () => _setStatus(req.id, 'approved'),
                tooltip: 'Approve',
              ),
            if (req.status == 'pending')
              IconButton(
                icon: Icon(Icons.cancel_outlined, size: 18, color: UpriseColors.error),
                onPressed: () => _setStatus(req.id, 'rejected'),
                tooltip: 'Reject',
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: UpriseColors.error),
              onPressed: () => _confirmDelete(req),
              tooltip: 'Delete',
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _setStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('external_requests').doc(docId).update({'status': newStatus});
    _loadRequests();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request ${newStatus.toUpperCase()}')));
  }

  void _confirmDelete(ExternalRequest req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Request'),
        content: Text('Are you sure you want to delete the request from "${req.userName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('external_requests').doc(req.id).delete();
              _loadRequests();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDetails(ExternalRequest req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.person_outline, color: UpriseColors.primaryDark),
          SizedBox(width: 8),
          Expanded(child: Text(req.userName, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('Email', req.email),
            _detailRow('University/Organization', req.university),
            _detailRow('Request Date', DateFormat('MMM dd, yyyy hh:mm a').format(req.requestDate)),
            _detailRow('Purpose', req.purpose.isNotEmpty ? req.purpose : 'No purpose provided.'),
            _detailRow('Status', req.status.toUpperCase(), isStatus: true, statusColor: req.status == 'approved' ? UpriseColors.success : req.status == 'rejected' ? UpriseColors.error : UpriseColors.warning),
          ]),
        ),
        actions: [
          if (req.status == 'pending')
            TextButton.icon(
              onPressed: () async {
                await _setStatus(req.id, 'approved');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.check_circle, color: UpriseColors.success),
              label: Text('Approve', style: TextStyle(color: UpriseColors.success)),
            ),
          if (req.status == 'pending')
            TextButton.icon(
              onPressed: () async {
                await _setStatus(req.id, 'rejected');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.cancel, color: UpriseColors.error),
              label: Text('Reject', style: TextStyle(color: UpriseColors.error)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text('$label:', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray))),
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

  void _showCreateRequestDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final universityCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.person_add, color: UpriseColors.primaryDark),
          SizedBox(width: 8),
          Text('Create External Account Request', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                SizedBox(height: 12),
                TextFormField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email Address'), validator: (v) => v!.isEmpty || !v.contains('@') ? 'Valid email required' : null),
                SizedBox(height: 12),
                TextFormField(controller: universityCtrl, decoration: InputDecoration(labelText: 'University / Organization')),
                SizedBox(height: 12),
                TextFormField(controller: purposeCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Purpose of Access')),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await FirebaseFirestore.instance.collection('external_requests').add({
                  'userName': nameCtrl.text,
                  'email': emailCtrl.text,
                  'university': universityCtrl.text,
                  'purpose': purposeCtrl.text,
                  'status': 'pending',
                  'requestDate': FieldValue.serverTimestamp(),
                });
                _loadRequests();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request submitted')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}

class ExternalRequest {
  final String id;
  final String userId;
  final String userName;
  final String email;
  final String university;
  final String status;
  final DateTime requestDate;
  final String purpose;

  ExternalRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.university,
    required this.status,
    required this.requestDate,
    required this.purpose,
  });
}
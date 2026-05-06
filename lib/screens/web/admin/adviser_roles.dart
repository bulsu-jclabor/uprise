// lib/screens/admin/adviser_roles.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';


class OrgModel {
  final String id;
  final String name;
  final String abbrev;
  final String tag;
  OrgModel({required this.id, required this.name, required this.abbrev, required this.tag});
  factory OrgModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrgModel(
      id: doc.id,
      name: d['name'] ?? d['orgName'] ?? '',
      abbrev: d['abbrev'] ?? d['abbreviation'] ?? '',
      tag: d['tag'] ?? d['department'] ?? d['type'] ?? '',
    );
  }
}

class AdviserModel {
  final String id;
  final String name;
  final String email;
  final String rank;
  AdviserModel({required this.id, required this.name, required this.email, required this.rank});
  factory AdviserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdviserModel(
      id: doc.id,
      name: d['fullName'] ?? d['name'] ?? d['displayName'] ?? '',
      email: d['email'] ?? '',
      rank: d['rank'] ?? d['position'] ?? 'Instructor',
    );
  }
}

class AdviserRoles extends StatefulWidget {
  @override
  _AdviserRolesState createState() => _AdviserRolesState();
}

class _AdviserRolesState extends State<AdviserRoles> {
  final TextEditingController _searchController = TextEditingController();
  String _filterOrgId = 'All';
  String _filterAdviserId = 'All';
  bool _showArchived = false;
  int _currentPage = 1;
  static const int _pageSize = 10;

  List<OrgModel> _orgs = [];
  List<AdviserModel> _advisers = [];
  bool _loadingMeta = true;

  int _totalAdvisers = 0;
  int _totalOfficers = 0;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    try {
      final orgSnap = await FirebaseFirestore.instance.collection('organizations').get();
      final orgs = orgSnap.docs.map((d) => OrgModel.fromDoc(d)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final advSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'adviser')
          .get();
      final advisers = advSnap.docs.map((d) => AdviserModel.fromDoc(d)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final rolesSnap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('archived', isEqualTo: false)
          .get();
      int officers = 0;
      for (var doc in rolesSnap.docs) {
        final d = doc.data();
        if ((d['president'] ?? '').toString().trim().isNotEmpty) officers++;
        if ((d['vicePresident'] ?? '').toString().trim().isNotEmpty) officers++;
        if ((d['secretary'] ?? '').toString().trim().isNotEmpty) officers++;
      }

      setState(() {
        _orgs = orgs;
        _advisers = advisers;
        _totalAdvisers = rolesSnap.docs.length;
        _totalOfficers = officers;
        _loadingMeta = false;
      });
    } catch (e) {
      setState(() => _loadingMeta = false);
      debugPrint('loadMeta error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStats(),
          _buildToolbar(),
          SizedBox(height: 16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Adviser Roles', style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
            SizedBox(height: 4),
            Text('Manage key leadership roles for CICT student organizations.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
          ]),
          SizedBox(
            width: 260, height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                filled: true, fillColor: UpriseColors.lightGray,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (_) => setState(() => _currentPage = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(children: [
        _statCard(Icons.people_outline, Colors.orange, 'TOTAL ADVISERS', '$_totalAdvisers'),
        SizedBox(width: 16),
        _statCard(Icons.groups_outlined, Colors.green, 'TOTAL OFFICERS', '$_totalOfficers'),
      ]),
    );
  }

  Widget _statCard(IconData icon, Color color, String label, String value) {
    return Container(
      padding: EdgeInsets.all(20),
      constraints: BoxConstraints(minWidth: 180),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          SizedBox(height: 4),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
        ]),
      ]),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(children: [
        _tabBtn('All', !_showArchived, () => setState(() { _showArchived = false; _currentPage = 1; })),
        SizedBox(width: 8),
        _tabBtn('Archived', _showArchived, () => setState(() { _showArchived = true; _currentPage = 1; })),
        SizedBox(width: 16),
        _dropdownFilter<String>(
          hint: 'Filter by Org',
          value: _filterOrgId == 'All' ? null : _filterOrgId,
          items: [
            DropdownMenuItem(value: null, child: Text('All Orgs')),
            ..._orgs.map((o) => DropdownMenuItem(value: o.id, child: Text(o.abbrev.isNotEmpty ? o.abbrev : o.name))),
          ],
          onChanged: (v) => setState(() { _filterOrgId = v ?? 'All'; _currentPage = 1; }),
        ),
        SizedBox(width: 8),
        _dropdownFilter<String>(
          hint: 'Filter by Adviser',
          value: _filterAdviserId == 'All' ? null : _filterAdviserId,
          items: [
            DropdownMenuItem(value: null, child: Text('All Advisers')),
            ..._advisers.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
          ],
          onChanged: (v) => setState(() { _filterAdviserId = v ?? 'All'; _currentPage = 1; }),
        ),
        Spacer(),
        OutlinedButton.icon(
          onPressed: _exportCSV,
          icon: Icon(Icons.download, size: 16),
          label: Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: UpriseColors.primaryDark,
            side: BorderSide(color: UpriseColors.mediumGray),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _loadingMeta ? null : _showAddDialog,
          icon: Icon(Icons.add, size: 16),
          label: Text('Assign Adviser Role'),
          style: ElevatedButton.styleFrom(
            backgroundColor: UpriseColors.primaryDark,
            foregroundColor: UpriseColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }

  Widget _tabBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.beVietnamPro(
          fontSize: 14, fontWeight: FontWeight.w500,
          color: selected ? Colors.white : UpriseColors.darkGray,
        )),
      ),
    );
  }

  Widget _dropdownFilter<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: UpriseColors.darkGray),
        ),
      ),
    );
  }

  Widget _buildTable() {
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
            Expanded(flex: 3, child: Text('ORGANIZATION', style: _hStyle())),
            Expanded(flex: 2, child: Text('ADVISER', style: _hStyle())),
            Expanded(flex: 2, child: Text('PRESIDENT', style: _hStyle())),
            Expanded(flex: 2, child: Text('VICE PRESIDENT', style: _hStyle())),
            Expanded(flex: 2, child: Text('SECRETARY', style: _hStyle())),
            Expanded(flex: 1, child: Text('ACTIONS', style: _hStyle())),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('adviser_roles')
                .where('archived', isEqualTo: _showArchived)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }

              var docs = snap.data?.docs ?? [];

              final term = _searchController.text.toLowerCase();
              if (term.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['orgName'] ?? '').toString().toLowerCase().contains(term) ||
                      (data['orgAbbrev'] ?? '').toString().toLowerCase().contains(term) ||
                      (data['adviserName'] ?? '').toString().toLowerCase().contains(term);
                }).toList();
              }
              if (_filterOrgId != 'All') {
                docs = docs.where((d) => (d.data() as Map)['orgId'] == _filterOrgId).toList();
              }
              if (_filterAdviserId != 'All') {
                docs = docs.where((d) => (d.data() as Map)['adviserId'] == _filterAdviserId).toList();
              }

              if (docs.isEmpty) return _emptyState();

              final totalPages = (docs.length / _pageSize).ceil().clamp(1, 999);
              final safePage = _currentPage.clamp(1, totalPages);
              final start = (safePage - 1) * _pageSize;
              final end = (start + _pageSize).clamp(0, docs.length);
              final pageDocs = docs.sublist(start, end);

              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: pageDocs.length,
                    itemBuilder: (_, i) {
                      final data = pageDocs[i].data() as Map<String, dynamic>;
                      return _buildRow(data, pageDocs[i].id);
                    },
                  ),
                ),
                _buildFooter(docs.length, totalPages, start, end),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  TextStyle _hStyle() => GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildRow(Map<String, dynamic> data, String docId) {
    final rank = data['adviserRank'] ?? 'Instructor';
    final rankColor = _rankColor(rank);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(flex: 3, child: Row(children: [
          _orgAvatar(data['orgAbbrev'] ?? '??'),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['orgName'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
            if ((data['orgTag'] ?? '').toString().isNotEmpty)
              Text(data['orgTag'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
          ])),
        ])),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['adviserName'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal)),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: rankColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(rank, style: GoogleFonts.beVietnamPro(fontSize: 11, color: rankColor, fontWeight: FontWeight.w600)),
          ),
        ])),
        Expanded(flex: 2, child: Text(data['president'] ?? '—', style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(flex: 2, child: Text(data['vicePresident'] ?? '—', style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(flex: 2, child: Text(data['secretary'] ?? '—', style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(flex: 1, child: Row(children: [
          IconButton(icon: Icon(Icons.remove_red_eye_outlined, size: 18, color: UpriseColors.darkGray), onPressed: () => _showViewDialog(data, docId), tooltip: 'View'),
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: UpriseColors.primaryDark), onPressed: () => _showEditDialog(data, docId), tooltip: 'Edit'),
          IconButton(icon: Icon(Icons.delete_outline, size: 18, color: UpriseColors.error), onPressed: () => _confirmDelete(docId, data['orgName'] ?? ''), tooltip: 'Delete'),
        ])),
      ]),
    );
  }

  Widget _orgAvatar(String abbrev) {
    final label = abbrev.length > 2 ? abbrev.substring(0, 2) : abbrev;
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: UpriseColors.primaryDark.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.bold, color: UpriseColors.primaryDark)),
    );
  }

  Color _rankColor(String rank) {
    switch (rank) {
      case 'Senior': return Colors.blue;
      case 'Junior': return Colors.orange;
      case 'Professor': return Colors.purple;
      default: return Colors.green;
    }
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.supervisor_account_outlined, size: 64, color: UpriseColors.mediumGray),
      SizedBox(height: 16),
      Text(_showArchived ? 'No archived records' : 'No adviser roles assigned yet',
          style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 15)),
    ]));
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
        color: UpriseColors.lightGray,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total organizations',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
        Row(children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: 20),
            color: _currentPage > 1 ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          ...List.generate(totalPages, (i) {
            final page = i + 1;
            final sel = page == _currentPage;
            return GestureDetector(
              onTap: () => setState(() => _currentPage = page),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? UpriseColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$page', style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: sel ? Colors.white : UpriseColors.charcoal,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                )),
              ),
            );
          }),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 20),
            color: _currentPage < totalPages ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ]),
      ]),
    );
  }

  // ─── Add / Edit dialog ──────────────────────────────────────

  void _showAddDialog() => _showFormDialog(isEdit: false, docId: null, existing: null);
  void _showEditDialog(Map<String, dynamic> data, String docId) => _showFormDialog(isEdit: true, docId: docId, existing: data);

  void _showFormDialog({required bool isEdit, required String? docId, required Map<String, dynamic>? existing}) {
    OrgModel? selectedOrg = isEdit
        ? _orgs.cast<OrgModel?>().firstWhere((o) => o?.id == existing?['orgId'], orElse: () => null)
        : null;
    AdviserModel? selectedAdviser = isEdit
        ? _advisers.cast<AdviserModel?>().firstWhere((a) => a?.id == existing?['adviserId'], orElse: () => null)
        : null;

    final adviserSearchCtrl = TextEditingController();
    List<AdviserModel> filteredAdvisers = List.from(_advisers);

    final presCtrl = TextEditingController(text: existing?['president'] ?? '');
    final vpCtrl = TextEditingController(text: existing?['vicePresident'] ?? '');
    final secCtrl = TextEditingController(text: existing?['secretary'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool isSaving = false;
          String? errorMsg;

          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            if (selectedOrg == null) { setDlg(() => errorMsg = 'Please select an organization.'); return; }
            if (selectedAdviser == null) { setDlg(() => errorMsg = 'Please select an adviser.'); return; }
            setDlg(() { isSaving = true; errorMsg = null; });
            try {
              final payload = <String, dynamic>{
                'orgId': selectedOrg!.id,
                'orgName': selectedOrg!.name,
                'orgAbbrev': selectedOrg!.abbrev,
                'orgTag': selectedOrg!.tag,
                'adviserId': selectedAdviser!.id,
                'adviserName': selectedAdviser!.name,
                'adviserEmail': selectedAdviser!.email,
                'adviserRank': selectedAdviser!.rank,
                'president': presCtrl.text.trim(),
                'vicePresident': vpCtrl.text.trim(),
                'secretary': secCtrl.text.trim(),
                'archived': false,
              };
              if (isEdit && docId != null) {
                await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).update(payload);
              } else {
                final dup = await FirebaseFirestore.instance
                    .collection('adviser_roles')
                    .where('orgId', isEqualTo: selectedOrg!.id)
                    .where('archived', isEqualTo: false)
                    .get();
                if (dup.docs.isNotEmpty) {
                  setDlg(() { isSaving = false; errorMsg = '${selectedOrg!.name} already has an active adviser role assigned.'; });
                  return;
                }
                payload['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance.collection('adviser_roles').add(payload);
              }
              _loadMeta();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Adviser role updated.' : 'Adviser role assigned.')));
            } catch (e) {
              setDlg(() { isSaving = false; errorMsg = e.toString(); });
            }
          }

          return AlertDialog(
            title: Row(children: [
              Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline, color: UpriseColors.primaryDark),
              SizedBox(width: 8),
              Text(isEdit ? 'Edit Adviser Role' : 'Assign Adviser Role',
                  style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Organization picker
                    _sectionLabel('Organization'),
                    SizedBox(height: 8),
                    DropdownButtonFormField<OrgModel>(
                      value: selectedOrg,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Organization',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: _orgs.map((o) => DropdownMenuItem(
                        value: o,
                        child: Row(children: [
                          _orgAvatar(o.abbrev.isNotEmpty ? (o.abbrev.length > 2 ? o.abbrev.substring(0,2) : o.abbrev) : (o.name.length > 2 ? o.name.substring(0,2) : o.name)),
                          SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(o.name, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                            if (o.tag.isNotEmpty) Text(o.tag, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                          ])),
                        ]),
                      )).toList(),
                      onChanged: isEdit ? null : (v) => setDlg(() => selectedOrg = v),
                      validator: (_) => selectedOrg == null ? 'Select an organization' : null,
                    ),
                    if (_orgs.isEmpty)
                      Padding(padding: EdgeInsets.only(top: 6),
                          child: Text('No organizations found in DB.', style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.error))),

                    SizedBox(height: 20),

                    // Adviser picker with search
                    _sectionLabel('Adviser'),
                    SizedBox(height: 8),
                    TextField(
                      controller: adviserSearchCtrl,
                      decoration: InputDecoration(
                        labelText: 'Search Adviser',
                        hintText: 'Type name or email...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onChanged: (q) => setDlg(() {
                        filteredAdvisers = _advisers.where((a) =>
                            a.name.toLowerCase().contains(q.toLowerCase()) ||
                            a.email.toLowerCase().contains(q.toLowerCase())).toList();
                      }),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedAdviser != null ? UpriseColors.primaryDark : UpriseColors.mediumGray),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: filteredAdvisers.isEmpty
                          ? Center(child: Text('No advisers found', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)))
                          : ListView.builder(
                              itemCount: filteredAdvisers.length,
                              itemBuilder: (_, i) {
                                final a = filteredAdvisers[i];
                                final sel = selectedAdviser?.id == a.id;
                                return ListTile(
                                  dense: true,
                                  selected: sel,
                                  selectedTileColor: UpriseColors.primaryDark.withOpacity(0.08),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: UpriseColors.primaryDark.withOpacity(0.12),
                                    child: Text(a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                                        style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.primaryDark, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(a.name, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500)),
                                  subtitle: Text('${a.email}  •  ${a.rank}', style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                                  trailing: sel ? Icon(Icons.check_circle, color: UpriseColors.primaryDark, size: 18) : null,
                                  onTap: () => setDlg(() => selectedAdviser = a),
                                );
                              },
                            ),
                    ),
                    if (_advisers.isEmpty)
                      Padding(padding: EdgeInsets.only(top: 6),
                          child: Text('No advisers found. Ensure users with role="adviser" exist in Firestore.',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.error))),

                    SizedBox(height: 20),

                    // Officers
                    _sectionLabel('Officers'),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: presCtrl,
                      decoration: InputDecoration(labelText: 'President', prefixIcon: Icon(Icons.person_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: vpCtrl,
                      decoration: InputDecoration(labelText: 'Vice President', prefixIcon: Icon(Icons.person_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: secCtrl,
                      decoration: InputDecoration(labelText: 'Secretary', prefixIcon: Icon(Icons.person_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),

                    if (errorMsg != null) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(color: UpriseColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(Icons.error_outline, size: 16, color: UpriseColors.error),
                          SizedBox(width: 8),
                          Expanded(child: Text(errorMsg!, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.error))),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                child: isSaving
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Assign Role', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5));

  // ─── View Dialog ────────────────────────────────────────────

  void _showViewDialog(Map<String, dynamic> data, String docId) {
    final rank = data['adviserRank'] ?? 'Instructor';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          _orgAvatar(data['orgAbbrev'] ?? '??'),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['orgName'] ?? '', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold, fontSize: 16)),
            if ((data['orgTag'] ?? '').toString().isNotEmpty)
              Text(data['orgTag'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
          ])),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _viewSection('Adviser', [
              _vRow('Name', data['adviserName'] ?? '—'),
              _vRow('Email', data['adviserEmail'] ?? '—'),
              _vRowBadge('Rank', rank, _rankColor(rank)),
            ]),
            SizedBox(height: 12),
            _viewSection('Officers', [
              _vRow('President', data['president'] ?? '—'),
              _vRow('Vice President', data['vicePresident'] ?? '—'),
              _vRow('Secretary', data['secretary'] ?? '—'),
            ]),
          ]),
        ),
        actions: [
          if (!(data['archived'] ?? false))
            TextButton.icon(
              onPressed: () { Navigator.pop(ctx); _confirmArchive(docId, data['orgName'] ?? ''); },
              icon: Icon(Icons.archive_outlined, size: 16, color: UpriseColors.darkGray),
              label: Text('Archive', style: TextStyle(color: UpriseColors.darkGray)),
            ),
          if (data['archived'] == true)
            TextButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).update({'archived': false});
                _loadMeta();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record restored.')));
              },
              icon: Icon(Icons.unarchive_outlined, size: 16, color: Colors.green),
              label: Text('Restore', style: TextStyle(color: Colors.green)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _showEditDialog(data, docId); },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: Text('Edit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _viewSection(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: UpriseColors.lightGray, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5)),
        SizedBox(height: 8),
        ...rows,
      ]),
    );
  }

  Widget _vRow(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
      Flexible(child: Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
    ]),
  );

  Widget _vRowBadge(String label, String value, Color color) => Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(value, style: GoogleFonts.beVietnamPro(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  // ─── Archive / Delete ───────────────────────────────────────

  void _confirmArchive(String docId, String orgName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive Record'),
        content: Text('Archive "$orgName"? It will be moved to the Archived tab.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).update({'archived': true});
              _loadMeta();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record archived.')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String docId, String orgName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: UpriseColors.error),
          SizedBox(width: 8),
          Text('Delete Record'),
        ]),
        content: Text('Permanently delete "$orgName"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('adviser_roles').doc(docId).delete();
              _loadMeta();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record deleted.'), backgroundColor: UpriseColors.error));
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Export ─────────────────────────────────────────────────

  Future<void> _exportCSV() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('archived', isEqualTo: _showArchived)
          .get();
      final lines = <String>['Organization,Abbreviation,Tag,Adviser,Adviser Email,Rank,President,Vice President,Secretary,Status'];
      for (var doc in snap.docs) {
        final d = doc.data();
        lines.add([
          d['orgName'] ?? '', d['orgAbbrev'] ?? '', d['orgTag'] ?? '',
          d['adviserName'] ?? '', d['adviserEmail'] ?? '', d['adviserRank'] ?? '',
          d['president'] ?? '', d['vicePresident'] ?? '', d['secretary'] ?? '',
          (d['archived'] ?? false) ? 'Archived' : 'Active',
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/adviser_roles_export.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Adviser Roles Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
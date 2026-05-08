import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';

// ============ ACTIVITY LOGGER ============
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Unknown User';
    await _firestore.collection('activity_logs').add({
      'user': userName,
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '',
      'details': details,
    });
  }
}

class ExternalAccount extends StatefulWidget {
  const ExternalAccount({super.key});

  @override
  _ExternalAccountState createState() => _ExternalAccountState();
}

class _ExternalAccountState extends State<ExternalAccount> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      // FloatingActionButton removed – external requests are submitted by users, not admin
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
                  'External Account Management',
                  style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage Non-CICT / Guest Accounts',
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
      stream: FirebaseFirestore.instance.collection('external_requests').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            switch (status) {
              case 'pending': pending++; break;
              case 'approved': approved++; break;
              case 'rejected': rejected++; break;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            _statCard('TOTAL REQUESTS', '$total', UpriseColors.primaryDark),
            const SizedBox(width: 16),
            _statCard('PENDING', '$pending', UpriseColors.warning),
            const SizedBox(width: 16),
            _statCard('APPROVED', '$approved', UpriseColors.success),
            const SizedBox(width: 16),
            _statCard('REJECTED', '$rejected', UpriseColors.error),
          ]),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------- TOOLBAR (unchanged) ----------
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
                  hintText: 'Search name, email, university...',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                  prefixIcon: const Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                  filled: true,
                  fillColor: UpriseColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: UpriseColors.mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: UpriseColors.mediumGray),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (_) => setState(() => _currentPage = 1),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                items: ['All', 'Pending', 'Approved', 'Rejected']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Row(children: [
                            Icon(_statusIcon(status), size: 16, color: _statusColor(status)),
                            const SizedBox(width: 8),
                            Text(status, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          ]),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _statusFilter = value!;
                  _currentPage = 1;
                }),
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
                icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _exportToCSV,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: UpriseColors.primaryDark,
              side: BorderSide(color: UpriseColors.mediumGray),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending': return Icons.pending_actions;
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      default: return Icons.list;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending': return UpriseColors.warning;
      case 'Approved': return UpriseColors.success;
      case 'Rejected': return UpriseColors.error;
      default: return UpriseColors.primaryDark;
    }
  }

  // ---------- TABLE (unchanged) ----------
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('external_requests').orderBy('requestDate', descending: true).snapshots(),
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
            final name = (data['userName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final uni = (data['university'] ?? '').toString().toLowerCase();
            return name.contains(term) || email.contains(term) || uni.contains(term);
          }).toList();
        }

        if (docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UpriseColors.mediumGray),
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
                    Expanded(flex: 1, child: Text('ID', style: _headerStyle())),
                    Expanded(flex: 2, child: Text('USER NAME', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('UNIVERSITY', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                    Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                  ]),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: UpriseColors.mediumGray),
                        const SizedBox(height: 16),
                        Text('No external requests found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 15)),
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
            border: Border.all(color: UpriseColors.mediumGray),
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
                  Expanded(flex: 1, child: Text('ID', style: _headerStyle())),
                  Expanded(flex: 2, child: Text('USER NAME', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('UNIVERSITY', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                  Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pageDocs.length,
                  itemBuilder: (_, i) {
                    final data = pageDocs[i].data() as Map<String, dynamic>;
                    final req = ExternalRequest(
                      id: pageDocs[i].id,
                      userId: data['userId'] ?? '',
                      userName: data['userName'] ?? '',
                      email: data['email'] ?? '',
                      university: data['university'] ?? '',
                      status: data['status'] ?? 'pending',
                      requestDate: (data['requestDate'] as Timestamp).toDate(),
                      purpose: data['purpose'] ?? '',
                    );
                    return _buildRow(req);
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
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total requests',
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

  Widget _buildRow(ExternalRequest req) {
    final statusColor = req.status == 'approved'
        ? UpriseColors.success
        : req.status == 'rejected'
            ? UpriseColors.error
            : UpriseColors.warning;
    final formattedDate = DateFormat('MMM dd, yyyy').format(req.requestDate);
    String shortId = req.userName.isNotEmpty
        ? req.userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '??';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(flex: 1, child: Text(shortId, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.userName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(req.email, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
          ]),
        ),
        Expanded(flex: 1, child: Text(formattedDate, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray))),
        Expanded(flex: 1, child: Text(req.university, style: GoogleFonts.beVietnamPro(fontSize: 12))),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(req.status.toUpperCase(),
                textAlign: TextAlign.center,
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

  // ---------- STATUS CHANGE WITH LOGGING ----------
  Future<void> _setStatus(String docId, String newStatus) async {
    // Fetch request details before update
    String userName = '';
    try {
      final docSnap = await FirebaseFirestore.instance.collection('external_requests').doc(docId).get();
      userName = docSnap.data()?['userName'] ?? 'Unknown user';
    } catch (e) {
      userName = 'Unknown user';
    }

    await FirebaseFirestore.instance.collection('external_requests').doc(docId).update({'status': newStatus});

    await ActivityLogger.log(
      action: '${newStatus.toUpperCase()} external request for $userName',
      module: 'External Account',
      severity: newStatus == 'rejected' ? 'warning' : 'info',
      details: {'requestId': docId},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request ${newStatus.toUpperCase()}')));
    }
  }

  // ---------- DELETE WITH LOGGING ----------
  void _confirmDelete(ExternalRequest req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: Text('Are you sure you want to delete the request from "${req.userName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('external_requests').doc(req.id).delete();

              await ActivityLogger.log(
                action: 'Deleted external request for ${req.userName}',
                module: 'External Account',
                severity: 'warning',
                details: {'requestId': req.id},
              );

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request deleted')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------- DETAILS DIALOG (unchanged) ----------
  void _showDetails(ExternalRequest req) {
    final statusColor = req.status == 'approved'
        ? UpriseColors.success
        : req.status == 'rejected'
            ? UpriseColors.error
            : UpriseColors.warning;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.person_outline, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(child: Text(req.userName, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('Email', req.email),
            _detailRow('University/Organization', req.university),
            _detailRow('Request Date', DateFormat('MMM dd, yyyy hh:mm a').format(req.requestDate)),
            _detailRow('Purpose', req.purpose.isNotEmpty ? req.purpose : 'No purpose provided.'),
            _detailRow('Status', req.status.toUpperCase(), isStatus: true, statusColor: statusColor),
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
            child: const Text('Close'),
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

  // ---------- EXPORT ----------
  Future<void> _exportToCSV() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('external_requests').get();
      final lines = <String>['Name,Email,University,Purpose,Status,Request Date'];
      for (var doc in snap.docs) {
        final d = doc.data();
        lines.add([
          d['userName'] ?? '',
          d['email'] ?? '',
          d['university'] ?? '',
          (d['purpose'] ?? '').replaceAll(',', ';'),
          d['status'] ?? '',
          (d['requestDate'] as Timestamp).toDate().toString(),
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/external_requests.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'External Requests Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error),
      );
    }
  }
}

// ---------- Data Model ----------
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
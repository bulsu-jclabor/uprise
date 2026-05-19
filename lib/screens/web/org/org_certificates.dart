// lib/screens/web/org/org_certificates.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ============ COLOR SCHEME ============
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
  static const Color successBg    = Color(0xFFD1FAE5);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color infoBg       = Color(0xFFDBEAFE);
}

// ============ CERTIFICATE MODEL ============
class CertificateRecord {
  final String id;
  final String certificateId; // e.g. CERT-8831
  final String eventName;
  final String organization;
  final String type;
  final DateTime date;
  final int recipients;
  final String status; // distributed | pending | draft | undistributed
  final String templateType;

  const CertificateRecord({
    required this.id,
    required this.certificateId,
    required this.eventName,
    required this.organization,
    required this.type,
    required this.date,
    required this.recipients,
    required this.status,
    required this.templateType,
  });

  factory CertificateRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final issuedAt = (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return CertificateRecord(
      id: doc.id,
      certificateId: 'CERT-${doc.id.substring(0, 4).toUpperCase()}',
      eventName: data['eventName'] as String? ?? data['certificateName'] as String? ?? 'Untitled',
      organization: data['organization'] as String? ?? 'N/A',
      type: data['type'] as String? ?? 'Participation',
      date: issuedAt,
      recipients: (data['recipients'] as num?)?.toInt() ?? 1,
      status: data['status'] as String? ?? 'draft',
      templateType: data['templateType'] as String? ?? 'Formal Academic',
    );
  }
}

// ============ CERTIFICATE TEMPLATE MODEL ============
class CertificateTemplate {
  final String id;
  final String name;
  final String description;
  final List<String> fields;
  final DateTime createdAt;

  const CertificateTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    required this.createdAt,
  });

  factory CertificateTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CertificateTemplate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      fields: List<String>.from(data['fields'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ============ STATUS BADGE ============
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'distributed':
        bg = OrgColors.successBg;
        fg = const Color(0xFF065F46);
        label = 'Distributed';
        break;
      case 'pending':
        bg = OrgColors.warningBg;
        fg = const Color(0xFF92400E);
        label = 'Pending';
        break;
      case 'draft':
        bg = OrgColors.mediumGray;
        fg = OrgColors.darkGray;
        label = 'Draft';
        break;
      case 'undistributed':
      default:
        bg = OrgColors.errorBg;
        fg = const Color(0xFF991B1B);
        label = 'Undistributed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ============ MAIN SCREEN ============
class OrgCertificatesScreen extends StatefulWidget {
  final String orgId;
  const OrgCertificatesScreen({super.key, required this.orgId});

  @override
  State<OrgCertificatesScreen> createState() => _OrgCertificatesScreenState();
}

class _OrgCertificatesScreenState extends State<OrgCertificatesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Stream<QuerySnapshot> get _certificatesStream => FirebaseFirestore.instance
      .collection('certificates')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('issuedAt', descending: true)
      .snapshots();

  void _openGenerateCertificateFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SelectTemplateModal(
        orgId: widget.orgId,
        onConfirm: (templateType) {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _GenerateCertificateModal(
              orgId: widget.orgId,
              selectedTemplateType: templateType,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 20),
          Expanded(child: _buildCertificatesTable()),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Management',
              style: GoogleFonts.beVietnamPro(
                fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Generate, customize, and distribute event certificates',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _openGenerateCertificateFlow,
          icon: const Icon(Icons.add, size: 16, color: OrgColors.white),
          label: Text(
            'Generate Certificate',
            style: GoogleFonts.beVietnamPro(
              color: OrgColors.white, fontWeight: FontWeight.w600, fontSize: 13,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: OrgColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _certificatesStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final total = docs.length;
        final totalRecipients = docs.fold<int>(
          0, (sum, d) => sum + ((d.data() as Map<String, dynamic>)['recipients'] as num? ?? 1).toInt(),
        );
        final distributed = docs.where((d) =>
            (d.data() as Map<String, dynamic>)['status'] == 'distributed').length;
        final pending = docs.where((d) =>
            (d.data() as Map<String, dynamic>)['status'] == 'pending').length;

        return Row(
          children: [
            Expanded(child: _StatCard(
              label: 'Total Certificates',
              value: total,
              icon: Icons.card_membership_outlined,
              iconColor: OrgColors.info,
              iconBg: OrgColors.infoBg,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Total Recipients',
              value: totalRecipients,
              icon: Icons.people_outline,
              iconColor: OrgColors.warning,
              iconBg: OrgColors.warningBg,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Distributed',
              value: distributed,
              icon: Icons.assignment_turned_in_outlined,
              iconColor: OrgColors.success,
              iconBg: OrgColors.successBg,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Pending',
              value: pending,
              icon: Icons.grid_view_outlined,
              iconColor: OrgColors.primaryDark,
              iconBg: OrgColors.warningBg,
            )),
          ],
        );
      },
    );
  }

  // ── Certificate Records Table ─────────────────────────────────────────────
  Widget _buildCertificatesTable() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate Records',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w600, color: OrgColors.charcoal,
                      ),
                    ),
                    Text(
                      'Manage and monitor all issued digital certificates',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                    ),
                  ],
                ),
                const Spacer(),
                // Search box
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    style: GoogleFonts.beVietnamPro(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search records...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                      prefixIcon: const Icon(Icons.search, size: 18, color: OrgColors.darkGray),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: OrgColors.primaryLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: OrgColors.primaryLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5),
                      ),
                      filled: true,
                      fillColor: OrgColors.lightGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Column headers
          Container(
            color: OrgColors.lightGray,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                _colHeader('CERTIFICATE ID', flex: 2),
                _colHeader('EVENT NAME', flex: 3),
                _colHeader('ORGANIZATION', flex: 2),
                _colHeader('TYPE', flex: 2),
                _colHeader('DATE', flex: 2),
                _colHeader('RECIPIENTS', flex: 2),
                _colHeader('STATUS', flex: 2),
                _colHeader('ACTIONS', flex: 2),
              ],
            ),
          ),
          const Divider(height: 1, color: OrgColors.mediumGray),
          // Rows
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _certificatesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: OrgColors.primaryLight),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_membership_outlined, size: 48, color: OrgColors.mediumGray),
                        const SizedBox(height: 12),
                        Text(
                          'No certificates issued yet.',
                          style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click "Generate Certificate" to create one.',
                          style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                final records = snapshot.data!.docs
                    .map((doc) => CertificateRecord.fromFirestore(doc))
                    .where((r) {
                  if (_searchQuery.isEmpty) return true;
                  return r.eventName.toLowerCase().contains(_searchQuery) ||
                      r.certificateId.toLowerCase().contains(_searchQuery) ||
                      r.organization.toLowerCase().contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final r = records[i];
                    final isEven = i % 2 == 0;
                    return _CertificateRow(
                      record: r,
                      isEven: isEven,
                      orgId: widget.orgId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _colHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: OrgColors.darkGray, letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ============ STAT CARD ============
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 26, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ CERTIFICATE ROW ============
class _CertificateRow extends StatelessWidget {
  final CertificateRecord record;
  final bool isEven;
  final String orgId;

  const _CertificateRow({
    required this.record,
    required this.isEven,
    required this.orgId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? OrgColors.white : OrgColors.lightGray,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              record.certificateId,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              record.eventName,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.organization,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.type,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM d, yyyy').format(record.date),
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.recipients.toString(),
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
            ),
          ),
          Expanded(
            flex: 2,
            child: _StatusBadge(record.status),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _ActionIconButton(
                  icon: Icons.remove_red_eye_outlined,
                  color: OrgColors.info,
                  tooltip: 'View',
                  onTap: () => _viewCertificate(context, record),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  icon: Icons.edit_outlined,
                  color: OrgColors.primaryDark,
                  tooltip: 'Edit',
                  onTap: () => _editCertificate(context, record),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  icon: Icons.delete_outline,
                  color: OrgColors.error,
                  tooltip: 'Delete',
                  onTap: () => _deleteCertificate(context, record),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewCertificate(BuildContext context, CertificateRecord record) {
    showDialog(
      context: context,
      builder: (_) => _CertificatePreviewDialog(record: record),
    );
  }

  void _editCertificate(BuildContext context, CertificateRecord record) {
    showDialog(
      context: context,
      builder: (_) => _GenerateCertificateModal(
        orgId: orgId,
        selectedTemplateType: record.templateType,
        existingRecord: record,
      ),
    );
  }

  Future<void> _deleteCertificate(BuildContext context, CertificateRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Certificate',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${record.certificateId}"? This cannot be undone.',
          style: GoogleFonts.beVietnamPro(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.beVietnamPro(color: OrgColors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('certificates').doc(record.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_certificate',
        module: 'certificates',
        details: {'certId': record.id, 'eventName': record.eventName},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate deleted', style: GoogleFonts.beVietnamPro()),
            backgroundColor: OrgColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: OrgColors.error),
        );
      }
    }
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

// ============ STEP 1: SELECT TEMPLATE MODAL ============
class _SelectTemplateModal extends StatefulWidget {
  final String orgId;
  final void Function(String templateType) onConfirm;

  const _SelectTemplateModal({required this.orgId, required this.onConfirm});

  @override
  State<_SelectTemplateModal> createState() => _SelectTemplateModalState();
}

class _SelectTemplateModalState extends State<_SelectTemplateModal> {
  String _selected = 'Formal Academic';

  // Template completion level per type (mock progress — can be driven by Firestore)
  final Map<String, double> _completionLevels = {
    'Formal Academic': 0.85,
    'Modern Workshop': 0.60,
    'Vibrant Event': 0.40,
  };

  final List<Map<String, dynamic>> _templates = [
    {
      'type': 'Formal Academic',
      'colors': [Color(0xFFFDF6EC), Color(0xFFB45309)],
      'accent': Color(0xFFB45309),
    },
    {
      'type': 'Modern Workshop',
      'colors': [Color(0xFF1E3A5F), Color(0xFF2563EB)],
      'accent': Color(0xFF2563EB),
    },
    {
      'type': 'Vibrant Event',
      'colors': [Color(0xFF065F46), Color(0xFF10B981)],
      'accent': Color(0xFF10B981),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final completion = _completionLevels[_selected] ?? 0.5;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Certificate Template',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Preview and customize the academic credential before issuing.',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18, color: OrgColors.darkGray),
                  ),
                ],
              ),
            ),

            // Template cards
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: _templates.map((t) {
                      final type = t['type'] as String;
                      final colors = t['colors'] as List<Color>;
                      final accent = t['accent'] as Color;
                      final isSelected = _selected == type;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _TemplatePreviewCard(
                            type: type,
                            colors: colors,
                            accent: accent,
                            isSelected: isSelected,
                            onTap: () => setState(() => _selected = type),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Completion level
                  Row(
                    children: [
                      Text(
                        'TEMPLATE COMPLETION LEVEL',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: OrgColors.darkGray, letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(completion * 100).toInt()}% Ready',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: OrgColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completion,
                      minHeight: 7,
                      backgroundColor: OrgColors.mediumGray,
                      valueColor: const AlwaysStoppedAnimation<Color>(OrgColors.primaryLight),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ensure all required fields are input correctly to unlock automatic signing with Hanzell · See distribution details',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrgColors.darkGray,
                      side: const BorderSide(color: OrgColors.primaryLight),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Close', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => widget.onConfirm(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm',
                      style: GoogleFonts.beVietnamPro(
                        color: OrgColors.white, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Template Preview Card ─────────────────────────────────────────────────────
class _TemplatePreviewCard extends StatelessWidget {
  final String type;
  final List<Color> colors;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplatePreviewCard({
    required this.type,
    required this.colors,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Mini certificate preview
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: colors[0],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? accent : OrgColors.mediumGray,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Decorative corner
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
                // Certificate content preview
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Certificate',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 8, fontWeight: FontWeight.w700, color: accent,
                        ),
                      ),
                      Text(
                        'of Participation',
                        style: GoogleFonts.beVietnamPro(fontSize: 6, color: accent),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 1.5, width: 40,
                        color: accent.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[Recipient Name]',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 7, fontWeight: FontWeight.w600,
                          color: colors[0].computeLuminance() > 0.5 ? OrgColors.charcoal : OrgColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selected check
                if (isSelected)
                  Positioned(
                    top: 4, left: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 10, color: OrgColors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            type,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w500, color: OrgColors.charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? OrgColors.primaryDark : OrgColors.mediumGray,
                foregroundColor: isSelected ? OrgColors.white : OrgColors.darkGray,
                padding: const EdgeInsets.symmetric(vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'CHOOSE',
                style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ STEP 2: GENERATE CERTIFICATE MODAL ============
class _GenerateCertificateModal extends StatefulWidget {
  final String orgId;
  final String selectedTemplateType;
  final CertificateRecord? existingRecord;

  const _GenerateCertificateModal({
    required this.orgId,
    required this.selectedTemplateType,
    this.existingRecord,
  });

  @override
  State<_GenerateCertificateModal> createState() => _GenerateCertificateModalState();
}

class _GenerateCertificateModalState extends State<_GenerateCertificateModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();

  String? _selectedEventId;
  String? _selectedEventName;
  String _certType = 'Formal Academic';
  bool _isSubmitting = false;
  String _previewRecipient = '[Recipient Name]';

  // Available events stream
  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('events')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('date', descending: false)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _certType = widget.selectedTemplateType;
    _orgCtrl.text = 'FutureLab';
    _dateCtrl.text = DateFormat('MM/dd/yyyy').format(DateTime.now());

    if (widget.existingRecord != null) {
      _titleCtrl.text = widget.existingRecord!.eventName;
      _orgCtrl.text = widget.existingRecord!.organization;
      _dateCtrl.text = DateFormat('MM/dd/yyyy').format(widget.existingRecord!.date);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _orgCtrl.dispose();
    _dateCtrl.dispose();
    _signatureCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool distribute}) async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isSubmitting = true);

    final data = <String, dynamic>{
      'orgId': widget.orgId,
      'eventName': _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : (_selectedEventName ?? 'Untitled'),
      'organization': _orgCtrl.text.trim(),
      'templateType': _certType,
      'type': 'Participation',
      'issuedAt': FieldValue.serverTimestamp(),
      'status': distribute ? 'distributed' : 'draft',
      'recipients': 0,
      'signatories': _signatureCtrl.text.trim(),
    };

    try {
      if (widget.existingRecord != null) {
        await FirebaseFirestore.instance
            .collection('certificates')
            .doc(widget.existingRecord!.id)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('certificates').add(data);
      }
      await activity_log.ActivityLogger.log(
        action: distribute ? 'generate_distribute_certificate' : 'save_draft_certificate',
        module: 'certificates',
        details: {'orgId': widget.orgId, 'templateType': _certType},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              distribute ? 'Certificate generated & distributed!' : 'Saved as draft.',
              style: GoogleFonts.beVietnamPro(),
            ),
            backgroundColor: distribute ? OrgColors.success : OrgColors.darkGray,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: OrgColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Determine preview colors based on template type
  Map<String, dynamic> get _previewTheme {
    switch (_certType) {
      case 'Modern Workshop':
        return {'bg': const Color(0xFF1E3A5F), 'accent': const Color(0xFF2563EB), 'text': OrgColors.white};
      case 'Vibrant Event':
        return {'bg': const Color(0xFF065F46), 'accent': const Color(0xFF10B981), 'text': OrgColors.white};
      default: // Formal Academic
        return {'bg': const Color(0xFFFDF6EC), 'accent': OrgColors.primaryDark, 'text': OrgColors.charcoal};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _previewTheme;
    final eventTitle = _titleCtrl.text.isNotEmpty
        ? _titleCtrl.text
        : (_selectedEventName ?? 'the AI Ethics Seminar');
    final eventDate = _dateCtrl.text.isNotEmpty ? _dateCtrl.text : 'March 15, 2026';
    final orgName = _orgCtrl.text.isNotEmpty ? _orgCtrl.text : 'FutureLab';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 760,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: OrgColors.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.workspace_premium_outlined,
                          size: 18, color: OrgColors.primaryDark),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate New Certificate',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
                          ),
                        ),
                        Text(
                          'Create and customize certificates for event participants',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18, color: OrgColors.darkGray),
                    ),
                  ],
                ),
              ),

              // ── Body: left form + right preview ──
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Form
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row: Select Event + Certificate Type
                              Row(
                                children: [
                                  Expanded(
                                    child: _FormField(
                                      label: 'Select Event *',
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: _eventsStream,
                                        builder: (context, snapshot) {
                                          final events = snapshot.data?.docs ?? [];
                                          return DropdownButtonFormField<String>(
                                            value: _selectedEventId,
                                            hint: Text(
                                              'AI Ethics Seminar',
                                              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                                            ),
                                            decoration: _inputDecoration(),
                                            style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
                                            items: events.map((doc) {
                                              final data = doc.data() as Map<String, dynamic>;
                                              return DropdownMenuItem(
                                                value: doc.id,
                                                child: Text(data['title'] as String? ?? 'Untitled'),
                                              );
                                            }).toList(),
                                            onChanged: (v) {
                                              if (v == null) return;
                                              final doc = events.firstWhere((d) => d.id == v);
                                              final data = doc.data() as Map<String, dynamic>;
                                              setState(() {
                                                _selectedEventId = v;
                                                _selectedEventName = data['title'] as String?;
                                                _titleCtrl.text = _selectedEventName ?? '';
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FormField(
                                      label: 'Certificate Type *',
                                      child: DropdownButtonFormField<String>(
                                        value: _certType,
                                        decoration: _inputDecoration(),
                                        style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
                                        items: [
                                          'Formal Academic',
                                          'Modern Workshop',
                                          'Vibrant Event',
                                        ].map((t) => DropdownMenuItem(
                                          value: t, child: Text(t),
                                        )).toList(),
                                        onChanged: (v) {
                                          if (v != null) setState(() => _certType = v);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Certificate Template Customization header
                              Text(
                                'Certificate Template Customization',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Certificate Title
                              _FormField(
                                label: 'Certificate Title *',
                                child: TextFormField(
                                  controller: _titleCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: _inputDecoration(
                                    hint: 'e.g. Certificate of Participation',
                                  ),
                                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                  style: GoogleFonts.beVietnamPro(fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _FormField(
                                      label: 'Organization Name *',
                                      child: TextFormField(
                                        controller: _orgCtrl,
                                        onChanged: (_) => setState(() {}),
                                        decoration: _inputDecoration(hint: 'FutureLab'),
                                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FormField(
                                      label: 'Event Date *',
                                      child: TextFormField(
                                        controller: _dateCtrl,
                                        onChanged: (_) => setState(() {}),
                                        decoration: _inputDecoration(hint: '03/15/2026'),
                                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                                        onTap: () async {
                                          FocusScope.of(context).requestFocus(FocusNode());
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2030),
                                            builder: (context, child) => Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.light(
                                                  primary: OrgColors.primaryDark,
                                                ),
                                              ),
                                              child: child!,
                                            ),
                                          );
                                          if (picked != null) {
                                            _dateCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              _FormField(
                                label: 'Signatories (Authorized Personnel) *',
                                child: TextFormField(
                                  controller: _signatureCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: _inputDecoration(
                                    hint: 'Name and Title (comma separated)',
                                  ),
                                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                  style: GoogleFonts.beVietnamPro(fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Automatic Recipient Detection note
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: OrgColors.infoBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: OrgColors.info.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, size: 15, color: OrgColors.info),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.charcoal),
                                          children: [
                                            TextSpan(
                                              text: 'Automatic Recipient Detection  ',
                                              style: GoogleFonts.beVietnamPro(
                                                fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.charcoal,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'Certificates will be automatically generated for all event attendees based on ',
                                              style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
                                            ),
                                            TextSpan(
                                              text: 'Hanzell',
                                              style: GoogleFonts.beVietnamPro(
                                                fontSize: 11, fontWeight: FontWeight.w600,
                                                color: OrgColors.info,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' · See distribution details',
                                              style: GoogleFonts.beVietnamPro(
                                                fontSize: 11, color: OrgColors.info,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Right: Live Preview
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIVE PREVIEW',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: OrgColors.darkGray, letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _CertificatePreview(
                                bg: theme['bg'] as Color,
                                accent: theme['accent'] as Color,
                                textColor: theme['text'] as Color,
                                orgName: orgName,
                                eventTitle: eventTitle,
                                eventDate: eventDate,
                                recipientName: _previewRecipient,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: OrgColors.primaryLight)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _submit(distribute: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OrgColors.darkGray,
                        side: const BorderSide(color: OrgColors.primaryLight),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Draft', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : () => _submit(distribute: true),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(color: OrgColors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 15, color: OrgColors.white),
                      label: Text(
                        'Generate & Distribute',
                        style: GoogleFonts.beVietnamPro(color: OrgColors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrgColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.primaryLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.primaryLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: OrgColors.error),
      ),
      filled: true,
      fillColor: OrgColors.white,
    );
  }
}

// ── Form field wrapper ────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12, fontWeight: FontWeight.w500, color: OrgColors.charcoal,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

// ============ CERTIFICATE LIVE PREVIEW ============
class _CertificatePreview extends StatelessWidget {
  final Color bg;
  final Color accent;
  final Color textColor;
  final String orgName;
  final String eventTitle;
  final String eventDate;
  final String recipientName;

  const _CertificatePreview({
    required this.bg,
    required this.accent,
    required this.textColor,
    required this.orgName,
    required this.eventTitle,
    required this.eventDate,
    required this.recipientName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Org name / logo area
          Text(
            orgName.toUpperCase(),
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: accent, letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          // Decorative line
          Row(
            children: [
              Expanded(child: Divider(color: accent.withValues(alpha: 0.4), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.workspace_premium, size: 18, color: accent),
              ),
              Expanded(child: Divider(color: accent.withValues(alpha: 0.4), thickness: 1)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Certificate of',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, fontWeight: FontWeight.w300, color: textColor,
            ),
          ),
          Text(
            'Participation',
            style: GoogleFonts.beVietnamPro(
              fontSize: 20, fontWeight: FontWeight.w800, color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is to certify that',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          Text(
            recipientName,
            style: GoogleFonts.beVietnamPro(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: textColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Divider(color: accent.withValues(alpha: 0.3), thickness: 0.8),
          const SizedBox(height: 4),
          Text(
            'has successfully participated in the',
            style: GoogleFonts.beVietnamPro(fontSize: 9, color: textColor.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          Text(
            eventTitle,
            style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w600, color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'held on $eventDate',
            style: GoogleFonts.beVietnamPro(fontSize: 9, color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          // Signature line
          Divider(color: accent.withValues(alpha: 0.5), thickness: 0.8, indent: 30, endIndent: 30),
          Text(
            'Authorized Signatory',
            style: GoogleFonts.beVietnamPro(fontSize: 8, color: textColor.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ============ CERTIFICATE PREVIEW DIALOG (view mode) ============
class _CertificatePreviewDialog extends StatelessWidget {
  final CertificateRecord record;
  const _CertificatePreviewDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.certificateId,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _CertificatePreview(
                bg: const Color(0xFFFDF6EC),
                accent: OrgColors.primaryDark,
                textColor: OrgColors.charcoal,
                orgName: record.organization,
                eventTitle: record.eventName,
                eventDate: DateFormat('MMMM dd, yyyy').format(record.date),
                recipientName: '[Recipient Name]',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.primaryDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Close', style: GoogleFonts.beVietnamPro(color: OrgColors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




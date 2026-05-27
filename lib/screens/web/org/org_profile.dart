// lib/screens/web/org/org_profile.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/activity_logger.dart' as activity_log;

String _mimeTypeFromPath(String? path) {
  if (path == null) return 'image/png';
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'bmp':
      return 'image/bmp';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/png';
  }
}

ImageProvider _imageProviderFromUrl(String url) {
  if (url.startsWith('data:image')) {
    final base64Part = url.split(',').last;
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}

Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover, Widget? errorWidget}) {
  return Image(
    image: _imageProviderFromUrl(url),
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
  );
}

// ─── Color Scheme ─────────────────────────────────────────────────────────────
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
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class OrgProfileScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String orgShortName;
  final String orgEmail;

  const OrgProfileScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    required this.orgShortName,
    required this.orgEmail,
  });

  @override
  State<OrgProfileScreen> createState() => _OrgProfileScreenState();
}

class _OrgProfileScreenState extends State<OrgProfileScreen> {
  // Org data
  String _orgName = '';
  String _orgShortName = '';
  String _orgEmail = '';
  String _orgDescription = '';
  String _schoolYear = '';
  String _semester = '';
  String _orgLogoUrl = '';

  // Social media
  String _facebook = '';
  String _instagram = '';
  String _twitter = '';
  String _gmail = '';

  // Adviser
  String _adviserName = '';
  String _adviserEmail = '';
  String _adviserPhone = '';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _orgName = widget.orgName;
    _orgShortName = widget.orgShortName;
    _orgEmail = widget.orgEmail;
    _loadOrgData();
  }

  Future<void> _loadOrgData() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.orgId)
        .get();
    
    if (!mounted) return;
    
    if (doc.exists) {
      final data = doc.data()!;
      
      // DON'T await this - let it run in background
      _syncOrganizationOfficersIfNeeded(data);
      
      setState(() {
        _orgName        = data['name'] ?? widget.orgName;
        _orgShortName   = data['shortName'] ?? widget.orgShortName;
        _orgEmail       = data['email'] ?? widget.orgEmail;
        _orgDescription = data['description'] ?? '';
        _schoolYear     = data['schoolYear'] ?? '';
        _semester       = data['semester'] ?? '';
        _orgLogoUrl     = data['logoUrl'] ?? '';
        _facebook       = data['facebook'] ?? '';
        _instagram      = data['instagram'] ?? '';
        _twitter        = data['twitter'] ?? '';
        _gmail          = data['gmail'] ?? '';
        _adviserName    = data['adviserName'] ?? '';
        _adviserEmail   = data['adviserEmail'] ?? '';
        _adviserPhone   = data['adviserPhone'] ?? '';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      _showErrorSnack('Organization not found');
    }
  } catch (e) {
    print('Error: $e');
    if (mounted) {
      setState(() => _loading = false);
      _showErrorSnack('Failed to load: $e');
    }
  }
}

// Add this helper method after _loadOrgData
void _showErrorSnack(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: OrgColors.error,
    ),
  );
}

  Future<void> _syncOrganizationOfficersIfNeeded(Map<String, dynamic> data) async {
  try {
    final storedOfficers = data['officers'] as List<dynamic>?;
    
    final officerSnap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.orgId)
        .collection('officers')
        .orderBy('positionRank', descending: false)
        .get();

    final officers = officerSnap.docs.map((d) {
      final ddata = d.data();
      return {
        'name': ddata['name'] ?? '',
        'role': ddata['position'] ?? '',
        'email': ddata['email'] ?? '',
        'phone': ddata['phone'] ?? '',
        'photoUrl': ddata['photoUrl'] ?? '',
      };
    }).toList();

    if (!_officersMatch(storedOfficers, officers)) {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .update({'officers': officers});
    }
  } catch (e) {
    // Just log error, don't break the whole page
    print('Sync officers error: $e');
  }
}

  bool _officersMatch(List<dynamic>? stored, List<Map<String, dynamic>> expected) {
    if (stored == null || stored.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      final storedOfficer = stored[i];
      if (storedOfficer is! Map) return false;
      final expectedOfficer = expected[i];
      for (final key in expectedOfficer.keys) {
        if ((storedOfficer[key] ?? '') != expectedOfficer[key]) return false;
      }
    }
    return true;
  }

  void _openEditProfileSheet() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: _EditOrgProfileSheet(
          orgId: widget.orgId,
          orgName: _orgName,
          shortName: _orgShortName,
          email: _orgEmail,
          description: _orgDescription,
          schoolYear: _schoolYear,
          semester: _semester,
          logoUrl: _orgLogoUrl,
          adviserName: _adviserName,
          adviserEmail: _adviserEmail,
          adviserPhone: _adviserPhone,
          facebook: _facebook,
          instagram: _instagram,
          twitter: _twitter,
          gmail: _gmail,
          onSaved: _loadOrgData,
        ),
      ),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  void _openAddOfficerModal({OfficerModel? officer}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OfficerModal(
        orgId: widget.orgId,
        existingOfficer: officer,
        onSuccess: () => setState(() {}),
      ),
    );
  }

  Future<void> _deleteOfficer(OfficerModel officer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: OrgColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, color: OrgColors.error, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Remove Officer', style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              Text('Remove "${officer.name}" from the officers list?',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro()),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: OrgColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text('Remove', style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.orgId)
        .collection('officers')
        .doc(officer.id)
        .delete();
    await _syncOrganizationOfficers();
    await activity_log.ActivityLogger.log(action: 'delete_officer', module: 'org_profile',
        details: {'orgId': widget.orgId, 'name': officer.name});
    setState(() {});
  }

  Future<void> _syncOrganizationOfficers() async {
    final orgDoc = FirebaseFirestore.instance.collection('organizations').doc(widget.orgId);
    final officerSnap = await orgDoc.collection('officers').get();
    final officers = officerSnap.docs.map((d) {
      final ddata = d.data();
      return {
        'name': ddata['name'] ?? '',
        'role': ddata['position'] ?? '',
        'email': ddata['email'] ?? '',
        'phone': ddata['phone'] ?? '',
        'photoUrl': ddata['photoUrl'] ?? '',
      };
    }).toList();
    await orgDoc.update({'officers': officers});
  }

  Stream<QuerySnapshot> get _officersStream => FirebaseFirestore.instance
      .collection('organizations')
      .doc(widget.orgId)
      .collection('officers')
      .orderBy('positionRank', descending: false)
      .snapshots();

  Future<int> _getMemberCount() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('orgId', isEqualTo: widget.orgId)
        .where('role', isEqualTo: 'org')
        .get();
    return snap.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Header ─────────────────────────────────────────────
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Organization Profile',
                  style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w800, color: OrgColors.charcoal)),
              const SizedBox(height: 3),
              Text('Manage your organization information and structure',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _openEditProfileSheet,
              icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              label: Text('Edit Profile', style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: OrgColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Two-column layout: main + sidebar ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left / Main column ─────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Org Info Card
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Organization Information'),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: OrgColors.lightGray,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: OrgColors.primaryLight),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _orgLogoUrl.isNotEmpty
                                    ? _buildImageWidget(_orgLogoUrl, fit: BoxFit.cover, errorWidget: const Icon(Icons.business, color: OrgColors.darkGray))
                                    : const Icon(Icons.business, color: OrgColors.darkGray, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_orgName,
                                        style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                                    const SizedBox(height: 4),
                                    Text(_orgEmail,
                                        style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                                    if (_orgDescription.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(_orgDescription,
                                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal.withOpacity(0.75), height: 1.5)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _infoChip('School Year', _schoolYear.isNotEmpty ? _schoolYear : '—')),
                            const SizedBox(width: 12),
                            Expanded(child: _infoChip('Semester', _semester.isNotEmpty ? _semester : '—')),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Adviser Card
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Adviser'),
                          const SizedBox(height: 14),
                          if (_adviserName.isNotEmpty)
                            Row(children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: OrgColors.accent.withOpacity(0.15),
                                child: Text(_adviserName[0].toUpperCase(),
                                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 16, color: OrgColors.primaryDark)),
                              ),
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_adviserName,
                                    style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                                if (_adviserEmail.isNotEmpty)
                                  Text(_adviserEmail,
                                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                                if (_adviserPhone.isNotEmpty)
                                  Text(_adviserPhone,
                                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                              ]),
                            ])
                          else
                            Text('No adviser assigned',
                                style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Officers Card
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: _sectionHeader('Officers')),
                            ElevatedButton.icon(
                              onPressed: () => _openAddOfficerModal(),
                              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                              label: Text('Add Officer',
                                  style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OrgColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('Manage your organization officers and positions',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                          const SizedBox(height: 16),

                          // Total members badge
                          FutureBuilder<int>(
                            future: _getMemberCount(),
                            builder: (ctx, snap) {
                              final count = snap.data ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: OrgColors.lightGray,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: OrgColors.primaryLight),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.people_outline, size: 16, color: OrgColors.darkGray),
                                  const SizedBox(width: 8),
                                  Text('Total Members',
                                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                                  const Spacer(),
                                  Text('$count',
                                      style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                                ]),
                              );
                            },
                          ),

                          StreamBuilder<QuerySnapshot>(
                            stream: _officersStream,
                            builder: (ctx, snap) {
                              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                              final officers = snap.data!.docs.map((d) => OfficerModel.fromFirestore(d)).toList();
                              if (officers.isEmpty) {
                                return Center(child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text('No officers added yet',
                                      style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                                ));
                              }
                              return Column(
                                children: officers.map((o) => _OfficerTile(
                                  officer: o,
                                  onEdit: () => _openAddOfficerModal(officer: o),
                                  onDelete: () => _deleteOfficer(o),
                                )).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Hierarchy Card
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Organization Hierarchy'),
                          const SizedBox(height: 4),
                          Text('Visual structure of the organization',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                          const SizedBox(height: 20),
                          _HierarchyTree(orgId: widget.orgId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // ── Right / Sidebar ────────────────────────────────────
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    // Social Media Card
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Social Media'),
                          const SizedBox(height: 14),
                          _socialRow(Icons.facebook_rounded, 'Facebook', _facebook),
                          _socialRow(Icons.camera_alt_outlined, 'Instagram', _instagram),
                          _socialRow(Icons.alternate_email, 'Twitter / X', _twitter),
                          _socialRow(Icons.mail_outline_rounded, 'Gmail', _gmail),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Stats Card
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Quick Stats'),
                          const SizedBox(height: 14),
                          StreamBuilder<QuerySnapshot>(
                            stream: _officersStream,
                            builder: (ctx, snap) {
                              final officerCount = snap.data?.docs.length ?? 0;
                              return Column(children: [
                                _statRow('Total Officers', officerCount.toString()),
                                const SizedBox(height: 10),
                                FutureBuilder<int>(
                                  future: _getMemberCount(),
                                  builder: (ctx2, snap2) => _statRow('Total Members', (snap2.data ?? 0).toString()),
                                ),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OrgColors.primaryLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _sectionHeader(String title) => Text(title,
      style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700, color: OrgColors.charcoal));

  Widget _infoChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: OrgColors.lightGray,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OrgColors.primaryLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _socialRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 16, color: value.isNotEmpty ? OrgColors.primaryDark : OrgColors.mediumGray),
          const SizedBox(width: 10),
          Expanded(child: Text(
            value.isNotEmpty ? value : 'Not set',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: value.isNotEmpty ? OrgColors.charcoal : OrgColors.mediumGray),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      );

  Widget _statRow(String label, String value) => Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: OrgColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(value,
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: OrgColors.primaryDark)),
        ),
      ]);
}

// ─── Officer Tile ─────────────────────────────────────────────────────────────
class _OfficerTile extends StatelessWidget {
  final OfficerModel officer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OfficerTile({required this.officer, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(
        children: [
          // Avatar or photo
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: OrgColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(21),
            ),
            clipBehavior: Clip.antiAlias,
            child: officer.photoUrl.isNotEmpty
                ? _buildImageWidget(officer.photoUrl, fit: BoxFit.cover, errorWidget: _initials(officer.name))
                : _initials(officer.name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(officer.name,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700)),
                if (officer.isCaptain) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: OrgColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Captain',
                        style: GoogleFonts.beVietnamPro(fontSize: 9, fontWeight: FontWeight.w700, color: OrgColors.primaryDark)),
                  ),
                ],
              ]),
              Text(officer.position,
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.primaryDark, fontWeight: FontWeight.w600)),
              if (officer.email.isNotEmpty)
                Text(officer.email,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
              if (officer.phone.isNotEmpty)
                Text(officer.phone,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
            ]),
          ),
          // Action buttons
          Row(mainAxisSize: MainAxisSize.min, children: [
            _iconBtn(Icons.edit_outlined, OrgColors.info, onEdit),
            const SizedBox(width: 4),
            _iconBtn(Icons.delete_outline, OrgColors.error, onDelete),
          ]),
        ],
      ),
    );
  }

  Widget _initials(String name) => Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.primaryDark)),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      );
}

// ─── Hierarchy Tree ───────────────────────────────────────────────────────────
class _HierarchyTree extends StatelessWidget {
  final String orgId;
  const _HierarchyTree({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('officers')
          .orderBy('positionRank', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final officers = snap.data!.docs.map((d) => OfficerModel.fromFirestore(d)).toList();
        if (officers.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No officers to display', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
          ));
        }

        // Tier 1: rank 1 (or first item)
        // Tier 2: rank 2
        // Tier 3+: the rest
        final tier1 = officers.where((o) => o.positionRank <= 1).toList();
        final tier2 = officers.where((o) => o.positionRank == 2).toList();
        final tier3 = officers.where((o) => o.positionRank >= 3).toList();

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('orgId', isEqualTo: orgId)
              .where('role', isEqualTo: 'org')
              .limit(6)
              .get(),
          builder: (context, memberSnap) {
            final members = memberSnap.data?.docs ?? [];
            return Column(children: [
              if (tier1.isNotEmpty) ...[
                _buildTierRow(tier1, isTop: true),
                _connector(),
              ],
              if (tier2.isNotEmpty) ...[
                _buildTierRow(tier2),
                _connector(),
              ],
              if (tier3.isNotEmpty) ...[
                _buildTierRow(tier3),
                _connector(),
              ],
              // Members row
              _MembersRow(members: members),
            ]);
          },
        );
      },
    );
  }

  Widget _buildTierRow(List<OfficerModel> officers, {bool isTop = false}) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: officers.map((o) => _HierarchyBox(officer: o, isTop: isTop)).toList(),
      ),
    );
  }

  Widget _connector() => Container(
        width: 2,
        height: 24,
        margin: const EdgeInsets.symmetric(vertical: 0),
        color: OrgColors.accent.withOpacity(0.4),
      );
}

class _HierarchyBox extends StatelessWidget {
  final OfficerModel officer;
  final bool isTop;
  const _HierarchyBox({required this.officer, this.isTop = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isTop ? 160 : 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: isTop
            ? const LinearGradient(colors: [OrgColors.primaryDark, OrgColors.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isTop ? null : OrgColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isTop ? Colors.transparent : OrgColors.accent.withOpacity(0.3)),
      ),
      child: Column(children: [
        // Photo / Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isTop ? Colors.white.withOpacity(0.25) : OrgColors.accent.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: officer.photoUrl.isNotEmpty
              ? _buildImageWidget(officer.photoUrl, fit: BoxFit.cover, errorWidget: _initials(isTop))
              : _initials(isTop),
        ),
        const SizedBox(height: 8),
        Text(officer.name,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: isTop ? Colors.white : OrgColors.charcoal),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(officer.position,
            style: GoogleFonts.beVietnamPro(
                fontSize: 10, color: isTop ? Colors.white.withOpacity(0.85) : OrgColors.primaryDark),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (officer.email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(officer.email,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 9, color: isTop ? Colors.white.withOpacity(0.7) : OrgColors.darkGray),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  Widget _initials(bool isTop) => Center(
        child: Text(officer.name.isNotEmpty ? officer.name[0].toUpperCase() : '?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: isTop ? Colors.white : OrgColors.primaryDark)),
      );
}

class _MembersRow extends StatelessWidget {
  final List<QueryDocumentSnapshot> members;
  const _MembersRow({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(children: [
        Text('Members (${members.length}+)',
            style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: OrgColors.darkGray)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: members.map((m) {
            final data = m.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Member';
            final photo = data['photoUrl'] ?? '';
            return Tooltip(
              message: name,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: OrgColors.accent.withOpacity(0.15),
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(name[0].toUpperCase(),
                        style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: OrgColors.primaryDark))
                    : null,
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ─── Edit Org Profile Sheet ───────────────────────────────────────────────────
class _EditOrgProfileSheet extends StatefulWidget {
  final String orgId;
  final String orgName, shortName, email, description, schoolYear, semester, logoUrl;
  final String adviserName, adviserEmail, adviserPhone;
  final String facebook, instagram, twitter, gmail;
  final VoidCallback onSaved;

  const _EditOrgProfileSheet({
    required this.orgId,
    required this.orgName, required this.shortName, required this.email,
    required this.description, required this.schoolYear, required this.semester,
    required this.logoUrl,
    required this.adviserName, required this.adviserEmail, required this.adviserPhone,
    required this.facebook, required this.instagram, required this.twitter, required this.gmail,
    required this.onSaved,
  });

  @override
  State<_EditOrgProfileSheet> createState() => _EditOrgProfileSheetState();
}

class _EditOrgProfileSheetState extends State<_EditOrgProfileSheet> {
  final _nameCtrl    = TextEditingController();
  final _yearCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _aNameCtrl   = TextEditingController();
  final _aEmailCtrl  = TextEditingController();
  final _aPhoneCtrl  = TextEditingController();
  final _fbCtrl      = TextEditingController();
  final _igCtrl      = TextEditingController();
  final _twCtrl      = TextEditingController();
  final _gmCtrl      = TextEditingController();

  String? _logoUrl;
  String _semester = '';
  bool _isUploadingLogo = false;
  bool _isSaving = false;

  final List<String> _semesterOptions = ['1st Semester', '2nd Semester', 'Summer'];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text  = widget.orgName;
    _yearCtrl.text  = widget.schoolYear;
    _descCtrl.text  = widget.description;
    _aNameCtrl.text = widget.adviserName;
    _aEmailCtrl.text = widget.adviserEmail;
    _aPhoneCtrl.text = widget.adviserPhone;
    _fbCtrl.text    = widget.facebook;
    _igCtrl.text    = widget.instagram;
    _twCtrl.text    = widget.twitter;
    _gmCtrl.text    = widget.gmail;
    _logoUrl        = widget.logoUrl.isNotEmpty ? widget.logoUrl : null;
    _semester       = widget.semester;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _yearCtrl, _descCtrl, _aNameCtrl, _aEmailCtrl, _aPhoneCtrl, _fbCtrl, _igCtrl, _twCtrl, _gmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploadingLogo = true);
    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw 'Image bytes not available';
      final mimeType = _mimeTypeFromPath(file.path);
      final uri = 'data:$mimeType;base64,${base64Encode(bytes)}';
      setState(() => _logoUrl = uri);
    } catch (e) {
      _snack('Logo upload failed: $e');
    } finally {
      setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final orgPayload = {
      'name': _nameCtrl.text.trim(),
      'schoolYear': _yearCtrl.text.trim(),
      'semester': _semester,
      'description': _descCtrl.text.trim(),
      'adviserName': _aNameCtrl.text.trim(),
      'adviserEmail': _aEmailCtrl.text.trim(),
      'adviserPhone': _aPhoneCtrl.text.trim(),
      'facebook': _fbCtrl.text.trim(),
      'instagram': _igCtrl.text.trim(),
      'twitter': _twCtrl.text.trim(),
      'gmail': _gmCtrl.text.trim(),
      if (_logoUrl != null) 'logoUrl': _logoUrl,
    };
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).update(orgPayload);
      await _syncAdviserRoleDocs(orgPayload);
      await activity_log.ActivityLogger.log(action: 'update_org_profile', module: 'org_profile',
          details: {'orgId': widget.orgId});
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncAdviserRoleDocs(Map<String, dynamic> orgPayload) async {
    try {
      final roleSnap = await FirebaseFirestore.instance
          .collection('adviser_roles')
          .where('orgId', isEqualTo: widget.orgId)
          .get();
      final updates = <String, dynamic>{
        'orgName': orgPayload['name'],
        'adviserName': orgPayload['adviserName'],
        'adviserEmail': orgPayload['adviserEmail'],
        'adviserPhone': orgPayload['adviserPhone'],
      };
      if (widget.shortName.isNotEmpty) {
        updates['shortName'] = widget.shortName;
      }
      for (final doc in roleSnap.docs) {
        await doc.reference.update(updates);
      }
    } catch (e) {
      // Keep profile update success if role syncing fails, but log the error for debugging.
      debugPrint('Failed to sync adviser_roles for org ${widget.orgId}: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 16,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
      color: OrgColors.white,
      child: SizedBox(
        width: 460,
        height: double.infinity,
        child: Column(children: [
          // Header
          _sheetHeader('Edit Organization Profile', 'Update organization information, adviser details, and social media links'),
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Logo
                _fieldLabel('Organization Logo'),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: OrgColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: OrgColors.primaryLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logoUrl != null
                        ? _buildImageWidget(_logoUrl!, fit: BoxFit.cover, errorWidget: const Icon(Icons.business))
                        : const Icon(Icons.business, color: OrgColors.darkGray),
                  ),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: _isUploadingLogo ? null : _pickLogo,
                    icon: _isUploadingLogo
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_outlined, size: 16),
                    label: Text('Click to upload logo', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),

                // Org name + school year row
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fieldLabel('Organization Name'),
                    const SizedBox(height: 6),
                    _field(_nameCtrl, 'Organization Name'),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fieldLabel('School Year'),
                    const SizedBox(height: 6),
                    _field(_yearCtrl, '2025-2026'),
                  ])),
                ]),
                const SizedBox(height: 14),

                // Semester
                _fieldLabel('Semester'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _semesterOptions.map((s) {
                    final selected = _semester == s;
                    return ChoiceChip(
                      label: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 12,
                          color: selected ? Colors.white : OrgColors.charcoal,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                      selected: selected,
                      onSelected: (_) => setState(() => _semester = s),
                      selectedColor: OrgColors.accent,
                      backgroundColor: OrgColors.lightGray,
                      side: BorderSide(color: selected ? OrgColors.accent : OrgColors.mediumGray),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Description
                _fieldLabel('Description'),
                const SizedBox(height: 6),
                _field(_descCtrl, 'Organization description...', maxLines: 3),
                const SizedBox(height: 20),

                // Adviser section
                Text('Adviser Information',
                    style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                const Divider(height: 20),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fieldLabel('Name'),
                    const SizedBox(height: 6),
                    _field(_aNameCtrl, 'Full name'),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fieldLabel('Phone'),
                    const SizedBox(height: 6),
                    _field(_aPhoneCtrl, '+63 xxx xxx xxxx'),
                  ])),
                ]),
                const SizedBox(height: 12),
                _fieldLabel('Email'),
                const SizedBox(height: 6),
                _field(_aEmailCtrl, 'adviser@example.com'),
                const SizedBox(height: 20),

                // Social Media section
                Text('Social Media Links',
                    style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                const Divider(height: 20),
                _fieldLabel('Facebook'),
                const SizedBox(height: 6),
                _field(_fbCtrl, 'facebook.com/yourorg'),
                const SizedBox(height: 12),
                _fieldLabel('Instagram'),
                const SizedBox(height: 6),
                _field(_igCtrl, '@yourorg'),
                const SizedBox(height: 12),
                _fieldLabel('Twitter / X'),
                const SizedBox(height: 6),
                _field(_twCtrl, '@yourhandle'),
                const SizedBox(height: 12),
                _fieldLabel('Gmail'),
                const SizedBox(height: 6),
                _field(_gmCtrl, 'yourorg@gmail.com'),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          // Footer
          _sheetFooter(
            onCancel: () => Navigator.pop(context),
            onSave: _isSaving ? null : _save,
            isSaving: _isSaving,
            saveLabel: 'Save Changes',
          ),
        ]),
      ),
    );
  }

  Widget _sheetHeader(String title, String subtitle) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OrgColors.primaryLight))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w800, color: OrgColors.charcoal)),
            const SizedBox(height: 2),
            SizedBox(
              width: 360,
              child: Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
            ),
          ]),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close_rounded, size: 18, color: OrgColors.darkGray),
            ),
          ),
        ]),
      );

  Widget _sheetFooter({required VoidCallback onCancel, required VoidCallback? onSave, required bool isSaving, required String saveLabel}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: OrgColors.primaryLight))),
        child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: OrgColors.primaryLight),
            ),
            child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(saveLabel, style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      );

  Widget _fieldLabel(String label) => Text(label,
      style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.charcoal));

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
        controller: ctrl,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
          filled: true,
          fillColor: OrgColors.lightGray,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5)),
        ),
      );
}

// ─── Officer Modal ────────────────────────────────────────────────────────────
class _OfficerModal extends StatefulWidget {
  final String orgId;
  final OfficerModel? existingOfficer;
  final VoidCallback onSuccess;

  const _OfficerModal({required this.orgId, this.existingOfficer, required this.onSuccess});

  @override
  State<_OfficerModal> createState() => _OfficerModalState();
}

class _OfficerModalState extends State<_OfficerModal> {
  final _nameCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _customPosCtrl  = TextEditingController();
  final _rankCtrl       = TextEditingController();

  String? _photoUrl;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _useCustomPosition = false;
  String? _selectedPosition;
  bool _isCaptain = false;

  static const List<String> _standardPositions = [
    'President', 'Vice President', 'Secretary', 'Treasurer',
    'Business Manager', 'Board Member',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existingOfficer;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emailCtrl.text = e.email;
      _phoneCtrl.text = e.phone;
      _rankCtrl.text = e.positionRank.toString();
      _isCaptain = e.isCaptain;
      _photoUrl = e.photoUrl.isNotEmpty ? e.photoUrl : null;
      if (_standardPositions.contains(e.position)) {
        _selectedPosition = e.position;
        _useCustomPosition = false;
      } else {
        _customPosCtrl.text = e.position;
        _useCustomPosition = true;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _customPosCtrl, _rankCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw 'Image bytes not available';
      final mimeType = _mimeTypeFromPath(file.path);
      final uri = 'data:$mimeType;base64,${base64Encode(bytes)}';
      setState(() => _photoUrl = uri);
    } catch (e) {
      _snack('Photo upload failed: $e');
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  String get _resolvedPosition => _useCustomPosition ? _customPosCtrl.text.trim() : (_selectedPosition ?? '');

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _resolvedPosition.isEmpty) {
      _snack('Name and position are required');
      return;
    }
    setState(() => _isSaving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'position': _resolvedPosition,
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'positionRank': int.tryParse(_rankCtrl.text.trim()) ?? 0,
      'isCaptain': _isCaptain,
      'photoUrl': _photoUrl ?? '',
    };
    try {
      final col = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .collection('officers');
      if (widget.existingOfficer != null) {
        await col.doc(widget.existingOfficer!.id).update(data);
        await activity_log.ActivityLogger.log(action: 'edit_officer', module: 'org_profile',
            details: {'orgId': widget.orgId, 'officerId': widget.existingOfficer!.id});
      } else {
        await col.add(data);
        await activity_log.ActivityLogger.log(action: 'add_officer', module: 'org_profile',
            details: {'orgId': widget.orgId});
      }
      await _syncOrganizationOfficers();
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncOrganizationOfficers() async {
    final orgDoc = FirebaseFirestore.instance.collection('organizations').doc(widget.orgId);
    final officerSnap = await orgDoc.collection('officers')
        .orderBy('positionRank', descending: false)
        .orderBy('name', descending: false)
        .get();
    final officers = officerSnap.docs.map((d) {
      final ddata = d.data();
      return {
        'name': ddata['name'] ?? '',
        'role': ddata['position'] ?? '',
        'email': ddata['email'] ?? '',
        'phone': ddata['phone'] ?? '',
        'photoUrl': ddata['photoUrl'] ?? '',
      };
    }).toList();
    await orgDoc.update({'officers': officers});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingOfficer != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit Officer' : 'Add New Officer',
                      style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w800, color: OrgColors.charcoal)),
                  Text('Add a new officer to your organization',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                ]),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 18, color: OrgColors.darkGray),
                  ),
                ),
              ]),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Officer Photo
                    Center(
                      child: Column(children: [
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: OrgColors.lightGray,
                              shape: BoxShape.circle,
                              border: Border.all(color: OrgColors.primaryLight, width: 2),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _isUploadingPhoto
                                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                                : _photoUrl != null
                                    ? _buildImageWidget(_photoUrl!, fit: BoxFit.cover, errorWidget: _uploadIcon())
                                    : _uploadIcon(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Click to upload photo',
                            style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    // Full name
                    _fl('Full Name *'),
                    const SizedBox(height: 6),
                    _tf(_nameCtrl, 'Enter officer\'s full name'),
                    const SizedBox(height: 14),

                    // Position Type toggle
                    _fl('Position Type'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _posTypeBtn('Standard Position', !_useCustomPosition, () => setState(() => _useCustomPosition = false))),
                      const SizedBox(width: 10),
                      Expanded(child: _posTypeBtn('Custom Position', _useCustomPosition, () => setState(() => _useCustomPosition = true))),
                    ]),
                    const SizedBox(height: 12),

                    if (!_useCustomPosition) ...[
                      _fl('Select Position'),
                      const SizedBox(height: 8),
                      _PositionDropdown(
                        positions: _standardPositions,
                        selected: _selectedPosition,
                        onSelected: (p) => setState(() => _selectedPosition = p),
                      ),
                    ] else ...[
                      _fl('Custom Position'),
                      const SizedBox(height: 6),
                      _tf(_customPosCtrl, 'e.g. Social Media Manager'),
                    ],
                    const SizedBox(height: 14),

                    // Guest Rank / isCaptain row
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fl('Guest Rank'),
                        const SizedBox(height: 6),
                        _tf(_rankCtrl, '0', keyboardType: TextInputType.number),
                      ])),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fl('Captain'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Switch(
                            value: _isCaptain,
                            onChanged: (v) => setState(() => _isCaptain = v),
                            activeColor: OrgColors.accent,
                          ),
                          Text(_isCaptain ? 'Yes' : 'No',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                        ]),
                      ])),
                    ]),
                    const SizedBox(height: 14),

                    // Email + Phone
                    _fl('Email'),
                    const SizedBox(height: 6),
                    _tf(_emailCtrl, 'officer@example.com'),
                    const SizedBox(height: 12),
                    _fl('Phone'),
                    const SizedBox(height: 6),
                    _tf(_phoneCtrl, '+63 912 345 6789'),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: OrgColors.primaryLight))),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: OrgColors.primaryLight),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrgColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Update Officer' : 'Add Officer',
                          style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadIcon() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.camera_alt_outlined, size: 24, color: OrgColors.darkGray),
      ]);

  Widget _fl(String label) => Text(label,
      style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.charcoal));

  Widget _tf(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) => TextField(
        controller: ctrl,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
          filled: true,
          fillColor: OrgColors.lightGray,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5)),
        ),
      );

  Widget _posTypeBtn(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? OrgColors.accent.withOpacity(0.12) : OrgColors.lightGray,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? OrgColors.accent : OrgColors.mediumGray, width: selected ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 18, color: selected ? OrgColors.accent : OrgColors.darkGray),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.beVietnamPro(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: selected ? OrgColors.primaryDark : OrgColors.darkGray),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ─── Position Dropdown ────────────────────────────────────────────────────────
class _PositionDropdown extends StatefulWidget {
  final List<String> positions;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _PositionDropdown({required this.positions, required this.selected, required this.onSelected});

  @override
  State<_PositionDropdown> createState() => _PositionDropdownState();
}

class _PositionDropdownState extends State<_PositionDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _open ? OrgColors.primaryLight : OrgColors.mediumGray, width: _open ? 1.5 : 1),
            ),
            child: Row(children: [
              Expanded(child: Text(
                widget.selected ?? 'Choose a position',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: widget.selected != null ? OrgColors.charcoal : OrgColors.darkGray),
              )),
              Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: OrgColors.darkGray),
            ]),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: OrgColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OrgColors.primaryLight),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: widget.positions.map((pos) {
                final isSelected = widget.selected == pos;
                return InkWell(
                  onTap: () {
                    widget.onSelected(pos);
                    setState(() => _open = false);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: isSelected ? OrgColors.accent.withOpacity(0.08) : Colors.transparent,
                    child: Text(pos, style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? OrgColors.primaryDark : OrgColors.charcoal)),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── Officer Model ─────────────────────────────────────────────────────────────
class OfficerModel {
  final String id;
  final String name;
  final String position;
  final String email;
  final String phone;
  final int positionRank;
  final bool isCaptain;
  final String photoUrl;

  const OfficerModel({
    required this.id,
    required this.name,
    required this.position,
    required this.email,
    required this.phone,
    required this.positionRank,
    this.isCaptain = false,
    this.photoUrl = '',
  });

  factory OfficerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfficerModel(
      id: doc.id,
      name: data['name'] ?? '',
      position: data['position'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      positionRank: data['positionRank'] ?? 0,
      isCaptain: data['isCaptain'] ?? false,
      photoUrl: data['photoUrl'] ?? '',
    );
  }
}




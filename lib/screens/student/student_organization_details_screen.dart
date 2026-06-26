// lib/screens/student/student_organization_details_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/student/app_colors.dart';
import 'student_broadcast_screen.dart';


// ─────────────────────────────────────────────────────────────
//  ORGANIZATION DETAILS SCREEN
// ─────────────────────────────────────────────────────────────
class StudentOrganizationsDetailsScreen extends StatefulWidget {
  final String orgId;
  const StudentOrganizationsDetailsScreen({super.key, required this.orgId});

  @override
  State<StudentOrganizationsDetailsScreen> createState() =>
      _StudentOrganizationsDetailsScreenState();
}

class _StudentOrganizationsDetailsScreenState
    extends State<StudentOrganizationsDetailsScreen> {
  bool _coverImageFailed = false;

  ImageProvider? _buildLogoImage(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) return null;

    if (logoUrl.startsWith('data:')) {
      try {
        final base64Str = logoUrl.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }

    return NetworkImage(logoUrl);
  }

  DecorationImage? _buildCoverImage(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty) return null;

    if (coverUrl.startsWith('data:')) {
      try {
        final base64Str = coverUrl.split(',').last;
        return DecorationImage(
          image: MemoryImage(base64Decode(base64Str)),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return null;
      }
    }

    return DecorationImage(
      image: NetworkImage(coverUrl),
      fit: BoxFit.cover,
      onError: (_, __) {
        if (mounted && !_coverImageFailed) {
          setState(() => _coverImageFailed = true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final org = snapshot.data!.data() as Map<String, dynamic>;
          final officers = (org['officers'] as List?) ?? [];
          final events = (org['events'] as List?) ?? [];
          final announcements = (org['announcements'] as List?) ?? [];

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text(
                'Organization',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentBroadcastScreen(
                          orgId: widget.orgId,
                          orgName: org['name'] ?? 'Organization',
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.radio, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover Image ──
                  Stack(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.1),
                          image: _coverImageFailed
                              ? null
                              : _buildCoverImage(org['coverUrl']),
                        ),
                        child: (org['coverUrl'] == null ||
                                (org['coverUrl'] as String).isEmpty ||
                                _coverImageFailed)
                            ? Center(
                                child: Icon(
                                  Icons.business,
                                  size: 60,
                                  color: AppColors.primaryDark.withOpacity(0.3),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -30,
                        left: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white,
                            backgroundImage: _buildLogoImage(org['logoUrl']),
                            child: (org['logoUrl'] == null ||
                                    (org['logoUrl'] as String).isEmpty)
                                ? Text(
                                    (org['name'] ?? 'O')[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // ── Organization Info ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          org['category'] ?? 'Student Council',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            'ACCREDITED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── ABOUT ──
                        const Text(
                          'ABOUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          org['description'] ?? 'No description available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Organization Adviser(s) ──
                        Builder(builder: (context) {
                          final adviserList = (org['advisers'] as List?)
                              ?.whereType<Map<String, dynamic>>()
                              .toList();
                          final hasMultiple = adviserList != null && adviserList.isNotEmpty;
                          final photoUrl = org['adviserPhotoUrl'] as String?;
                          ImageProvider? photoProvider;
                          if (photoUrl != null && photoUrl.isNotEmpty) {
                            try {
                              photoProvider = photoUrl.startsWith('data:')
                                  ? MemoryImage(base64Decode(photoUrl.split(',').last))
                                  : NetworkImage(photoUrl) as ImageProvider;
                            } catch (_) {}
                          }
                          final advisersToShow = hasMultiple
                              ? adviserList!
                              : [
                                  {
                                    'name': org['adviserName'] ?? 'No adviser listed',
                                    'title': org['adviserTitle'],
                                  }
                                ];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final adv in advisersToShow)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        photoProvider != null
                                            ? CircleAvatar(radius: 20, backgroundImage: photoProvider)
                                            : Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryDark.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.person_outline, color: AppColors.primaryDark),
                                              ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Organization Adviser',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text(
                                                (adv['name'] ?? 'No adviser listed').toString(),
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                              ),
                                              if ((adv['title'] ?? '').toString().isNotEmpty)
                                                Text((adv['title']).toString(),
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // ── Connect / Social Links ──
                        if ([org['facebook'], org['instagram'], org['twitter'], org['gmail']]
                            .any((v) => (v ?? '').toString().trim().isNotEmpty)) ...[
                          const Text('Connect',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if ((org['facebook'] ?? '').toString().trim().isNotEmpty)
                                _SocialChip(icon: Icons.facebook_rounded, label: 'Facebook', url: org['facebook']),
                              if ((org['instagram'] ?? '').toString().trim().isNotEmpty)
                                _SocialChip(icon: Icons.camera_alt_outlined, label: 'Instagram', url: org['instagram']),
                              if ((org['twitter'] ?? '').toString().trim().isNotEmpty)
                                _SocialChip(icon: Icons.alternate_email_rounded, label: 'Twitter/X', url: org['twitter']),
                              if ((org['gmail'] ?? '').toString().trim().isNotEmpty)
                                _SocialChip(icon: Icons.email_outlined, label: org['gmail'], url: 'mailto:${org['gmail']}'),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ] else
                          const SizedBox(height: 8),

                        // ── Executive Officers ──
                        const Text(
                          'Executive Officers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (officers.isEmpty)
                          Text(
                            'No officers listed',
                            style: TextStyle(color: Colors.grey[500]),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: officers.length,
                            separatorBuilder: (_, __) => const Divider(height: 0),
                            itemBuilder: (context, index) {
                              final officer = officers[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                                  backgroundImage: _buildLogoImage(
                                      officer['photoUrl']),
                                  child: (officer['photoUrl'] == null ||
                                          (officer['photoUrl'] as String?)
                                                  ?.isEmpty ==
                                              true)
                                      ? Text(
                                          (officer['name'] ?? '')[0].toUpperCase(),
                                          style: TextStyle(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  officer['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  officer['position'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // ── Upcoming Events ──
                        const Text(
                          'Upcoming Events',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (events.isEmpty)
                          Text(
                            'No upcoming events',
                            style: TextStyle(color: Colors.grey[500]),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryDark.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            (event['date'] ?? '')
                                                .toString()
                                                .split(' ')
                                                .first,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                          Text(
                                            (event['date'] ?? '')
                                                .toString()
                                                .split(' ')
                                                .last,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primaryDark.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event['title'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 12,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                event['location'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                event['time'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // ── Recent Announcements ──
                        const Text(
                          'Recent Announcements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (announcements.isEmpty)
                          Text(
                            'No announcements available',
                            style: TextStyle(color: Colors.grey[500]),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: announcements.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final announcement = announcements[index];
                              final isUrgent =
                                  announcement['type'] == 'urgent' ||
                                      (announcement['title'] ?? '')
                                          .contains('URGENT');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUrgent
                                      ? Colors.red[50]
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isUrgent
                                      ? Border.all(color: Colors.red[200]!)
                                      : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isUrgent
                                            ? Colors.red[100]
                                            : AppColors.primaryDark.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isUrgent
                                            ? Icons.priority_high
                                            : Icons.campaign,
                                        size: 18,
                                        color: isUrgent
                                            ? Colors.red
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            announcement['title'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isUrgent
                                                  ? Colors.red[800]
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            announcement['content'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            announcement['timeAgo'] ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  const _SocialChip({required this.icon, required this.label, required this.url});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null && await canLaunchUrl(uri)
        ? await launchUrl(uri, mode: LaunchMode.externalApplication)
        : false;
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryDark.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ]),
      ),
    );
  }
}
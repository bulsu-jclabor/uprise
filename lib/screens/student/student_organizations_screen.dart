// lib/screens/student/student_organizations_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/student/app_colors.dart';
import 'student_organization_details_screen.dart';

// ─────────────────────────────────────────────────────────────
// Shared style tokens (kept consistent with the rest of the app)
// ─────────────────────────────────────────────────────────────
class _UiTokens {
  static const Color divider = Color(0xFFE7E7E9);
  static const Color cardBorder = Color(0xFFEDEDEF);
  static const Color mutedText = Color(0xFF6B6B70);
  static const Color headingText = Color(0xFF1B1B1D);

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────
//  MAIN ORGANIZATIONS SCREEN
// ─────────────────────────────────────────────────────────────
class StudentOrganizationsScreen extends StatefulWidget {
  const StudentOrganizationsScreen({super.key});

  @override
  State<StudentOrganizationsScreen> createState() =>
      _StudentOrganizationsScreenState();
}

class _StudentOrganizationsScreenState extends State<StudentOrganizationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Organizations',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: _UiTokens.headingText,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _UiTokens.headingText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _UiTokens.divider),
        ),
      ),
      body: _buildDiscoverTab(),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // ── Search Bar ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchQuery.isNotEmpty
                    ? AppColors.primaryDark.withOpacity(0.5)
                    : _UiTokens.divider,
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search organizations',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty ? AppColors.primaryDark : Colors.grey.shade500,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.primaryDark),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),

        // ── Organizations Grid ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('organizations')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDark,
                    strokeWidth: 2.2,
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDark,
                    strokeWidth: 2.2,
                  ),
                );
              }

              var docs = snapshot.data!.docs;

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final org = doc.data() as Map<String, dynamic>;
                  final name = (org['name'] ?? '').toLowerCase();
                  final description = (org['description'] ?? '').toLowerCase();
                  return name.contains(_searchQuery) ||
                      description.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.business_outlined,
                            size: 42,
                            color: AppColors.primaryDark.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No organizations found'
                              : 'No organizations available',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _UiTokens.headingText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'Check back later',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final org = doc.data() as Map<String, dynamic>;
                  final name = org['name'] ?? 'Organization';
                  final description = org['description'] ?? '';
                  final logoUrl = org['logoUrl'] as String?;
                  final category = org['category'] ?? '';

                  return _OrganizationCard(
                    id: doc.id,
                    name: name,
                    description: description,
                    logoUrl: logoUrl,
                    category: category,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ORGANIZATION CARD
// ─────────────────────────────────────────────────────────────
class _OrganizationCard extends StatelessWidget {
  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String category;

  const _OrganizationCard({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.category,
  });

  ImageProvider? _buildLogoImage() {
    if (logoUrl == null || logoUrl!.isEmpty) return null;

    if (logoUrl!.startsWith('data:')) {
      try {
        final base64Str = logoUrl!.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }

    return NetworkImage(logoUrl!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentOrganizationsDetailsScreen(orgId: id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _UiTokens.cardBorder,
            width: 1,
          ),
          boxShadow: _UiTokens.subtleShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo / Image Section ──
            SizedBox(
              height: 96,
              width: double.infinity,
              child: _buildLogoImage() != null
                  ? Image(
                      image: _buildLogoImage()!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Name ──
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _UiTokens.headingText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // ── Description ──
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: _UiTokens.mutedText,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // ── Category Badge ──
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryDark.withOpacity(0.16),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppColors.primaryDark,
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

  Widget _buildPlaceholder() {
    return Container(
      height: 96,
      width: double.infinity,
      color: AppColors.primaryDark.withOpacity(0.06),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}
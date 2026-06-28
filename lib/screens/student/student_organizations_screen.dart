// lib/screens/student/student_organizations_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/student/app_colors.dart';
import 'student_organization_details_screen.dart';


// ─────────────────────────────────────────────────────────────
//  MAIN ORGANIZATIONS SCREEN - BETTER COLORS
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
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? AppColors.primaryDark : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty ? AppColors.primaryDark : Colors.grey.shade500,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: AppColors.primaryDark),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryDark.withOpacity(0.3),
                    width: 1.5,
                  ),
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
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDark,
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
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.business_outlined,
                            size: 48,
                            color: AppColors.primaryDark.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No organizations found'
                              : 'No organizations available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'Check back later',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
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
//  ORGANIZATION CARD - BETTER COLORS
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryDark.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo / Image Section ──
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _buildLogoImage() != null
                    ? Image(
                        image: _buildLogoImage()!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
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
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // ── Category Badge ──
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
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
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark.withOpacity(0.15),
          ),
        ),
      ),
    );
  }
}
// lib/screens/student/student_organizations_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_organization_details_screen.dart';

// ─────────────────────────────────────────────────────────────
//  CUSTOM COLORS - UNIFORM (Colors.orange)
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF5F5F5);
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
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildDiscoverTab(),
    );
  }

  // ── DISCOVER TAB ──
  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Organizations List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('organizations')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs;

              // Filter by search query
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No organizations found'
                            : 'No organizations available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try a different search term'
                            : 'Check back later for new organizations',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final org = docs[index].data() as Map<String, dynamic>;
                  final logoUrl = org['logoUrl'] as String?;
                  final name = org['name'] ?? 'Organization';
                  final description = org['description'] ?? '';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentOrganizationsDetailsScreen(orgId: docs[index].id),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Logo
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _buildLogoImage(logoUrl) != null
                                    ? Image(
                                        image: _buildLogoImage(logoUrl)!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          name[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
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
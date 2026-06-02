// lib/screens/web/org/org_merchandise.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:universal_html/html.dart' as html;
import '../../../services/activity_logger.dart' as activity_log;
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_export_button.dart';
import '../admin/export_util.dart';
import '../admin/export_pdf.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (mirrors student accounts)
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm = 8;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      labelStyle: GoogleFonts.beVietnamPro(
          fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(
          fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge (reused)
// ─────────────────────────────────────────────────────────────────────────────
Widget _statusBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'published': _BadgeStyle(const Color(0xFFECFDF5), const Color(0xFF059669), 'PUBLISHED'),
    'draft': _BadgeStyle(const Color(0xFFFFFBEB), const Color(0xFFD97706), 'DRAFT'),
    'archived': _BadgeStyle(const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'ARCHIVED'),
  };
  final s = styles[status.toLowerCase()] ??
      _BadgeStyle(const Color(0xFFF3F4F6), const Color(0xFF6B7280), status.toUpperCase());
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: s.bg,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      s.label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: s.fg,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgMerchandiseScreen extends StatefulWidget {
  final String orgId;
  const OrgMerchandiseScreen({super.key, required this.orgId});

  @override
  State<OrgMerchandiseScreen> createState() => _OrgMerchandiseScreenState();
}

class _OrgMerchandiseScreenState extends State<OrgMerchandiseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ProductsTab(orgId: widget.orgId),
                _OrdersTab(orgId: widget.orgId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('orgId', isEqualTo: widget.orgId)
          .where('isArchived', isEqualTo: false)
          .snapshots(),
      builder: (context, productSnap) {
        final products = productSnap.data?.docs ?? [];
        final totalProducts = products.length;
        final lowStock = products.where((p) => ((p.data() as Map)['stock'] ?? 0) <= 5).length;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('orgId', isEqualTo: widget.orgId)
              .snapshots(),
          builder: (context, orderSnap) {
            final orders = orderSnap.data?.docs ?? [];
            final totalSales = orders.length;
            double totalRevenue = 0;
            for (final doc in orders) {
              totalRevenue += ((doc.data() as Map)['total'] ?? 0).toDouble();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Row(children: [
                _StatCard(
                  label: 'Total Products',
                  value: totalProducts.toString(),
                  icon: Icons.shopping_bag_outlined,
                  color: UpriseColors.info,
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'Total Sales',
                  value: totalSales.toString(),
                  icon: Icons.shopping_cart_outlined,
                  color: UpriseColors.success,
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'Total Revenue',
                  value: '₱${NumberFormat('#,###').format(totalRevenue)}',
                  icon: Icons.payments_outlined,
                  color: UpriseColors.warning,
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'Low Stock',
                  value: lowStock.toString(),
                  icon: Icons.warning_amber_outlined,
                  color: lowStock > 0 ? UpriseColors.error : const Color(0xFF6B7280),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          // Tab pills (kept for consistency)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E6EA)),
            ),
            child: Row(
              children: [
                _PillTab(
                  label: 'Products',
                  selected: _selectedTab == 0,
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _selectedTab = 0);
                  },
                ),
                _PillTab(
                  label: 'Orders',
                  selected: _selectedTab == 1,
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() => _selectedTab = 1);
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          // Export button (will show different options based on active tab)
          AdminExportButton(onSelected: (format) => _exportCurrentTab(format)),
          const SizedBox(width: 10),
          // Sales Report button
          OutlinedButton.icon(
            onPressed: () => _openSalesReport(context),
            icon: const Icon(Icons.bar_chart_outlined, size: 16),
            label: Text('Sales Report',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: UpriseColors.primaryDark,
              side: BorderSide(color: UpriseColors.primaryDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          // Add Product button
          ElevatedButton.icon(
            onPressed: () => _openAddProductModal(context),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: Text('Add Product',
                style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UpriseColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCurrentTab(String format) async {
    if (_selectedTab == 0) {
      await _exportProducts(format);
    } else {
      await _exportOrders(format);
    }
  }

  Future<void> _exportProducts(String format) async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where('orgId', isEqualTo: widget.orgId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    final docs = snap.docs;
    if (docs.isEmpty) {
      _showSnack('No products to export', UpriseColors.warning);
      return;
    }
    final now = DateFormat('yyyyMMdd').format(DateTime.now());
    if (format == 'csv') {
      final buf = StringBuffer();
      buf.writeln('Product Name,Category,Price,Stock,Sold');
      for (final doc in docs) {
        final d = doc.data();
        buf.writeln('"${d['name']}","${d['category']}","${d['price']}","${d['stock']}","${d['sold']}"');
      }
      await AdminExportUtil.saveText(buf.toString(), 'products_$now.csv', mimeType: 'text/csv');
    } else if (format == 'pdf') {
      final rows = docs.map((doc) {
        final d = doc.data();
        return ['${d['name']}', '${d['category']}', '${d['price']}', '${d['stock']}', '${d['sold']}'];
      }).toList();
      final pdfBytes = await AdminExportPdf.generateTablePdf(
        title: 'Product Inventory',
        headers: const ['Name', 'Category', 'Price', 'Stock', 'Sold'],
        rows: rows,
      );
      await AdminExportUtil.saveBytes(pdfBytes, 'products_$now.pdf', mimeType: 'application/pdf');
    }
    _showSnack('Exported products', UpriseColors.success);
  }

  Future<void> _exportOrders(String format) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('orgId', isEqualTo: widget.orgId)
        .orderBy('createdAt', descending: true)
        .get();
    final docs = snap.docs;
    if (docs.isEmpty) {
      _showSnack('No orders to export', UpriseColors.warning);
      return;
    }
    final now = DateFormat('yyyyMMdd').format(DateTime.now());
    if (format == 'csv') {
      final buf = StringBuffer();
      buf.writeln('Order ID,Customer,Total,Status,Date');
      for (final doc in docs) {
        final d = doc.data();
        final date = DateFormat('yyyy-MM-dd').format((d['createdAt'] as Timestamp).toDate());
        buf.writeln('"${d['orderId']}","${d['customerName']}","${d['total']}","${d['status']}","$date"');
      }
      await AdminExportUtil.saveText(buf.toString(), 'orders_$now.csv', mimeType: 'text/csv');
    } else if (format == 'pdf') {
      final rows = docs.map((doc) {
        final d = doc.data();
        final date = DateFormat('yyyy-MM-dd').format((d['createdAt'] as Timestamp).toDate());
        return ['${d['orderId']}', '${d['customerName']}', '${d['total']}', '${d['status']}', date];
      }).toList();
      final pdfBytes = await AdminExportPdf.generateTablePdf(
        title: 'Sales Orders',
        headers: const ['Order ID', 'Customer', 'Total', 'Status', 'Date'],
        rows: rows,
      );
      await AdminExportUtil.saveBytes(pdfBytes, 'orders_$now.pdf', mimeType: 'application/pdf');
    }
    _showSnack('Exported orders', UpriseColors.success);
  }

  void _openAddProductModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductModal(orgId: widget.orgId),
    );
  }

  void _openSalesReport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _SalesReportModal(orgId: widget.orgId),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill Tab
// ─────────────────────────────────────────────────────────────────────────────
class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Card (matches student accounts)
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCTS TAB (table layout, pagination)
// ============================================================
class _ProductsTab extends StatefulWidget {
  final String orgId;
  const _ProductsTab({required this.orgId});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  final List<String> _categoryFilters = ['All', 'Apparel', 'Accessories'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('products')
      .where('orgId', isEqualTo: widget.orgId)
      .where('isArchived', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots();

  List<ProductModel> _applyFilters(List<ProductModel> list) {
    return list.where((p) {
      final matchSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCat = _categoryFilter == 'All' || p.category == _categoryFilter;
      return matchSearch && matchCat;
    }).toList();
  }

  Future<void> _archiveProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Archive Product', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Text('Archive "${product.name}"? It will be hidden from the store.', style: GoogleFonts.beVietnamPro()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.beVietnamPro())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.warning, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Archive', style: GoogleFonts.beVietnamPro(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('products').doc(product.id).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
      await activity_log.ActivityLogger.log(
        action: 'archive_product',
        module: 'merchandise',
        details: {'orgId': widget.orgId, 'productId': product.id, 'name': product.name},
      );
      if (mounted) _showSnack('Product archived', UpriseColors.success);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', UpriseColors.error);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(child: _buildTable()),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _currentPage = 1;
              }),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Category filter dropdown
          _FilterDropdown(
            value: _categoryFilter,
            items: _categoryFilters,
            hint: 'Category',
            icon: Icons.category_outlined,
            onChanged: (v) => setState(() {
              _categoryFilter = v!;
              _currentPage = 1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        var allProducts = snapshot.data!.docs.map((d) => ProductModel.fromFirestore(d)).toList();
        allProducts = _applyFilters(allProducts);

        final totalPages = allProducts.isEmpty ? 1 : (allProducts.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, allProducts.length);
        final pageProducts = allProducts.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: allProducts.isEmpty
                    ? _buildEmptyState(Icons.inventory_2_outlined, 'No products yet', 'Click "Add Product" to get started.')
                    : ListView.builder(
                        itemCount: pageProducts.length,
                        itemBuilder: (_, i) => _buildProductRow(pageProducts[i], isLast: i == pageProducts.length - 1),
                      ),
              ),
              _buildFooter(allProducts.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: _headerCell('PRODUCT')),
        Expanded(flex: 1, child: _headerCell('CATEGORY')),
        Expanded(flex: 1, child: _headerCell('PRICE')),
        Expanded(flex: 1, child: _headerCell('STOCK')),
        Expanded(flex: 1, child: _headerCell('SOLD')),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(text,
      style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.7));

  Widget _buildProductRow(ProductModel product, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, size: 18, color: UpriseColors.primaryDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
                          overflow: TextOverflow.ellipsis),
                      if (product.stock <= 5)
                        Text('Low stock',
                            style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.error, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark.withAlpha(18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(product.category,
                  style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text('₱${NumberFormat('#,###').format(product.price)}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
          ),
          Expanded(
            flex: 1,
            child: Text('${product.stock}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
          ),
          Expanded(
            flex: 1,
            child: Text('${product.sold}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  onTap: () => showDialog(context: context, builder: (_) => _ProductDetailsModal(product: product)),
                ),
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onTap: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _ProductModal(orgId: widget.orgId, existingProduct: product),
                  ),
                ),
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.archive_outlined,
                  tooltip: 'Archive',
                  color: UpriseColors.warning,
                  onTap: () => _archiveProduct(product),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total products',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          Row(children: [
            _PageButton(icon: Icons.chevron_left_rounded, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
            if (lastPage < totalPages) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12))),
              _PageNumButton(page: totalPages, isActive: _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
            ],
            const SizedBox(width: 4),
            _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
          ]),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 40, color: const Color(0xFF9AA5B4))),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ============================================================
// ORDERS TAB (table layout)
// ============================================================
class _OrdersTab extends StatefulWidget {
  final String orgId;
  const _OrdersTab({required this.orgId});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  final List<String> _statusFilters = ['All', 'Pending', 'Processing', 'Completed'];

  List<OrderModel> _applyFilters(List<OrderModel> orders) {
    return orders.where((o) {
      final matchSearch = _searchQuery.isEmpty ||
          o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.orderId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchStatus = _statusFilter == 'All' || o.status.toLowerCase() == _statusFilter.toLowerCase();
      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(child: _buildTable()),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _currentPage = 1;
              }),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search orders...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _statusFilter,
            items: _statusFilters,
            hint: 'Status',
            icon: Icons.tune_rounded,
            onChanged: (v) => setState(() {
              _statusFilter = v!;
              _currentPage = 1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('orgId', isEqualTo: widget.orgId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        var allOrders = snapshot.data!.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        allOrders = _applyFilters(allOrders);

        final totalPages = allOrders.isEmpty ? 1 : (allOrders.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, allOrders.length);
        final pageOrders = allOrders.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: allOrders.isEmpty
                    ? _buildEmptyState(Icons.shopping_cart_outlined, 'No orders yet', 'Orders will appear here after checkout.')
                    : ListView.builder(
                        itemCount: pageOrders.length,
                        itemBuilder: (_, i) => _buildOrderRow(pageOrders[i], isLast: i == pageOrders.length - 1),
                      ),
              ),
              _buildFooter(allOrders.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: _headerCell('ORDER ID')),
        Expanded(flex: 2, child: _headerCell('CUSTOMER')),
        Expanded(flex: 2, child: _headerCell('DATE')),
        Expanded(flex: 1, child: _headerCell('TOTAL')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(text,
      style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.7));

  Widget _buildOrderRow(OrderModel order, {required bool isLast}) {
    final date = DateFormat('MMM d, yyyy').format(order.createdAt.toDate());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(order.orderId,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C))),
                Text(order.customerEmail,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(date, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            flex: 1,
            child: Text('₱${NumberFormat('#,###.00').format(order.total)}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
          ),
          Expanded(flex: 1, child: _statusBadge(order.status)),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  onTap: () => showDialog(context: context, builder: (_) => _OrderDetailsModal(order: order)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total orders',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          Row(children: [
            _PageButton(icon: Icons.chevron_left_rounded, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
            if (lastPage < totalPages) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12))),
              _PageNumButton(page: totalPages, isActive: _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
            ],
            const SizedBox(width: 4),
            _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
          ]),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 40, color: const Color(0xFF9AA5B4))),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets (from student accounts)
// ─────────────────────────────────────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({required this.value, required this.items, required this.hint, required this.icon, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E6EA))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: onTap == null ? const Color(0xFFD1D5DB) : (color ?? const Color(0xFF64748B))),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 20, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB))),
    );
  }
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$page',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: isActive ? Colors.white : const Color(0xFF374151))),
      ),
    );
  }
}

// ============================================================
// PRODUCT MODAL (restyled like manual add student)
// ============================================================
class _ProductModal extends StatefulWidget {
  final String orgId;
  final ProductModel? existingProduct;
  const _ProductModal({required this.orgId, this.existingProduct});

  @override
  State<_ProductModal> createState() => _ProductModalState();
}

class _ProductModalState extends State<_ProductModal> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String _category = 'Apparel';
  bool _submitting = false;

  bool get _isEdit => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.existingProduct!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      _priceCtrl.text = p.price.toStringAsFixed(2);
      _stockCtrl.text = p.stock.toString();
      _category = p.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Product name is required');
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim()) ?? -1;
    if (price <= 0) {
      _showError('Enter a valid price');
      return;
    }
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? -1;
    if (stock < 0) {
      _showError('Enter a valid stock quantity');
      return;
    }

    setState(() => _submitting = true);
    final user = FirebaseAuth.instance.currentUser;
    final data = <String, dynamic>{
      'orgId': widget.orgId,
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'category': _category,
      'price': price,
      'stock': stock,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEdit) {
        await FirebaseFirestore.instance.collection('products').doc(widget.existingProduct!.id).update(data);
        await activity_log.ActivityLogger.log(action: 'edit_product', module: 'merchandise', details: {'orgId': widget.orgId, 'productId': widget.existingProduct!.id});
      } else {
        data['sold'] = 0;
        data['isArchived'] = false;
        data['imageUrl'] = '';
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = user?.uid ?? '';
        await FirebaseFirestore.instance.collection('products').add(data);
        await activity_log.ActivityLogger.log(action: 'create_product', module: 'merchandise', details: {'orgId': widget.orgId, 'name': data['name']});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.beVietnamPro()), backgroundColor: UpriseColors.error,
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isEdit ? 'Edit Product' : 'Add Product', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                      if (_isEdit && widget.existingProduct != null)
                        Text('PRODUCT ID: #${widget.existingProduct!.id.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.beVietnamPro(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                ),
              ]),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Product Information', icon: Icons.info_outline_rounded),
                    // Category toggle
                    Text('Category', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E6EA)),
                      ),
                      child: Row(
                        children: ['Apparel', 'Accessories'].map((c) {
                          final sel = _category == c;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _category = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.all(3),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel ? UpriseColors.primaryDark : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(c,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF64748B))),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _DS.inputDecoration('Product Name', hint: 'e.g., Premium Shirt 2026', icon: Icons.label_outline_rounded),
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: _DS.inputDecoration('Description', hint: 'Product details...', icon: Icons.description_outlined),
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    // Price & Stock row
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: _DS.inputDecoration('Price', hint: '0.00', icon: Icons.attach_money_outlined),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _DS.inputDecoration('Stock Quantity', hint: '0', icon: Icons.inventory_2_outlined),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isEdit ? 'Save Changes' : 'Add Product', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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

  Widget _sectionLabel(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 16, color: UpriseColors.primaryDark), const SizedBox(width: 8)],
        Text(text, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark, letterSpacing: 0.3)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
      ]),
    );
  }
}

// ============================================================
// PRODUCT DETAILS MODAL (simplified but clean)
// ============================================================
class _ProductDetailsModal extends StatelessWidget {
  final ProductModel product;
  const _ProductDetailsModal({required this.product});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: UpriseColors.primaryDark.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shopping_bag_outlined, size: 20, color: UpriseColors.primaryDark)),
              const SizedBox(width: 14),
              Expanded(child: Text(product.name, style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B))),
            ]),
            const SizedBox(height: 16),
            _detailItem('Category', product.category),
            _detailItem('Price', '₱${NumberFormat('#,###').format(product.price)}'),
            _detailItem('Stock', '${product.stock} units'),
            _detailItem('Sold', '${product.sold} units'),
            if (product.description.isNotEmpty) _detailItem('Description', product.description),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C))),
        ],
      ),
    );
  }
}

// ============================================================
// ORDER DETAILS MODAL (restyled)
// ============================================================
class _OrderDetailsModal extends StatelessWidget {
  final OrderModel order;
  const _OrderDetailsModal({required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: UpriseColors.primaryDark.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_outlined, size: 18, color: UpriseColors.primaryDark)),
                const SizedBox(width: 14),
                Expanded(child: Text('Order Details', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B))),
              ]),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${order.orderId}', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    _sectionTitle('Customer Information'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.person_outline, order.customerName),
                    _infoRow(Icons.email_outlined, order.customerEmail),
                    _infoRow(Icons.phone_outlined, order.customerPhone),
                    if (order.customerAddress.isNotEmpty) _infoRow(Icons.location_on_outlined, order.customerAddress),
                    const SizedBox(height: 16),
                    _sectionTitle('Order Items'),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(width: 40, height: 40, decoration: BoxDecoration(color: UpriseColors.primaryDark.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.shopping_bag_outlined, size: 20, color: UpriseColors.primaryDark)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('₱${NumberFormat('#,###').format(item.price)} each', style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Qty: ${item.quantity}', style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                                  Text('₱${NumberFormat('#,###.00').format(item.totalPrice)}',
                                      style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
                                ],
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    _sectionTitle('Order Summary'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E6EA))),
                      child: Column(
                        children: [
                          _summaryLine('Subtotal', '₱${NumberFormat('#,###.00').format(order.total)}'),
                          const SizedBox(height: 4),
                          _summaryLine('Payment Method', order.paymentMethod),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: const Color(0xFFE2E6EA), height: 1)),
                          _summaryLine('Total Amount', '₱${NumberFormat('#,###.00').format(order.total)}', bold: true, valueColor: UpriseColors.primaryDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Order Timeline'),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text('Order placed: ${DateFormat('MMM d, yyyy h:mm a').format(order.createdAt.toDate())}',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                    ]),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Close', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C)));
  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Icon(icon, size: 14, color: const Color(0xFF64748B)), const SizedBox(width: 6), Expanded(child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 12)))]),
      );
  Widget _summaryLine(String label, String value, {bool bold = false, Color? valueColor}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: valueColor)),
        ],
      );
}

// ============================================================
// SALES REPORT MODAL (restyled)
// ============================================================
class _SalesReportModal extends StatelessWidget {
  final String orgId;
  const _SalesReportModal({required this.orgId});

  void _exportReport(BuildContext context, List<OrderModel> orders) {
    final buf = StringBuffer();
    buf.writeln('MERCHANDISE SALES REPORT');
    buf.writeln('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}\n');
    buf.writeln('Order ID,Customer,Total,Status,Date');
    for (final o in orders) {
      final date = DateFormat('MM/dd/yyyy').format(o.createdAt.toDate());
      buf.writeln('"${o.orderId}","${o.customerName}","${o.total.toStringAsFixed(2)}","${o.status}","$date"');
    }
    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'sales_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 720,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').where('orgId', isEqualTo: orgId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            final orders = snapshot.hasData ? snapshot.data!.docs.map((d) => OrderModel.fromFirestore(d)).toList() : <OrderModel>[];

            double totalRevenue = 0;
            int completed = 0, processing = 0;
            for (final o in orders) {
              totalRevenue += o.total;
              if (o.status.toLowerCase() == 'completed') completed++;
              if (o.status.toLowerCase() == 'processing') processing++;
            }

            final Map<String, double> monthly = {};
            for (final o in orders) {
              final m = DateFormat('yyyy-MM').format(o.createdAt.toDate());
              monthly[m] = (monthly[m] ?? 0) + o.total;
            }
            final months = monthly.keys.toList()..sort();

            final Map<String, int> unitsSold = {};
            final Map<String, double> revByProduct = {};
            for (final o in orders) {
              for (final item in o.items) {
                unitsSold[item.name] = (unitsSold[item.name] ?? 0) + item.quantity;
                revByProduct[item.name] = (revByProduct[item.name] ?? 0) + item.totalPrice;
              }
            }
            final top5 = (unitsSold.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Sales Report', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Merchandise Performance', style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                    ]),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: orders.isEmpty ? null : () => _exportReport(context, orders),
                      icon: const Icon(Icons.download_outlined, size: 15),
                      label: Text('Export CSV', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UpriseColors.primaryDark,
                        side: BorderSide(color: UpriseColors.primaryDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B))),
                  ]),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Overview'),
                        const SizedBox(height: 10),
                        Row(children: [
                          _miniStatCard('Total Sales', orders.length.toString(), UpriseColors.info),
                          const SizedBox(width: 10),
                          _miniStatCard('Total Revenue', '₱${NumberFormat('#,###').format(totalRevenue)}', UpriseColors.primaryDark, highlight: true),
                          const SizedBox(width: 10),
                          _miniStatCard('Completed', completed.toString(), UpriseColors.success),
                          const SizedBox(width: 10),
                          _miniStatCard('Processing', processing.toString(), UpriseColors.warning),
                        ]),
                        const SizedBox(height: 20),
                        _sectionTitle('Monthly Revenue'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: months.isEmpty
                              ? Center(child: Text('No data yet', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B))))
                              : BarChart(BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: monthly.values.reduce((a, b) => a > b ? a : b) * 1.2,
                                  barGroups: months.asMap().entries.map((e) => BarChartGroupData(
                                        x: e.key,
                                        barRods: [BarChartRodData(toY: monthly[e.value] ?? 0, color: UpriseColors.primaryDark, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                                      )).toList(),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (v, m) {
                                          final i = v.toInt();
                                          if (i >= 0 && i < months.length) return Text(DateFormat('MMM').format(DateTime.parse('${months[i]}-01')), style: GoogleFonts.beVietnamPro(fontSize: 10));
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 48,
                                        getTitlesWidget: (v, m) => Text('₱${NumberFormat.compact().format(v)}', style: GoogleFonts.beVietnamPro(fontSize: 9, color: const Color(0xFF64748B))),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFE2E6EA), strokeWidth: 0.8)),
                                  borderData: FlBorderData(show: false),
                                )),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Popular Items'),
                        const SizedBox(height: 10),
                        if (top5.isEmpty)
                          Text('No product sales yet', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12))
                        else
                          ...top5.map((entry) {
                            final rev = revByProduct[entry.key] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(width: 36, height: 36, decoration: BoxDecoration(color: UpriseColors.primaryDark.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.shopping_bag_outlined, size: 18, color: UpriseColors.primaryDark)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.key, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                                        Text('${entry.value} units sold', style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: UpriseColors.primaryDark.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                                    child: Text('₱${NumberFormat('#,###').format(rev)}',
                                        style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                    color: Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Text('Done', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C)));
  Widget _miniStatCard(String label, String value, Color color, {bool highlight = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlight ? color.withAlpha(20) : const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: highlight ? color.withAlpha(77) : const Color(0xFFE2E6EA)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: highlight ? color : const Color(0xFF1A202C))),
          ]),
        ),
      );
}

// ============================================================
// MODEL CLASSES (unchanged)
// ============================================================
class ProductModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final int stock;
  final int sold;
  final String imageUrl;

  ProductModel({required this.id, required this.name, required this.description, required this.category, required this.price, required this.stock, required this.sold, this.imageUrl = ''});

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? '',
      price: (d['price'] ?? 0).toDouble(),
      stock: d['stock'] ?? 0,
      sold: d['sold'] ?? 0,
      imageUrl: d['imageUrl'] ?? '',
    );
  }
}

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final double totalPrice;

  OrderItem({required this.productId, required this.name, required this.quantity, required this.price, required this.totalPrice});

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        name: map['name'] ?? '',
        quantity: map['quantity'] ?? 0,
        price: (map['price'] ?? 0).toDouble(),
        totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      );
}

class OrderModel {
  final String id;
  final String orderId;
  final String orgId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String customerAddress;
  final List<OrderItem> items;
  final double total;
  final String paymentMethod;
  final String status;
  final Timestamp createdAt;

  OrderModel({
    required this.id,
    required this.orderId,
    required this.orgId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawItems = (d['items'] as List?) ?? [];
    return OrderModel(
      id: doc.id,
      orderId: d['orderId'] ?? 'ORD-${doc.id.substring(0, 6).toUpperCase()}',
      orgId: d['orgId'] ?? '',
      customerName: d['customerName'] ?? '',
      customerEmail: d['customerEmail'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      customerAddress: d['customerAddress'] ?? '',
      items: rawItems.map((i) => OrderItem.fromMap(i as Map<String, dynamic>)).toList(),
      total: (d['total'] ?? 0).toDouble(),
      paymentMethod: d['paymentMethod'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: d['createdAt'] as Timestamp,
    );
  }
}
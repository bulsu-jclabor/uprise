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

// ============================================================
// COLOR SCHEME
// ============================================================
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
}

// ============================================================
// MAIN SCREEN
// ============================================================
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Merchandise',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: OrgColors.charcoal)),
                  const SizedBox(height: 2),
                  Text(
                      "Manage your organization's merchandise products and orders",
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: OrgColors.darkGray)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openAddProductModal(context),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text('Add Product',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.primaryDark,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Stats Row ──
          _StatsRow(orgId: widget.orgId),
          const SizedBox(height: 20),

          // ── Tabs + Sales Report button ──
          Row(
            children: [
              // Tab pills (Products | Orders)
              Container(
                decoration: BoxDecoration(
                  color: OrgColors.lightGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OrgColors.primaryLight),
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
              // Sales Report button (visible always)
              OutlinedButton.icon(
                onPressed: () => _openSalesReport(context),
                icon: const Icon(Icons.bar_chart_outlined, size: 16),
                label: Text('Sales Report',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OrgColors.charcoal,
                  side: BorderSide(color: OrgColors.primaryLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tab Views ──
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
}

// ============================================================
// PILL TAB
// ============================================================
class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(3),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? OrgColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : OrgColors.darkGray)),
      ),
    );
  }
}

// ============================================================
// STATS ROW
// ============================================================
class _StatsRow extends StatelessWidget {
  final String orgId;
  const _StatsRow({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('orgId', isEqualTo: orgId)
          .where('isArchived', isEqualTo: false)
          .snapshots(),
      builder: (context, productSnap) {
        final products = productSnap.data?.docs ?? [];
        final totalProducts = products.length;
        final lowStock =
            products.where((p) => ((p.data() as Map)['stock'] ?? 0) <= 5).length;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('orgId', isEqualTo: orgId)
              .snapshots(),
          builder: (context, orderSnap) {
            final orders = orderSnap.data?.docs ?? [];
            final totalSales = orders.length;
            double totalRevenue = 0;
            for (final doc in orders) {
              totalRevenue +=
                  ((doc.data() as Map)['total'] ?? 0).toDouble();
            }

            return Row(children: [
              _StatCard(
                  label: 'Total Products',
                  value: totalProducts.toString(),
                  icon: Icons.shopping_bag_outlined,
                  color: OrgColors.info),
              const SizedBox(width: 14),
              _StatCard(
                  label: 'Total Sales',
                  value: totalSales.toString(),
                  icon: Icons.shopping_cart_outlined,
                  color: OrgColors.success),
              const SizedBox(width: 14),
              _StatCard(
                  label: 'Total Revenue',
                  value:
                      '₱${NumberFormat('#,###').format(totalRevenue)}',
                  icon: Icons.payments_outlined,
                  color: OrgColors.warning),
              const SizedBox(width: 14),
              _StatCard(
                  label: 'Low Stock',
                  value: lowStock.toString(),
                  icon: Icons.warning_amber_outlined,
                  color: lowStock > 0
                      ? OrgColors.error
                      : OrgColors.darkGray),
            ]);
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                          fontSize: 11,
                          color: OrgColors.darkGray,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: OrgColors.charcoal)),
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
// PRODUCTS TAB
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
  String _categoryFilter = 'All Items'; // All Items | Apparel | Accessories

  final List<String> _categoryFilters = [
    'All Items',
    'Apparel',
    'Accessories'
  ];

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
      final matchCat = _categoryFilter == 'All Items' ||
          p.category == _categoryFilter;
      return matchSearch && matchCat;
    }).toList();
  }

  Future<void> _archiveProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Archive Product',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Text(
            'Archive "${product.name}"? It will be hidden from the store.',
            style: GoogleFonts.beVietnamPro()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.beVietnamPro()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.warning,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Archive',
                style: GoogleFonts.beVietnamPro(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
      await activity_log.ActivityLogger.log(
        action: 'archive_product',
        module: 'merchandise',
        details: {
          'orgId': widget.orgId,
          'productId': product.id,
          'name': product.name
        },
      );
      if (mounted) {
        _showSnack('Product archived successfully', OrgColors.success);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', OrgColors.error);
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ──
        Row(
          children: [
            // Category filter pills
            ..._categoryFilters.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _CategoryPill(
                    label: cat,
                    selected: _categoryFilter == cat,
                    onTap: () => setState(() => _categoryFilter = cat),
                  ),
                )),
            const Spacer(),
            // Search
            SizedBox(
              width: 240,
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: GoogleFonts.beVietnamPro(
                      fontSize: 12, color: OrgColors.darkGray),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: OrgColors.darkGray),
                  filled: true,
                  fillColor: OrgColors.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: OrgColors.primaryLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: OrgColors.primaryLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: OrgColors.primaryLight),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Product Grid ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'No products yet',
                    subtitle: 'Click "Add Product" to get started.');
              }
              final all = snapshot.data!.docs
                  .map((d) => ProductModel.fromFirestore(d))
                  .toList();
              final filtered = _applyFilters(all);
              if (filtered.isEmpty) {
                return _EmptyState(
                    icon: Icons.search_off_outlined,
                    message: 'No matching products',
                    subtitle: 'Try adjusting your search or filter.');
              }
              return GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ProductCard(
                  product: filtered[i],
                  onEdit: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _ProductModal(
                        orgId: widget.orgId,
                        existingProduct: filtered[i]),
                  ),
                  onArchive: () => _archiveProduct(filtered[i]),
                  onView: () => showDialog(
                    context: context,
                    builder: (_) =>
                        _ProductDetailsModal(product: filtered[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? OrgColors.primaryDark
              : OrgColors.white,
          border: Border.all(
              color: selected
                  ? OrgColors.primaryDark
                  : OrgColors.mediumGray),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : OrgColors.darkGray)),
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD  (matches Frame 76 style)
// ============================================================
class _ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onView;
  const _ProductCard(
      {required this.product,
      required this.onEdit,
      required this.onArchive,
      required this.onView});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isLowStock = widget.product.stock <= 5;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _hovered
                  ? OrgColors.primaryLight
                  : OrgColors.mediumGray),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                      color: OrgColors.primaryDark.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image area ──
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: widget.onView,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: OrgColors.primaryDark.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                      ),
                      child: widget.product.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: Image.network(
                                widget.product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholderIcon(),
                              ),
                            )
                          : _placeholderIcon(),
                    ),
                    // Low stock badge
                    if (isLowStock)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: OrgColors.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Low Stock',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    // Category badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: OrgColors.primaryDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(widget.product.category,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Product Info ──
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product.name,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OrgColors.charcoal),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                        '₱${NumberFormat('#,###').format(widget.product.price)}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: OrgColors.primaryDark)),
                    const SizedBox(height: 2),
                    Text(
                        'Stock: ${widget.product.stock} units  •  Sold: ${widget.product.sold}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 10, color: OrgColors.darkGray)),
                    const Spacer(),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _SmallButton(
                            label: 'Edit',
                            icon: Icons.edit_outlined,
                            color: OrgColors.info,
                            onTap: widget.onEdit,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _SmallButton(
                            label: 'Archive',
                            icon: Icons.archive_outlined,
                            color: OrgColors.warning,
                            onTap: widget.onArchive,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() => Center(
        child: Icon(Icons.shopping_bag_outlined,
            size: 52, color: OrgColors.primaryDark.withOpacity(0.4)),
      );
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT DETAILS MODAL  (matches Frame 76 popup)
// ============================================================
class _ProductDetailsModal extends StatelessWidget {
  final ProductModel product;
  const _ProductDetailsModal({required this.product});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Text('Product Details',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 18, color: OrgColors.darkGray),
                    style: IconButton.styleFrom(
                      backgroundColor: OrgColors.mediumGray,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OrgColors.mediumGray),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Container(
                    width: 100,
                    height: 120,
                    decoration: BoxDecoration(
                      color: OrgColors.primaryDark.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: product.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(product.imageUrl,
                                fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Icon(Icons.shopping_bag_outlined,
                                size: 40, color: OrgColors.primaryDark)),
                  ),
                  const SizedBox(width: 16),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            '₱${NumberFormat('#,###').format(product.price)}',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: OrgColors.primaryDark)),
                        const SizedBox(height: 8),
                        if (product.description.isNotEmpty)
                          Text(product.description,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 12,
                                  color: OrgColors.darkGray)),
                        const SizedBox(height: 10),
                        _DetailRow(label: 'Category', value: product.category),
                        _DetailRow(
                            label: 'Stock',
                            value: '${product.stock} units',
                            valueColor: product.stock <= 5
                                ? OrgColors.error
                                : OrgColors.success),
                        _DetailRow(
                            label: 'Sales Performance',
                            value: '${product.sold} sold'),
                      ],
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: OrgColors.darkGray)),
          Text(value,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? OrgColors.charcoal)),
        ],
      ),
    );
  }
}

// ============================================================
// PRODUCT MODAL — ADD / EDIT  (matches Frames 74 & 75)
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
    // Validation
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
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.existingProduct!.id)
            .update(data);
        await activity_log.ActivityLogger.log(
          action: 'edit_product',
          module: 'merchandise',
          details: {
            'orgId': widget.orgId,
            'productId': widget.existingProduct!.id
          },
        );
      } else {
        data['sold'] = 0;
        data['isArchived'] = false;
        data['imageUrl'] = '';
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = user?.uid ?? '';
        await FirebaseFirestore.instance.collection('products').add(data);
        await activity_log.ActivityLogger.log(
          action: 'create_product',
          module: 'merchandise',
          details: {'orgId': widget.orgId, 'name': data['name']},
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro()),
      backgroundColor: OrgColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: OrgColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: OrgColors.primaryDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isEdit ? 'Edit Product' : 'Add Product',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OrgColors.charcoal)),
                      if (_isEdit && widget.existingProduct != null)
                        Text(
                            'PRODUCT ID: #${widget.existingProduct!.id.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 10,
                                color: OrgColors.darkGray,
                                fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 18, color: OrgColors.darkGray),
                    style: IconButton.styleFrom(
                        backgroundColor: OrgColors.mediumGray,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(28, 28)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OrgColors.mediumGray),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Toggle
                    _FieldLabel('CATEGORY'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: OrgColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: OrgColors.primaryLight),
                      ),
                      child: Row(
                        children: ['Apparel', 'Accessories'].map((c) {
                          final sel = _category == c;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _category = c),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                margin: const EdgeInsets.all(3),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? OrgColors.primaryDark
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(c,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : OrgColors.darkGray)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image placeholder (for future image upload)
                    if (_isEdit) ...[
                      _FieldLabel('PRODUCT IMAGE'),
                      const SizedBox(height: 6),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: OrgColors.lightGray,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: OrgColors.primaryLight,
                              style: BorderStyle.solid),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color:
                                    OrgColors.primaryDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined,
                                  color: OrgColors.primaryDark, size: 32),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Replace Image',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: OrgColors.charcoal)),
                                Text(
                                    'PNG, JPG up to 5MB',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 10,
                                        color: OrgColors.darkGray)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Product Name
                    _FieldLabel('PRODUCT NAME'),
                    const SizedBox(height: 6),
                    _TextField(
                        controller: _nameCtrl,
                        hint: 'e.g. PREMIUM Shirt 2026'),
                    const SizedBox(height: 16),

                    // Description
                    _FieldLabel('DESCRIPTION'),
                    const SizedBox(height: 6),
                    _TextField(
                        controller: _descCtrl,
                        hint: 'Add some notes about this product...',
                        maxLines: 3),
                    const SizedBox(height: 16),

                    // Price & Stock Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('PRICE'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _priceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13),
                                decoration: InputDecoration(
                                  prefixText: '₱ ',
                                  prefixStyle:
                                      GoogleFonts.beVietnamPro(
                                          fontSize: 13,
                                          color: OrgColors.darkGray),
                                  hintText: '0.00',
                                  hintStyle: GoogleFonts.beVietnamPro(
                                      fontSize: 13,
                                      color: OrgColors.mediumGray),
                                  border: _inputBorder(),
                                  enabledBorder: _inputBorder(),
                                  focusedBorder: _inputBorder(
                                      color: OrgColors.primaryLight),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('STOCK QUANTITY'),
                              const SizedBox(height: 6),
                              _TextField(
                                  controller: _stockCtrl,
                                  hint: '0',
                                  keyboardType:
                                      TextInputType.number),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──
            const Divider(height: 1, color: OrgColors.mediumGray),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrgColors.charcoal,
                      side: const BorderSide(
                          color: OrgColors.primaryLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text('Discard',
                        style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.primaryDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(
                            _isEdit
                                ? 'Save Changes'
                                : 'Add Product',
                            style: GoogleFonts.beVietnamPro(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder({Color color = OrgColors.mediumGray}) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color));
}

// ============================================================
// ORDERS TAB  (matches Frame 79/80)
// ============================================================
class _OrdersTab extends StatefulWidget {
  final String orgId;
  const _OrdersTab({required this.orgId});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final TextEditingController _searchController =
      TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  final List<String> _statusFilters = [
    'All', 'Pending', 'Processing', 'Completed'
  ];

  List<OrderModel> _applyFilters(List<OrderModel> orders) {
    return orders.where((o) {
      final matchSearch = _searchQuery.isEmpty ||
          o.customerName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          o.orderId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchStatus = _statusFilter == 'All' ||
          o.status.toLowerCase() == _statusFilter.toLowerCase();
      return matchSearch && matchStatus;
    }).toList();
  }

  void _exportOrdersCSV(List<OrderModel> orders) {
    final filtered = _applyFilters(orders);
    final buf = StringBuffer();
    buf.writeln(
        'Order ID,Customer,Email,Phone,Total,Payment,Status,Date');
    for (final o in filtered) {
      final date = DateFormat('MM/dd/yyyy HH:mm')
          .format(o.createdAt.toDate());
      buf.writeln(
          '"${o.orderId}","${o.customerName}","${o.customerEmail}","${o.customerPhone}","${o.total.toStringAsFixed(2)}","${o.paymentMethod}","${o.status}","$date"');
    }
    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download',
          'orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Exported ${filtered.length} orders to CSV',
          style: GoogleFonts.beVietnamPro()),
      backgroundColor: OrgColors.success,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('orgId', isEqualTo: widget.orgId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.hasData
            ? snapshot.data!.docs
                .map((d) => OrderModel.fromFirestore(d))
                .toList()
            : <OrderModel>[];
        final filtered = _applyFilters(orders);

        return Column(
          children: [
            // ── Toolbar ──
            Row(
              children: [
                // Status filter pills
                ..._statusFilters.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _CategoryPill(
                        label: s,
                        selected: _statusFilter == s,
                        onTap: () =>
                            setState(() => _statusFilter = s),
                      ),
                    )),
                const Spacer(),
                // Search
                SizedBox(
                  width: 220,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                    style: GoogleFonts.beVietnamPro(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search orders...',
                      hintStyle: GoogleFonts.beVietnamPro(
                          fontSize: 12, color: OrgColors.darkGray),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: OrgColors.darkGray),
                      filled: true,
                      fillColor: OrgColors.lightGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: OrgColors.primaryLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: OrgColors.primaryLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: OrgColors.primaryLight),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Export
                OutlinedButton.icon(
                  onPressed: orders.isEmpty
                      ? null
                      : () => _exportOrdersCSV(orders),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text('Export',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OrgColors.charcoal,
                    side:
                        const BorderSide(color: OrgColors.primaryLight),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Orders List ──
            Expanded(
              child: Builder(builder: (_) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (orders.isEmpty) {
                  return _EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      message: 'No orders yet',
                      subtitle: 'Orders will appear here.');
                }
                if (filtered.isEmpty) {
                  return _EmptyState(
                      icon: Icons.search_off_outlined,
                      message: 'No matching orders',
                      subtitle:
                          'Try adjusting your search or filter.');
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => _OrderCard(
                    order: filtered[i],
                    onView: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _OrderDetailsModal(order: filtered[i]),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onView;
  const _OrderCard({required this.order, required this.onView});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final date = DateFormat('MMM d, yyyy h:mm a')
        .format(order.createdAt.toDate());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(
        children: [
          // Order ID & status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${order.orderId}  •  ${order.status[0].toUpperCase()}${order.status.substring(1)}',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(order.customerName,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OrgColors.charcoal)),
              const SizedBox(height: 2),
              Text(order.customerEmail,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
              Text(order.customerPhone,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
            ],
          ),
          const Spacer(),
          // Date, amount, payment
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(date,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
              const SizedBox(height: 4),
              Text(
                  '₱${NumberFormat('#,###.00').format(order.total)}',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: OrgColors.charcoal)),
              Text(order.paymentMethod,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
              const SizedBox(height: 6),
              InkWell(
                onTap: onView,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: OrgColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: OrgColors.info.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 13, color: OrgColors.info),
                      const SizedBox(width: 4),
                      Text('View Details',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: OrgColors.info)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return OrgColors.success;
      case 'processing':
        return OrgColors.info;
      case 'pending':
        return OrgColors.warning;
      default:
        return OrgColors.darkGray;
    }
  }
}

// ============================================================
// ORDER DETAILS MODAL  (matches Frame 80 popup)
// ============================================================
class _OrderDetailsModal extends StatelessWidget {
  final OrderModel order;
  const _OrderDetailsModal({required this.order});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return OrgColors.success;
      case 'processing':
        return OrgColors.info;
      case 'pending':
        return OrgColors.warning;
      default:
        return OrgColors.darkGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Text('Order Details',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        '${order.status[0].toUpperCase()}${order.status.substring(1)}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 18, color: OrgColors.darkGray),
                    style: IconButton.styleFrom(
                        backgroundColor: OrgColors.mediumGray,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(28, 28)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OrgColors.mediumGray),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order ID
                    Text('Order ID: ${order.orderId}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: OrgColors.darkGray)),
                    const SizedBox(height: 16),

                    // Customer Information
                    _SectionTitle('Customer Information'),
                    const SizedBox(height: 8),
                    _InfoRow(Icons.person_outline, order.customerName),
                    _InfoRow(
                        Icons.email_outlined, order.customerEmail),
                    _InfoRow(Icons.phone_outlined, order.customerPhone),
                    if (order.customerAddress.isNotEmpty)
                      _InfoRow(Icons.location_on_outlined,
                          order.customerAddress),
                    const SizedBox(height: 16),

                    // Order Items
                    _SectionTitle('Order Items'),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: OrgColors.primaryDark
                                      .withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 20,
                                    color: OrgColors.primaryDark),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style:
                                            GoogleFonts.beVietnamPro(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600)),
                                    Text(
                                        '₱${NumberFormat('#,###').format(item.price)} each',
                                        style:
                                            GoogleFonts.beVietnamPro(
                                                fontSize: 11,
                                                color:
                                                    OrgColors.darkGray)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text('Qty: ${item.quantity}',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 11,
                                          color: OrgColors.darkGray)),
                                  Text(
                                      '₱${NumberFormat('#,###.00').format(item.totalPrice)}',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              OrgColors.primaryDark)),
                                ],
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),

                    // Order Summary
                    _SectionTitle('Order Summary'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OrgColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: OrgColors.primaryLight),
                      ),
                      child: Column(
                        children: [
                          _SummaryLine('Subtotal',
                              '₱${NumberFormat('#,###.00').format(order.total)}'),
                          const SizedBox(height: 4),
                          _SummaryLine(
                              'Payment Method', order.paymentMethod),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            child: Divider(
                                color: OrgColors.mediumGray,
                                height: 1),
                          ),
                          _SummaryLine(
                              'Total Amount',
                              '₱${NumberFormat('#,###.00').format(order.total)}',
                              bold: true,
                              valueColor: OrgColors.primaryDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Order Timeline
                    _SectionTitle('Order Timeline'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: OrgColors.darkGray),
                        const SizedBox(width: 6),
                        Text(
                            'Order placed: ${DateFormat('MMM d, yyyy h:mm a').format(order.createdAt.toDate())}',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                color: OrgColors.darkGray)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, color: OrgColors.mediumGray),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrgColors.charcoal,
                      side: const BorderSide(
                          color: OrgColors.primaryLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text('Close',
                        style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {}, // Future: print/export order
                    icon: const Icon(Icons.print_outlined,
                        size: 16, color: Colors.white),
                    label: Text('Print Order',
                        style: GoogleFonts.beVietnamPro(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.primaryDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      elevation: 0,
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

// ============================================================
// SALES REPORT MODAL  (matches screenshot)
// ============================================================
class _SalesReportModal extends StatelessWidget {
  final String orgId;
  const _SalesReportModal({required this.orgId});

  void _exportReport(
      BuildContext context, List<OrderModel> orders) {
    final buf = StringBuffer();
    buf.writeln('MERCHANDISE SALES REPORT');
    buf.writeln(
        'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}');
    buf.writeln('');
    buf.writeln('Order ID,Customer,Total,Status,Date');
    for (final o in orders) {
      final date = DateFormat('MM/dd/yyyy')
          .format(o.createdAt.toDate());
      buf.writeln(
          '"${o.orderId}","${o.customerName}","${o.total.toStringAsFixed(2)}","${o.status}","$date"');
    }
    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download',
          'sales_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12))
          ],
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('orgId', isEqualTo: orgId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final orders = snapshot.hasData
                ? snapshot.data!.docs
                    .map((d) => OrderModel.fromFirestore(d))
                    .toList()
                : <OrderModel>[];

            // Stats
            double totalRevenue = 0;
            int completed = 0, processing = 0;
            for (final o in orders) {
              totalRevenue += o.total;
              if (o.status.toLowerCase() == 'completed') completed++;
              if (o.status.toLowerCase() == 'processing') processing++;
            }

            // Monthly revenue map
            final Map<String, double> monthly = {};
            for (final o in orders) {
              final m = DateFormat('yyyy-MM')
                  .format(o.createdAt.toDate());
              monthly[m] = (monthly[m] ?? 0) + o.total;
            }
            final months = monthly.keys.toList()..sort();

            // Popular items
            final Map<String, int> unitsSold = {};
            final Map<String, double> revByProduct = {};
            for (final o in orders) {
              for (final item in o.items) {
                unitsSold[item.name] =
                    (unitsSold[item.name] ?? 0) + item.quantity;
                revByProduct[item.name] =
                    (revByProduct[item.name] ?? 0) + item.totalPrice;
              }
            }
            final top5 = (unitsSold.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
                .toList();

            return Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  decoration: const BoxDecoration(
                    color: OrgColors.lightGray,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Sales Report',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              'Academic Year 2025-2026 • Scholarly Canvas',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 11,
                                  color: OrgColors.darkGray)),
                        ],
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: orders.isEmpty
                            ? null
                            : () => _exportReport(context, orders),
                        icon: const Icon(
                            Icons.download_outlined,
                            size: 15),
                        label: Text('Export',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OrgColors.charcoal,
                          side: const BorderSide(
                              color: OrgColors.primaryLight),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close,
                            size: 18, color: OrgColors.darkGray),
                        style: IconButton.styleFrom(
                            backgroundColor: OrgColors.mediumGray,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(28, 28)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: OrgColors.mediumGray),

                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Sales Overview stat cards
                        _SectionTitle('Sales Overview'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _MiniStatCard(
                              label: 'Total Sales',
                              value: orders.length.toString(),
                              color: OrgColors.info,
                            ),
                            const SizedBox(width: 10),
                            _MiniStatCard(
                              label: 'Total Revenue',
                              value:
                                  '₱${NumberFormat('#,###').format(totalRevenue)}',
                              color: OrgColors.primaryDark,
                              highlight: true,
                            ),
                            const SizedBox(width: 10),
                            _MiniStatCard(
                              label: 'Processing',
                              value: processing.toString(),
                              color: OrgColors.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Revenue Performance chart
                        _SectionTitle('Revenue Performance'),
                        Text(
                            'Monthly revenue from merchandise sales',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                color: OrgColors.darkGray)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: months.isEmpty
                              ? Center(
                                  child: Text('No data yet',
                                      style:
                                          GoogleFonts.beVietnamPro(
                                              color: OrgColors
                                                  .darkGray)))
                              : BarChart(BarChartData(
                                  alignment:
                                      BarChartAlignment.spaceAround,
                                  maxY: monthly.values
                                          .reduce((a, b) =>
                                              a > b ? a : b) *
                                      1.2,
                                  barGroups: months
                                      .asMap()
                                      .entries
                                      .map((e) => BarChartGroupData(
                                            x: e.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: monthly[
                                                        e.value] ??
                                                    0,
                                                color: OrgColors
                                                    .primaryDark,
                                                width: 20,
                                                borderRadius:
                                                    const BorderRadius
                                                        .vertical(
                                                        top: Radius
                                                            .circular(
                                                                4)),
                                              ),
                                            ],
                                          ))
                                      .toList(),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (v, m) {
                                          final i = v.toInt();
                                          if (i >= 0 &&
                                              i < months.length) {
                                            return Text(
                                              DateFormat('MMM').format(
                                                  DateTime.parse(
                                                      '${months[i]}-01')),
                                              style:
                                                  GoogleFonts.beVietnamPro(
                                                      fontSize: 10),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 48,
                                        getTitlesWidget: (v, m) =>
                                            Text(
                                          '₱${NumberFormat.compact().format(v)}',
                                          style:
                                              GoogleFonts.beVietnamPro(
                                                  fontSize: 9,
                                                  color:
                                                      OrgColors
                                                          .darkGray),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: false)),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (v) =>
                                        FlLine(
                                            color: OrgColors.mediumGray,
                                            strokeWidth: 0.8),
                                  ),
                                  borderData:
                                      FlBorderData(show: false),
                                )),
                        ),
                        const SizedBox(height: 20),

                        // Popular Items
                        _SectionTitle('Popular Items'),
                        const SizedBox(height: 10),
                        if (top5.isEmpty)
                          Text('No product sales yet',
                              style: GoogleFonts.beVietnamPro(
                                  color: OrgColors.darkGray,
                                  fontSize: 12))
                        else
                          ...top5.map((entry) {
                            final rev =
                                revByProduct[entry.key] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: OrgColors.primaryDark
                                          .withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 18,
                                        color:
                                            OrgColors.primaryDark),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.key,
                                            style:
                                                GoogleFonts.beVietnamPro(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight
                                                            .w600)),
                                        Text(
                                            '${entry.value} units sold',
                                            style:
                                                GoogleFonts.beVietnamPro(
                                                    fontSize: 11,
                                                    color: OrgColors
                                                        .darkGray)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4),
                                    decoration: BoxDecoration(
                                      color: OrgColors.primaryDark
                                          .withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '₱${NumberFormat('#,###').format(rev)}',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              OrgColors.primaryDark),
                                    ),
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
                const Divider(height: 1, color: OrgColors.mediumGray),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrgColors.primaryDark,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          elevation: 0,
                        ),
                        child: Text('Done',
                            style: GoogleFonts.beVietnamPro(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;
  const _MiniStatCard(
      {required this.label,
      required this.value,
      required this.color,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight
              ? color.withOpacity(0.08)
              : OrgColors.lightGray,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlight
                  ? color.withOpacity(0.3)
                  : OrgColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    color: OrgColors.darkGray,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: highlight ? color : OrgColors.charcoal)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SHARED HELPER WIDGETS
// ============================================================
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: OrgColors.charcoal));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: OrgColors.darkGray),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: OrgColors.charcoal)),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _SummaryLine(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.normal,
                color: OrgColors.charcoal)),
        Text(value,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? OrgColors.charcoal)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: OrgColors.darkGray,
            letterSpacing: 0.8));
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  const _TextField(
      {required this.controller,
      required this.hint,
      this.maxLines = 1,
      this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.beVietnamPro(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(
            fontSize: 13, color: OrgColors.mediumGray),
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
          borderSide:
              const BorderSide(color: OrgColors.primaryLight),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  const _EmptyState(
      {required this.icon,
      required this.message,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: OrgColors.mediumGray),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: OrgColors.darkGray)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: OrgColors.darkGray)),
        ],
      ),
    );
  }
}

// ============================================================
// MODEL CLASSES
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

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.sold,
    this.imageUrl = '',
  });

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

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.totalPrice,
  });

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
      orderId: d['orderId'] ??
          'ORD-${doc.id.substring(0, 6).toUpperCase()}',
      orgId: d['orgId'] ?? '',
      customerName: d['customerName'] ?? '',
      customerEmail: d['customerEmail'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      customerAddress: d['customerAddress'] ?? '',
      items: rawItems
          .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      total: (d['total'] ?? 0).toDouble(),
      paymentMethod: d['paymentMethod'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: d['createdAt'] as Timestamp,
    );
  }
}




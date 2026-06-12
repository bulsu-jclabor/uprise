// lib/screens/student/student_merchandise_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────
const _kOrange      = Color(0xFFFF6B00);
const _kOrangeLight = Color(0xFFFFF3E0);
const _kBg          = Color(0xFFF5F5F5);
const _kCard        = Colors.white;

// ─────────────────────────────────────────────────────────────
// Models (mirrors org_merchandise.dart)
// ─────────────────────────────────────────────────────────────
class ProductVariant {
  final String id;
  final String size;
  final String color;
  final int stock;
  final double? priceOffset;

  const ProductVariant({
    required this.id,
    required this.size,
    required this.color,
    required this.stock,
    this.priceOffset,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> m) => ProductVariant(
        id         : m['id'] as String? ?? '',
        size       : m['size'] as String? ?? '',
        color      : m['color'] as String? ?? '',
        stock      : ((m['stock'] ?? 0) as num).toInt(),
        priceOffset: m['priceOffset'] != null
            ? (m['priceOffset'] as num).toDouble()
            : null,
      );
}

class _Product {
  final String id;
  final String orgId;
  final String name;
  final String description;
  final String category;
  final double price;
  final int stock;
  final int sold;
  final String imageUrl;
  final String status;
  final double costPrice;
  final List<ProductVariant> variants;

  const _Product({
    required this.id,
    required this.orgId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.sold,
    required this.imageUrl,
    this.status    = 'available',
    this.costPrice = 0,
    this.variants  = const [],
  });

  factory _Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawVariants = d['variants'];
    return _Product(
      id         : doc.id,
      orgId      : d['orgId']       as String? ?? '',
      name       : d['name']        as String? ?? '',
      description: d['description'] as String? ?? '',
      category   : d['category']    as String? ?? '',
      price      : (d['price']  ?? 0).toDouble(),
      stock      : (d['stock']  ?? 0) as int,
      sold       : (d['sold']   ?? 0) as int,
      imageUrl   : d['imageUrl'] as String? ?? '',
      status     : d['status']    as String? ?? 'available',
      costPrice  : (d['costPrice'] ?? 0).toDouble(),
      variants   : rawVariants is List
          ? rawVariants
              .whereType<Map<String, dynamic>>()
              .map(ProductVariant.fromMap)
              .toList()
          : const [],
    );
  }

  bool get inStock {
    if (variants.isNotEmpty) return variants.any((v) => v.stock > 0);
    return stock > 0;
  }
}

class _CartItem {
  final _Product product;
  int quantity;
  final String? variantId;
  final String? variantSize;
  final String? variantColor;
  final double? variantPrice;

  _CartItem({
    required this.product,
    this.quantity    = 1,
    this.variantId   ,
    this.variantSize ,
    this.variantColor,
    this.variantPrice,
  });

  String get cartKey => '${product.id}_${variantId ?? ''}';
  double get subtotal => (variantPrice ?? product.price) * quantity;
}

// ─────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────
class StudentMerchandiseScreen extends StatefulWidget {
  const StudentMerchandiseScreen({super.key});

  @override
  State<StudentMerchandiseScreen> createState() =>
      _StudentMerchandiseScreenState();
}

class _StudentMerchandiseScreenState
    extends State<StudentMerchandiseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  String? _studentOrgId;
  bool _loadingOrgId = true;

  final List<_CartItem> _cart = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() => _selectedTab = _tabController.index);
        }
      });
    _resolveOrgId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Determine which org the current student belongs to,
  // falling back to a "show all" mode if none is set.
  Future<void> _resolveOrgId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _loadingOrgId = false); return; }

    try {
      final studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      String orgId = '';
      if (studentSnap.docs.isNotEmpty) {
        orgId = (studentSnap.docs.first.data()['orgId'] as String?) ?? '';
      }

      if (orgId.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final ud = userDoc.data() ?? {};
          orgId = (ud['orgId'] as String?) ??
                  (ud['organizationId'] as String?) ?? '';
        }
      }

      setState(() {
        _studentOrgId   = orgId.isEmpty ? null : orgId;
        _loadingOrgId   = false;
      });
    } catch (_) {
      setState(() => _loadingOrgId = false);
    }
  }

  // ── Cart helpers ──────────────────────────────────────────
  void _addToCart(_Product product, {ProductVariant? variant}) {
    setState(() {
      final variantId    = variant?.id;
      final variantPrice = variant != null
          ? product.price + (variant.priceOffset ?? 0)
          : null;
      final key      = '${product.id}_${variantId ?? ''}';
      final maxStock = variant?.stock ?? product.stock;
      final existing = _cart.where((i) => i.cartKey == key);
      if (existing.isNotEmpty) {
        if (existing.first.quantity < maxStock) existing.first.quantity++;
      } else {
        _cart.add(_CartItem(
          product      : product,
          variantId    : variantId,
          variantSize  : variant?.size,
          variantColor : variant?.color,
          variantPrice : variantPrice,
        ));
      }
    });
  }

  void _increaseItem(String cartKey) {
    setState(() {
      final item     = _cart.firstWhere((i) => i.cartKey == cartKey);
      final variants = item.product.variants.where((v) => v.id == item.variantId);
      final maxStock = variants.isEmpty ? item.product.stock : variants.first.stock;
      if (item.quantity < maxStock) item.quantity++;
    });
  }

  void _removeFromCart(String cartKey) {
    setState(() => _cart.removeWhere((i) => i.cartKey == cartKey));
  }

  void _decreaseQty(String cartKey) {
    setState(() {
      final item = _cart.firstWhere((i) => i.cartKey == cartKey);
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _cart.removeWhere((i) => i.cartKey == cartKey);
      }
    });
  }

  int _cartCount() => _cart.fold(0, (sum, i) => sum + i.quantity);

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Merchandise',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: _kOrange),
        ),
        actions: [
          // Cart badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined,
                    color: Colors.black),
                onPressed: _cart.isEmpty
                    ? null
                    : () => _openCart(context),
              ),
              if (_cartCount() > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: _kOrange, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        _cartCount().toString(),
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loadingOrgId
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : Column(
              children: [
                // Tab Pills
                _TabRow(
                  selectedTab: _selectedTab,
                  onTap: (i) {
                    _tabController.animateTo(i);
                    setState(() => _selectedTab = i);
                  },
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ProductsTab(
                        orgId: _studentOrgId,
                        onAddToCart: _addToCart,
                        cart: _cart,
                      ),
                      _MyOrdersTab(orgId: _studentOrgId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _openCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => _CartSheet(
          cart: _cart,
          orgId: _studentOrgId ?? '',
          onIncrease: (cartKey) {
            _increaseItem(cartKey);
            setModalState(() {});
            setState(() {});
          },
          onDecrease: (cartKey) {
            _decreaseQty(cartKey);
            setModalState(() {});
            setState(() {});
          },
          onRemove: (cartKey) {
            _removeFromCart(cartKey);
            setModalState(() {});
            setState(() {});
          },
          onOrderPlaced: () {
            setState(() => _cart.clear());
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order placed successfully!'),
                backgroundColor: _kOrange,
              ),
            );
            // Switch to My Orders tab
            _tabController.animateTo(1);
            setState(() => _selectedTab = 1);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab Row
// ─────────────────────────────────────────────────────────────
class _TabRow extends StatelessWidget {
  final int selectedTab;
  final void Function(int) onTap;
  const _TabRow({required this.selectedTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          _TabPill(
            label: 'Products',
            selected: selectedTab == 0,
            onTap: () => onTap(0),
          ),
          const SizedBox(width: 8),
          _TabPill(
            label: 'My Orders',
            selected: selectedTab == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Products Tab  (fetches from org's 'products' collection)
// ─────────────────────────────────────────────────────────────
class _ProductsTab extends StatefulWidget {
  final String? orgId;
  final void Function(_Product, {ProductVariant? variant}) onAddToCart;
  final List<_CartItem> cart;

  const _ProductsTab({
    required this.orgId,
    required this.onAddToCart,
    required this.cart,
  });

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  String _search         = '';
  String _selectedCat    = 'All';
  final _searchCtrl      = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _stream {
    Query q = FirebaseFirestore.instance
        .collection('products')
        .where('archived', isEqualTo: false);

    // Scoped to student's org if set, otherwise fetch all public products
    if (widget.orgId != null) {
      q = q.where('orgId', isEqualTo: widget.orgId);
    }
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search + filter bar
        _SearchBar(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kOrange));
              }
              if (snap.hasError) {
                return _EmptyHint(
                  icon: Icons.error_outline,
                  title: 'Something went wrong',
                  subtitle: snap.error.toString(),
                );
              }

              var products = (snap.data?.docs ?? [])
                  .map((d) => _Product.fromFirestore(d))
                  .toList();

              // Build category list
              final categories = [
                'All',
                ...{for (final p in products) p.category}
                    .where((c) => c.isNotEmpty)
                    .toList()
                  ..sort(),
              ];

              // Filter
              if (_selectedCat != 'All') {
                products = products
                    .where((p) => p.category == _selectedCat)
                    .toList();
              }
              if (_search.isNotEmpty) {
                final q = _search.toLowerCase();
                products = products
                    .where((p) =>
                        p.name.toLowerCase().contains(q) ||
                        p.description.toLowerCase().contains(q))
                    .toList();
              }

              if (products.isEmpty) {
                return _EmptyHint(
                  icon: Icons.storefront_outlined,
                  title: 'No products found',
                  subtitle: _search.isNotEmpty
                      ? 'Try a different search term.'
                      : 'No merchandise available yet.',
                );
              }

              return Column(
                children: [
                  // Category chips
                  _CategoryRow(
                    categories: categories,
                    selected: _selectedCat,
                    onSelect: (c) => setState(() => _selectedCat = c),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (ctx, i) => _ProductCard(
                        product: products[i],
                        onAdd: ({ProductVariant? variant}) =>
                            widget.onAddToCart(products[i], variant: variant),
                        cartQty: widget.cart
                            .where((c) => c.product.id == products[i].id)
                            .fold(0, (s, c) => s + c.quantity),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search merchandise…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, size: 18, color: Colors.black38),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: _kBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryRow(
      {required this.categories,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final sel = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? _kOrange : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? _kOrange : Colors.black12, width: 1),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Product Card
// ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final _Product product;
  final void Function({ProductVariant? variant}) onAdd;
  final int cartQty;
  const _ProductCard(
      {required this.product, required this.onAdd, required this.cartQty});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imgPlaceholder(product.name),
                        )
                      : _imgPlaceholder(product.name),
                  if (product.status == 'discontinued' || !product.inStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: Center(
                          child: Text(
                            product.status == 'discontinued'
                                ? 'DISCONTINUED'
                                : 'OUT OF STOCK',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _StatusBadge(status: product.status),
                  ),
                  if (cartQty > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'x$cartQty in cart',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.black38),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${fmt.format(product.price)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kOrange),
                      ),
                      if (product.inStock && product.status != 'discontinued')
                        GestureDetector(
                          onTap: () => _triggerAdd(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: _kOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.inStock
                        ? '${product.variants.isNotEmpty ? product.variants.fold<int>(0, (sum, v) => sum + v.stock) : product.stock} left'
                        : 'Out of stock',
                    style: TextStyle(
                      fontSize: 10,
                      color: product.inStock
                          ? Colors.green.shade600
                          : Colors.redAccent,
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

  Widget _imgPlaceholder(String name) => Container(
        height: 120,
        width: double.infinity,
        color: _kOrangeLight,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 36,
                color: _kOrange,
                fontWeight: FontWeight.bold),
          ),
        ),
      );

  void _triggerAdd(BuildContext context, {bool closeParent = false}) {
    if (product.variants.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VariantPickerSheet(
          product: product,
          onSelect: (variant) {
            Navigator.pop(context);
            onAdd(variant: variant);
            if (closeParent) Navigator.pop(context);
          },
        ),
      );
    } else {
      onAdd();
      if (closeParent) Navigator.pop(context);
    }
  }

  void _showDetails(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                if (product.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      product.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(product.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: product.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(product.category,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black38)),
                const SizedBox(height: 10),
                Text(
                  '₱${fmt.format(product.price)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kOrange),
                ),
                const SizedBox(height: 12),
                Text(
                  product.description.isNotEmpty
                      ? product.description
                      : 'No description provided.',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _DetailChip(
                        icon: Icons.inventory_2_outlined,
                        label: '${product.variants.isNotEmpty ? product.variants.fold<int>(0, (sum, v) => sum + v.stock) : product.stock} in stock'),
                    const SizedBox(width: 8),
                    _DetailChip(
                        icon: Icons.sell_outlined,
                        label: '${product.sold} sold'),
                  ],
                ),
                if (product.variants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Variants',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _VariantsTable(
                      product: product, basePrice: product.price),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        product.inStock && product.status != 'discontinued'
                            ? () => _triggerAdd(context, closeParent: true)
                            : null,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(
                      product.status == 'discontinued'
                          ? 'Discontinued'
                          : product.inStock
                              ? 'Add to Cart'
                              : 'Out of Stock',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Variant Picker Sheet
// ─────────────────────────────────────────────────────────────
class _VariantPickerSheet extends StatefulWidget {
  final _Product product;
  final void Function(ProductVariant) onSelect;
  const _VariantPickerSheet(
      {required this.product, required this.onSelect});

  @override
  State<_VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<_VariantPickerSheet> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final fmt      = NumberFormat('#,##0.00');
    final variants = widget.product.variants;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Select Variant',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.product.name,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: variants.length,
            itemBuilder: (_, i) {
              final v          = variants[i];
              final selected   = _selectedIndex == i;
              final totalPrice = widget.product.price + (v.priceOffset ?? 0);
              final inStock    = v.stock > 0;

              return GestureDetector(
                onTap: inStock ? () => setState(() => _selectedIndex = i) : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? _kOrangeLight : _kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? _kOrange : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (v.size.isNotEmpty)
                              Text(
                                'Size: ${v.size}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: inStock
                                      ? Colors.black87
                                      : Colors.black38,
                                ),
                              ),
                            if (v.color.isNotEmpty)
                              Text(
                                'Color: ${v.color}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: inStock
                                      ? Colors.black54
                                      : Colors.black38,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              inStock
                                  ? '${v.stock} left'
                                  : 'Out of stock',
                              style: TextStyle(
                                fontSize: 11,
                                color: inStock
                                    ? Colors.green.shade600
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${fmt.format(totalPrice)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: inStock ? _kOrange : Colors.black38,
                        ),
                      ),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle,
                              color: _kOrange, size: 18),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedIndex == null
                  ? null
                  : () => widget.onSelect(variants[_selectedIndex!]),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status badge for product card and detail sheet
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;
    switch (status) {
      case 'out_of_stock':
        bg = Colors.red.shade600; label = 'OUT OF STOCK';
        break;
      case 'discontinued':
        bg = Colors.grey.shade600; label = 'DISCONTINUED';
        break;
      default:
        bg = Colors.green.shade600; label = 'AVAILABLE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Variants table for product detail sheet
// ─────────────────────────────────────────────────────────────
class _VariantsTable extends StatelessWidget {
  final _Product product;
  final double basePrice;
  const _VariantsTable({required this.product, required this.basePrice});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1.8),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: _kBg),
            children: [
              _cell('SIZE', header: true),
              _cell('COLOR', header: true),
              _cell('STOCK', header: true),
              _cell('PRICE', header: true),
            ],
          ),
          for (final v in product.variants)
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              children: [
                _cell(v.size.isNotEmpty ? v.size : '—'),
                _cell(v.color.isNotEmpty ? v.color : '—'),
                _cell(
                  v.stock > 0 ? '${v.stock}' : 'Out',
                  color: v.stock > 0
                      ? Colors.green.shade600
                      : Colors.redAccent,
                ),
                _cell('₱${fmt.format(basePrice + (v.priceOffset ?? 0))}'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool header = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: header ? 11 : 12,
            fontWeight: header ? FontWeight.w700 : FontWeight.normal,
            color: color ?? (header ? Colors.black54 : Colors.black87),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// My Orders Tab
// ─────────────────────────────────────────────────────────────
class _MyOrdersTab extends StatelessWidget {
  final String? orgId;
  const _MyOrdersTab({required this.orgId});

  Stream<QuerySnapshot> get _stream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    Query q = FirebaseFirestore.instance
        .collection('orders')
        .where('customerEmail', isEqualTo: user.email)
        .orderBy('createdAt', descending: true);

    // Scope to org if known
    if (orgId != null) {
      q = FirebaseFirestore.instance
          .collection('orders')
          .where('customerEmail', isEqualTo: user.email)
          .where('orgId', isEqualTo: orgId)
          .orderBy('createdAt', descending: true);
    }
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kOrange));
        }
        if (snap.hasError) {
          return _EmptyHint(
            icon: Icons.error_outline,
            title: 'Failed to load orders',
            subtitle: snap.error.toString(),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyHint(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            subtitle: 'Your order history will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OrderTile(doc: docs[i]),
        );
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  final DocumentSnapshot doc;
  const _OrderTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d           = doc.data() as Map<String, dynamic>;
    final orderId     = d['orderId'] as String?
        ?? 'ORD-${doc.id.substring(0, 6).toUpperCase()}';
    final status      = (d['status']       as String?) ?? 'pending';
    final pickupStatus = (d['pickupStatus'] as String?) ?? 'Pending'; // NEW
    final total       = (d['total']        ?? 0).toDouble();
    final ts          = d['createdAt'] as Timestamp?;
    final dateStr     = ts != null
        ? DateFormat('MMM dd, yyyy').format(ts.toDate())
        : '—';
    final items = (d['items'] as List?) ?? [];
    final fmt   = NumberFormat('#,##0.00');

    final Color statusColor;
    final IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green.shade600;
        statusIcon  = Icons.check_circle_outline;
        break;
      case 'cancelled':
        statusColor = Colors.redAccent;
        statusIcon  = Icons.cancel_outlined;
        break;
      case 'processing':
        statusColor = Colors.blue.shade600;
        statusIcon  = Icons.autorenew;
        break;
      default:
        statusColor = Colors.orange.shade700;
        statusIcon  = Icons.hourglass_empty_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                orderId,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const Spacer(),
              // NEW: Pickup status badge
              _PickupBadge(status: pickupStatus),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 11, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _capitalize(status),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 8),
          ...items.take(3).map((item) {
            final m = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(
                    '${m['quantity'] ?? 1}× ${m['name'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                  const Spacer(),
                  Text(
                    '₱${fmt.format((m['totalPrice'] ?? 0).toDouble())}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            );
          }),
          if (items.length > 3)
            Text(
              '+${items.length - 3} more item(s)',
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '₱${fmt.format(total)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kOrange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────
// Cart Sheet
// ─────────────────────────────────────────────────────────────
class _CartSheet extends StatelessWidget {
  final List<_CartItem> cart;
  final String orgId;
  final void Function(String) onIncrease;
  final void Function(String) onDecrease;
  final void Function(String) onRemove;
  final VoidCallback onOrderPlaced;

  const _CartSheet({
    required this.cart,
    required this.orgId,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onOrderPlaced,
  });

  double get _total =>
      cart.fold(0.0, (sum, i) => sum + i.subtotal);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, color: _kOrange),
                SizedBox(width: 8),
                Text(
                  'Your Cart',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          // Items
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: cart.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your cart is empty.',
                      style: TextStyle(color: Colors.black38),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    children: cart
                        .map((item) => _CartItemRow(
                              item: item,
                              onIncrease: () => onIncrease(item.cartKey),
                              onDecrease: () => onDecrease(item.cartKey),
                              onRemove: () => onRemove(item.cartKey),
                            ))
                        .toList(),
                  ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  '₱${fmt.format(_total)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kOrange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cart.isEmpty
                    ? null
                    : () => _placeOrder(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Place Order',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String customerName = '';
    String studentSection = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        customerName   = snap.docs.first.data()['fullName'] as String? ?? '';
        studentSection = snap.docs.first.data()['section'] as String? ?? '';
      }
    } catch (_) {}

    final orderId =
        'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final db       = FirebaseFirestore.instance;
    final orderRef = db.collection('orders').doc();

    final orderData = {
      'orderId'        : orderId,
      'orgId'          : orgId,
      'customerName'   : customerName,
      'customerEmail'  : user.email ?? '',
      'customerPhone'  : '',
      'customerAddress': '',
      'section'        : studentSection,
      'pickupStatus'   : 'Pending',
      'items'          : cart
          .map((i) => {
                'productId'   : i.product.id,
                'name'        : i.product.name,
                'variantId'   : i.variantId   ?? '',
                'variantSize' : i.variantSize  ?? '',
                'variantColor': i.variantColor ?? '',
                'quantity'    : i.quantity,
                'price'       : i.variantPrice ?? i.product.price,
                'totalPrice'  : i.subtotal,
              })
          .toList(),
      'total'        : _total,
      'paymentMethod': 'Cash on Pickup',
      'status'       : 'pending',
      'createdAt'    : FieldValue.serverTimestamp(),
    };

    final productIds = cart.map((i) => i.product.id).toSet().toList();

    try {
      await db.runTransaction((txn) async {
        // ── Phase 1: read all product docs ───────────────────
        final snaps = <String, DocumentSnapshot>{};
        for (final id in productIds) {
          snaps[id] = await txn.get(db.collection('products').doc(id));
        }

        // ── Phase 2: compute updates, then write ─────────────
        // Accumulate mutable state per product so multiple cart
        // items sharing a product are handled in one update.
        final productState = <String, Map<String, dynamic>>{};

        for (final id in productIds) {
          final d = snaps[id]!.data() as Map<String, dynamic>? ?? {};
          productState[id] = {
            'stock'   : (d['stock'] ?? 0) as int,
            'status'  : (d['status'] ?? 'available') as String,
            'variants': (d['variants'] is List)
                ? (d['variants'] as List)
                    .whereType<Map<String, dynamic>>()
                    .map((v) => Map<String, dynamic>.from(v))
                    .toList()
                : <Map<String, dynamic>>[],
            'variantsModified': false,
          };
        }

        for (final item in cart) {
          final state      = productState[item.product.id]!;
          final variantList =
              state['variants'] as List<Map<String, dynamic>>;
          final hasVariant =
              item.variantId != null && item.variantId!.isNotEmpty;

          final int logOldStock;
          final int logNewStock;

          if (hasVariant) {
            final idx =
                variantList.indexWhere((v) => v['id'] == item.variantId);
            if (idx != -1) {
              logOldStock               = (variantList[idx]['stock'] ?? 0) as int;
              logNewStock               = (logOldStock - item.quantity).clamp(0, 999999);
              variantList[idx]['stock'] = logNewStock;
              state['variantsModified'] = true;
            } else {
              logOldStock = 0;
              logNewStock = 0;
            }
            // Always decrement overall product stock too
            state['stock'] = ((state['stock'] as int) - item.quantity).clamp(0, 999999);
          } else {
            logOldStock    = state['stock'] as int;
            logNewStock    = (logOldStock - item.quantity).clamp(0, 999999);
            state['stock'] = logNewStock;
          }

          txn.set(db.collection('stock_logs').doc(), {
            'productId'  : item.product.id,
            'productName': item.product.name,
            if (hasVariant) 'variantId': item.variantId,
            'reason'     : 'sold',
            'oldStock'   : logOldStock,
            'newStock'   : logNewStock,
            'quantity'   : item.quantity,
            'changedBy'  : 'customer',
            'changedAt'  : FieldValue.serverTimestamp(),
            'orderId'    : orderId,
          });
        }

        // Apply product stock updates
        for (final entry in productState.entries) {
          final state      = entry.value;
          final variantList =
              state['variants'] as List<Map<String, dynamic>>;
          final update = <String, dynamic>{'stock': state['stock']};
          if (state['variantsModified'] as bool) {
            update['variants'] = variantList;
          }
          // Auto-update status when stock hits 0 (skip discontinued products)
          final currentStatus = state['status'] as String;
          if (currentStatus != 'discontinued') {
            final effectiveStock = variantList.isNotEmpty
                ? variantList.fold<int>(0, (s, v) => s + ((v['stock'] ?? 0) as int))
                : state['stock'] as int;
            update['status'] = effectiveStock == 0 ? 'out_of_stock' : 'available';
          }
          txn.update(db.collection('products').doc(entry.key), update);
        }

        txn.set(orderRef, orderData);
      });

      onOrderPlaced();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _CartItemRow extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  const _CartItemRow({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: item.product.imageUrl.isNotEmpty
                ? Image.network(item.product.imageUrl,
                    width: 44, height: 44, fit: BoxFit.cover)
                : Container(
                    width: 44,
                    height: 44,
                    color: _kOrangeLight,
                    child: Center(
                      child: Text(
                        item.product.name.isNotEmpty
                            ? item.product.name[0]
                            : '?',
                        style: const TextStyle(
                            color: _kOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.variantSize != null &&
                    item.variantSize!.isNotEmpty)
                  Text(
                    item.variantSize!,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.black38),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                    '₱${fmt.format(item.variantPrice ?? item.product.price)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          // Qty controls
          Row(
            children: [
              _QtyBtn(
                  icon: Icons.remove,
                  onTap: onDecrease),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              _QtyBtn(
                  icon: Icons.add,
                  onTap: onIncrease),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '₱${fmt.format(item.subtotal)}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kOrange),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon:
                const Icon(Icons.close, size: 14, color: Colors.black38),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: Colors.black54),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NEW: Pickup status badge for My Orders tab
// ─────────────────────────────────────────────────────────────
class _PickupBadge extends StatelessWidget {
  final String status;
  const _PickupBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg, fg;
    final String label;
    switch (status) {
      case 'Ready for Pickup':
        bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); label = 'READY';
        break;
      case 'Claimed':
        bg = const Color(0xFFECFDF5); fg = const Color(0xFF059669); label = 'CLAIMED';
        break;
      default:
        bg = const Color(0xFFFFF3E0); fg = _kOrange; label = 'PENDING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty hint
// ─────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyHint(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Colors.black12),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black38),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
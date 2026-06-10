import 'package:cloud_firestore/cloud_firestore.dart';

class MerchandiseModel {
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
  final DateTime? createdAt;

  const MerchandiseModel({
    required this.id,
    this.orgId = '',
    required this.name,
    this.description = '',
    this.category = '',
    required this.price,
    this.stock = 0,
    this.sold = 0,
    this.imageUrl = '',
    this.status = 'published',
    this.createdAt,
  });

  factory MerchandiseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MerchandiseModel(
      id: doc.id,
      orgId: d['orgId'] as String? ?? '',
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0.0,
      stock: (d['stock'] as num?)?.toInt() ?? 0,
      sold: (d['sold'] as num?)?.toInt() ?? 0,
      imageUrl: d['imageUrl'] ?? '',
      status: d['status'] as String? ?? 'published',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'sold': sold,
      'imageUrl': imageUrl,
      'status': status,
    };
  }
}

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final double totalPrice;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.totalPrice,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        name: map['name'] ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'totalPrice': totalPrice,
      };
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
  final String bundleId;

  const OrderModel({
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
    this.bundleId = '',
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
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
      total: (d['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: d['paymentMethod'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      bundleId: d['bundleId'] ?? '',
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GcashPaymentResult {
  final String intentDocId;
  final String checkoutUrl;

  const GcashPaymentResult({required this.intentDocId, required this.checkoutUrl});
}

class GcashPaymentService {
  static Future<GcashPaymentResult> createPaymentIntent({
    required String orgId,
    required List<Map<String, dynamic>> items,
    required double total,
    required String customerName,
    required String customerEmail,
    String customerPhone = '',
    String customerAddress = '',
    String section = '',
    String bundleId = '',
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('createGcashPaymentIntent');
    final result = await callable.call(<String, dynamic>{
      'orgId': orgId,
      'items': items,
      'total': total,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'section': section,
      'bundleId': bundleId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return GcashPaymentResult(
      intentDocId: data['intentDocId'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
    );
  }

  /// Waits for `paymongoWebhook` to resolve the payment intent's status.
  /// Returns 'completed', 'failed', or 'timeout'.
  static Future<String> awaitConfirmation(
    String intentDocId, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final docRef = FirebaseFirestore.instance.collection('gcash_payment_intents').doc(intentDocId);
    try {
      final snap = await docRef.snapshots().firstWhere((snap) {
        final status = snap.data()?['status'] as String?;
        return status == 'completed' || status == 'failed';
      }).timeout(timeout);
      return (snap.data()?['status'] as String?) ?? 'failed';
    } on TimeoutException {
      return 'timeout';
    }
  }
}

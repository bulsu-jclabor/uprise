// lib/screens/student/gcash_checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../widgets/student/app_colors.dart';

/// Opens the PayMongo GCash checkout URL in an in-app WebView and pops
/// `true` once the user reaches the `paymentRedirect` landing page
/// (success or failure is then resolved separately via the webhook,
/// see [GcashPaymentService.awaitConfirmation]). Pops `false` if the
/// user backs out before completing the flow.
class GcashCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;

  const GcashCheckoutScreen({super.key, required this.checkoutUrl});

  @override
  State<GcashCheckoutScreen> createState() => _GcashCheckoutScreenState();
}

class _GcashCheckoutScreenState extends State<GcashCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (request.url.contains('/paymentRedirect')) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'GCash Payment',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryDark)),
        ],
      ),
    );
  }
}

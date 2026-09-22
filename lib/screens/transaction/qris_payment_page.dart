import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wave_biz_tabs/services/transaction_service.dart';

class QrisPaymentPage extends StatefulWidget {
  final String paymentLink;
  final String idTransaction;
  final String accessToken;
  final String businessId;
  final TransactionService transactionService;

  const QrisPaymentPage({
    super.key,
    required this.paymentLink,
    required this.idTransaction,
    required this.accessToken,
    required this.businessId,
    required this.transactionService,
  });

  @override
  State<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

class _QrisPaymentPageState extends State<QrisPaymentPage> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentLink));

    _startPolling();
  }

  void _startPolling() {
    // Cek status pembayaran tiap 5 detik selama WebView terbuka.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await widget.transactionService.checkPaymentStatus(
          accessToken: widget.accessToken,
          businessId: widget.businessId,
          idTransaction: widget.idTransaction,
        );

        if (result.status == 'paid') {
          timer.cancel();
          if (mounted) Navigator.of(context).pop(true); // sukses
        } else if (result.status == 'expired' || result.status == 'cancelled') {
          timer.cancel();
          if (mounted) Navigator.of(context).pop(false); // gagal
        }
        // kalau masih "pending", polling lanjut
      } catch (e) {
        // jangan hentikan WebView cuma karena 1x gagal fetch status
        debugPrint('Poll payment status error: $e');
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran QRIS'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null), // dibatalkan user
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

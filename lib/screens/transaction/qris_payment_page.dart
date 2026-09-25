import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/services/transaction_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';



const _kAccent = Color(0xFF0F766E); // teal yang lebih dalam & elegan
const _kAccentDark = Color(0xFF0B4F49);
const _kAccentLight = Color(0xFFE6F4F2);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF8A94A6);
const _kSurface = Color(0xFFF6F8F9);

/// Menampilkan payment_link (Midtrans Snap) di dalam WebView, sambil polling
/// status pembayaran ke endpoint payment-check.
///
/// Return value setelah di-pop:
/// - true  -> pembayaran berhasil (status "paid"/"settlement")
/// - false -> gagal / expired / cancelled
/// - null  -> user menutup manual (belum tentu gagal, transaksi tetap ada)
class QrisPaymentPage extends StatefulWidget {
  final String paymentLink;
  final String idTransaction;
  final String accessToken;
  final String businessId;

  const QrisPaymentPage({
    super.key,
    required this.paymentLink,
    required this.idTransaction,
    required this.accessToken,
    required this.businessId,
  });

  @override
  State<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

enum _LoadState { loading, loaded, error, timeout }

class _QrisPaymentPageState extends State<QrisPaymentPage>
    with SingleTickerProviderStateMixin {
  final _service = TransactionService();
  late final WebViewController _controller;
  late final AnimationController _pulseController;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  bool _finished = false;
  _LoadState _loadState = _LoadState.loading;
  double _progress = 0;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initWebView();
    _startPolling();
  }

  void _initWebView() {
    _errorDetail = null;
    setState(() => _loadState = _LoadState.loading);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageStarted: (url) {
            debugPrint('[QrisPaymentPage] onPageStarted: $url');
            _resetTimeoutTimer();
          },
          onPageFinished: (url) {
            debugPrint('[QrisPaymentPage] onPageFinished: $url');
            _timeoutTimer?.cancel();
            if (mounted) setState(() => _loadState = _LoadState.loaded);
          },
          onWebResourceError: (error) {
            debugPrint(
              '[QrisPaymentPage] WebResourceError: ${error.description} '
              '(code ${error.errorCode}, type ${error.errorType})',
            );
            if (error.isForMainFrame ?? true) {
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _loadState = _LoadState.error;
                  _errorDetail = error.description;
                });
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentLink));

    _resetTimeoutTimer();
  }

  void _resetTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _loadState == _LoadState.loading) {
        setState(() => _loadState = _LoadState.timeout);
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_finished) return;
      try {
        final result = await _service.checkPaymentStatus(
          accessToken: widget.accessToken,
          businessId: widget.businessId,
          idTransaction: widget.idTransaction,
        );

        final status = result.status.toLowerCase();
        if (status == 'paid' || status == 'settlement') {
          _finish(true);
        } else if (status == 'expired' ||
            status == 'expire' ||
            status == 'cancelled' ||
            status == 'cancel') {
          _finish(false);
        }
      } catch (e) {
        debugPrint('[QrisPaymentPage] Poll status error: $e');
      }
    });
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.paymentLink);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: const Text('Tidak bisa membuka browser eksternal.'),
        ),
      );
    }
  }

  void _finish(bool? paid) {
    if (_finished || !mounted) return;
    _finished = true;
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.of(context).pop(paid);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildContentCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccentDark, _kAccent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => _finish(null),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pembayaran QRIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _StatusDot(
                      color: Colors.white,
                      pulse: _pulseController,
                      active: _loadState != _LoadState.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    switch (_loadState) {
      case _LoadState.loading:
        return 'Menyiapkan halaman…';
      case _LoadState.loaded:
        return 'Menunggu pembayaran';
      case _LoadState.timeout:
        return 'Koneksi lambat';
      case _LoadState.error:
        return 'Gagal memuat';
    }
  }

  Widget _buildContentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_loadState == _LoadState.loading)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 3,
              backgroundColor: _kAccentLight,
              valueColor: const AlwaysStoppedAnimation(_kAccent),
            )
          else
            const SizedBox(height: 3),
          Expanded(
            child: Stack(
              children: [
                Offstage(
                  offstage: _loadState == _LoadState.error,
                  child: WebViewWidget(controller: _controller),
                ),
                if (_loadState == _LoadState.loading) _buildLoadingOverlay(),
                if (_loadState == _LoadState.timeout) _buildTimeoutOverlay(),
                if (_loadState == _LoadState.error) _buildErrorOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _kAccentLight,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                color: _kAccent,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Menyiapkan halaman pembayaran',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mohon tunggu sebentar…',
            style: TextStyle(fontSize: 12.5, color: _kMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutOverlay() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              size: 30,
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Halaman pembayaran lama terbuka',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Koneksi mungkin lambat, atau halaman ini perlu dibuka di browser. '
            'Status pembayaran tetap dicek otomatis di latar belakang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _kMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          _ElevatedActionButton(
            label: 'Tunggu Lagi',
            icon: Icons.refresh_rounded,
            onPressed: () {
              setState(() => _loadState = _LoadState.loading);
              _resetTimeoutTimer();
            },
          ),
          const SizedBox(height: 10),
          _OutlinedActionButton(
            label: 'Buka di Browser',
            icon: Icons.open_in_new_rounded,
            onPressed: _openInBrowser,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 30,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Gagal memuat halaman pembayaran',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          if (_errorDetail != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorDetail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _kMuted, height: 1.4),
            ),
          ],
          const SizedBox(height: 24),
          _ElevatedActionButton(
            label: 'Coba Lagi',
            icon: Icons.refresh_rounded,
            onPressed: _initWebView,
          ),
          const SizedBox(height: 10),
          _OutlinedActionButton(
            label: 'Buka di Browser',
            icon: Icons.open_in_new_rounded,
            onPressed: _openInBrowser,
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends AnimatedWidget {
  final Color color;
  final bool active;

  const _StatusDot({
    required this.color,
    required AnimationController pulse,
    required this.active,
  }) : super(listenable: pulse);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as AnimationController).value;
    final opacity = active ? 0.4 + (t * 0.6) : 1.0;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ElevatedActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ElevatedActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _OutlinedActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccent,
          side: const BorderSide(color: _kAccent, width: 1.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

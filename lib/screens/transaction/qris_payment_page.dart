import 'package:flutter/material.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';

import '../../core/constants.dart';
import '../../models/cart_model.dart' show formatIDR;

const _kBg = Color(0xFFF4F6F8);
const _kInk = Color(0xFF1C2230);
const _kMuted = Color(0xFF8C93A3);
const _kBorder = Color(0xFFE7EAF0);

const _kSuccess = Color(0xFF14966B);
const _kSuccessSoft = Color(0xFFE4F6EE);
const _kDanger = Color(0xFFE0473F);
const _kDangerSoft = Color(0xFFFCEAE9);
const _kWarning = Color(0xFFC98A1E);
const _kWarningSoft = Color(0xFFFCF2E1);
const _kAccent = Color(0xFF11637F);
const _kAccentSoft = Color(0xFFE7F1F4);

/// Menjalankan pembayaran QRIS via SDK pembayaran native (bukan WebView),
/// lalu SELALU menampilkan layar konfirmasi di dalam app sebelum kembali —
/// jadi kasir tahu pasti transaksi berhasil, gagal, atau masih pending,
/// bukan cuma balik diam-diam.
///
/// Return value setelah di-pop:
/// - true  -> pembayaran dikonfirmasi sukses (settlement/capture)
/// - false -> gagal / ditolak / kedaluwarsa / dibatalkan
/// - null  -> belum ada kepastian (pending) / user menutup manual
class QrisPaymentPage extends StatefulWidget {
  /// Snap token dari response create-sale (`payment_token`). Ini yang
  /// dipakai untuk membuka layar pembayaran.
  final String paymentToken;
  final String idTransaction;

  /// Nominal transaksi (opsional) — buat ditampilkan di layar konfirmasi.
  final int? amount;

  const QrisPaymentPage({
    super.key,
    required this.paymentToken,
    required this.idTransaction,
    this.amount,
  });

  @override
  State<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

enum _FlowState {
  initializing,
  waitingPayment,
  initError,
  resultSuccess,
  resultFailed,
  resultPending,
}

class _QrisPaymentPageState extends State<QrisPaymentPage> {
  MidtransSDK? _midtrans;
  _FlowState _state = _FlowState.initializing;
  String? _errorDetail;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _startPaymentFlow();
  }

  Future<void> _startPaymentFlow() async {
    setState(() {
      _state = _FlowState.initializing;
      _errorDetail = null;
    });

    try {
      _midtrans = await MidtransSDK.init(
        config: MidtransConfig(
          clientKey: MidtransConstants.clientKey,
          merchantBaseUrl: MidtransConstants.merchantBaseUrl,
          colorTheme: ColorTheme(
            colorPrimary: _kAccent,
            colorPrimaryDark: _kInk,
            colorSecondary: _kAccent,
          ),
        ),
      );

      _midtrans?.setTransactionFinishedCallback(_onTransactionFinished);

      if (!mounted) return;
      setState(() => _state = _FlowState.waitingPayment);

      await _midtrans?.startPaymentUiFlow(token: widget.paymentToken);
    } catch (e) {
      debugPrint('[QrisPaymentPage] init/flow error: $e');
      if (mounted) {
        setState(() {
          _state = _FlowState.initError;
          _errorDetail = e.toString();
        });
      }
    }
  }

  /// Callback ini datang LANGSUNG dari layanan pembayaran — sumber
  /// kebenaran status QRIS, bukan asumsi kita sendiri.
  void _onTransactionFinished(TransactionResult result) {
    debugPrint(
      '[QrisPaymentPage] finished -> status: ${result.status}, '
      'message: ${result.message}, transactionId: ${result.transactionId}, '
      'paymentType: ${result.paymentType}',
    );

    if (!mounted) return;

    switch (result.status.toLowerCase()) {
      case 'settlement':
      case 'capture':
        setState(() {
          _state = _FlowState.resultSuccess;
          _resultMessage = result.message;
        });
        break;
      case 'deny':
      case 'expire':
      case 'cancel':
        setState(() {
          _state = _FlowState.resultFailed;
          _resultMessage = result.message;
        });
        break;
      default:
        // 'pending' atau status lain yang belum final (mis. user menutup
        // layar pembayaran sebelum menyelesaikannya).
        setState(() {
          _state = _FlowState.resultPending;
          _resultMessage = result.message;
        });
    }

    _midtrans?.removeTransactionFinishedCallback();
  }

  void _closeWith(bool? paid) {
    if (!mounted) return;
    Navigator.of(context).pop(paid);
  }

  @override
  void dispose() {
    _midtrans?.removeTransactionFinishedCallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isResultState,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeWith(null);
      },
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildBody(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isResultState =>
      _state == _FlowState.resultSuccess ||
      _state == _FlowState.resultFailed ||
      _state == _FlowState.resultPending;

  Widget _buildBody() {
    switch (_state) {
      case _FlowState.initializing:
      case _FlowState.waitingPayment:
        return _StatusCard(
          key: const ValueKey('loading'),
          iconBg: _kAccentSoft,
          icon: const Padding(
            padding: EdgeInsets.all(4),
            child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2.6),
          ),
          title: _state == _FlowState.initializing
              ? 'Menyiapkan pembayaran'
              : 'Menunggu pembayaran QRIS',
          subtitle: 'Mohon tunggu sebentar…',
        );
      case _FlowState.initError:
        return _StatusCard(
          key: const ValueKey('error'),
          iconBg: _kDangerSoft,
          icon: Icon(Icons.wifi_off_rounded, size: 30, color: _kDanger),
          title: 'Gagal membuka pembayaran',
          subtitle: _errorDetail ?? 'Terjadi kesalahan, coba lagi.',
          primaryLabel: 'Coba Lagi',
          onPrimary: _startPaymentFlow,
          secondaryLabel: 'Tutup',
          onSecondary: () => _closeWith(null),
        );
      case _FlowState.resultSuccess:
        return _StatusCard(
          key: const ValueKey('success'),
          iconBg: _kSuccessSoft,
          icon: const Icon(Icons.check_rounded, size: 34, color: _kSuccess),
          title: 'Pembayaran Berhasil',
          subtitle: widget.amount != null
              ? 'Total ${formatIDR(widget.amount!)} telah diterima.'
              : 'Pembayaran QRIS telah diterima.',
          badgeLabel: 'ID: ${widget.idTransaction}',
          primaryLabel: 'Selesai',
          primaryColor: _kSuccess,
          onPrimary: () => _closeWith(true),
        );
      case _FlowState.resultFailed:
        return _StatusCard(
          key: const ValueKey('failed'),
          iconBg: _kDangerSoft,
          icon: const Icon(Icons.close_rounded, size: 34, color: _kDanger),
          title: 'Pembayaran Gagal',
          subtitle: _resultMessage?.isNotEmpty == true
              ? _resultMessage!
              : 'Transaksi ditolak, kedaluwarsa, atau dibatalkan.',
          primaryLabel: 'Tutup',
          primaryColor: _kDanger,
          onPrimary: () => _closeWith(false),
        );
      case _FlowState.resultPending:
        return _StatusCard(
          key: const ValueKey('pending'),
          iconBg: _kWarningSoft,
          icon: const Icon(
            Icons.access_time_rounded,
            size: 30,
            color: _kWarning,
          ),
          title: 'Belum Ada Konfirmasi',
          subtitle:
              'Status pembayaran belum final. Cek ulang statusnya di daftar '
              'transaksi beberapa saat lagi.',
          primaryLabel: 'Tutup',
          primaryColor: _kWarning,
          onPrimary: () => _closeWith(null),
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  final Color iconBg;
  final Widget icon;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final String? primaryLabel;
  final Color primaryColor;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _StatusCard({
    super.key,
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeLabel,
    this.primaryLabel,
    this.primaryColor = _kAccent,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: icon,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _kInk,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _kMuted, height: 1.5),
          ),
          if (badgeLabel != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                badgeLabel!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _kMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
          if (primaryLabel != null) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  primaryLabel!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kMuted,
                  side: const BorderSide(color: _kBorder, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

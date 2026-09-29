import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/screens/transaction/qris_payment_page.dart';

import '../../providers/checkout_provider.dart';
import '../../models/receipt_model.dart';
import '../../models/sale_request.dart';
import '../../services/receipt_printer_service.dart';

const _kAccent = Color(0xFF008080);

Future<void> showPaymentMethodSheet(BuildContext context, WidgetRef ref) {
  ref.read(checkoutProvider.notifier).reset();

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PaymentMethodDialog(),
  );
}

class _PaymentMethodDialog extends ConsumerWidget {
  const _PaymentMethodDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Select payment method",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2430),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(
                  child: _PaymentOptionCard(
                    label: "Cash",
                    icon: Icons.payments_rounded,
                    method: PaymentMethod.cash,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _PaymentOptionCard(
                    label: "Debit",
                    icon: Icons.credit_card_rounded,
                    method: PaymentMethod.debit,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _PaymentOptionCard(
                    label: "QRIS",
                    icon: Icons.qr_code_rounded,
                    method: PaymentMethod.qris,
                  ),
                ),
              ],
            ),
            if (checkout.status == CheckoutStatus.error &&
                checkout.errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        checkout.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Change Order",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kAccent.withOpacity(0.6),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: checkout.status == CheckoutStatus.loading
                        ? null
                        : () async {
                            await ref.read(checkoutProvider.notifier).submit();
                            final result = ref.read(checkoutProvider);
                            if (result.status != CheckoutStatus.success ||
                                !context.mounted) {
                              return;
                            }

                            final receipt = result.receipt;

                            if (result.selectedMethod == PaymentMethod.qris) {
                              Navigator.of(context).pop();
                              final paid = await Navigator.of(context)
                                  .push<bool?>(
                                    MaterialPageRoute(
                                      builder: (_) => QrisPaymentPage(
                                        paymentToken: result.paymentToken!,
                                        idTransaction: result.idTransaction!,
                                        amount: result.amount,
                                      ),
                                    ),
                                  );
                              if (paid == true && context.mounted) {
                                _showSuccessDialog(context, receipt);
                              }
                            } else {
                              Navigator.of(context).pop();
                              _showSuccessDialog(context, receipt);
                            }
                          },
                    child: checkout.status == CheckoutStatus.loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Payment",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOptionCard extends ConsumerWidget {
  final String label;
  final IconData icon;
  final PaymentMethod method;

  const _PaymentOptionCard({
    required this.label,
    required this.icon,
    required this.method,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutProvider);
    final isSelected = checkout.selectedMethod == method;

    return InkWell(
      onTap: () => ref.read(checkoutProvider.notifier).selectMethod(method),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 96,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2F1) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? _kAccent : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? _kAccent : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? _kAccent : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSuccessDialog(BuildContext context, ReceiptData? receipt) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SuccessDialog(receipt: receipt),
  );
}

enum _PrintUiState { idle, printing, done, error, noPrinter }

/// Dialog sukses. Otomatis mencetak struk kalau printer sudah diatur dan
/// "Cetak otomatis" aktif; tombol "Cetak Struk" bisa dipakai cetak ulang.
class _SuccessDialog extends StatefulWidget {
  final ReceiptData? receipt;
  const _SuccessDialog({required this.receipt});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  _PrintUiState _state = _PrintUiState.idle;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final config = await ReceiptPrinterService.instance.loadConfig();
    if (!mounted) return;
    if (!config.hasPrinter) {
      setState(() => _state = _PrintUiState.noPrinter);
      return;
    }
    if (config.autoPrint) {
      await _print();
    }
  }

  Future<void> _print() async {
    final receipt = widget.receipt;
    if (receipt == null) return;
    setState(() {
      _state = _PrintUiState.printing;
      _message = 'Mencetak struk...';
    });
    final result = await ReceiptPrinterService.instance.printReceipt(receipt);
    if (!mounted) return;
    setState(() {
      _state = result.ok ? _PrintUiState.done : _PrintUiState.error;
      _message = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final printing = _state == _PrintUiState.printing;
    final hasReceipt = widget.receipt != null;

    Color statusColor = Colors.grey.shade500;
    if (_state == _PrintUiState.done) statusColor = _kAccent;
    if (_state == _PrintUiState.error) statusColor = Colors.red.shade400;

    String? statusText;
    switch (_state) {
      case _PrintUiState.printing:
      case _PrintUiState.done:
      case _PrintUiState.error:
        statusText = _message;
      case _PrintUiState.noPrinter:
        statusText =
            'Printer belum diatur. Atur di Profil > Printer Struk untuk '
            'mencetak struk.';
      case _PrintUiState.idle:
        statusText = null;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        width: 380,
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _kAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Success Create Order",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2430),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Congratulation you have been add the new order. "
              "Please check at list order page",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            if (statusText != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (printing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kAccent,
                        ),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            if (hasReceipt && _state != _PrintUiState.noPrinter) ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kAccent,
                    side: const BorderSide(color: _kAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: printing ? null : _print,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text(
                    _state == _PrintUiState.done ||
                            _state == _PrintUiState.error
                        ? 'Cetak Ulang Struk'
                        : 'Cetak Struk',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: printing ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  "Okay",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

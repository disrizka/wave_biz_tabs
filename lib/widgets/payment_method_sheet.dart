import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/screens/transaction/qris_payment_page.dart';

import '../../providers/checkout_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/sale_request.dart';


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

                            if (result.selectedMethod == PaymentMethod.qris) {
                              // Transaksi sudah dibuat di backend (status
                              // "pending"); buka WebView QRIS dan tunggu
                              // hasil polling status pembayaran.
                              final auth = ref.read(authProvider);
                              Navigator.of(context).pop(); // tutup modal ini
                              final paid = await Navigator.of(context)
                                  .push<bool?>(
                                    MaterialPageRoute(
                                      builder: (_) => QrisPaymentPage(
                                        paymentLink: result.paymentLink!,
                                        idTransaction: result.idTransaction!,
                                        accessToken: auth.accessToken!,
                                        businessId: auth.activeBusinessId!,
                                      ),
                                    ),
                                  );
                              if (paid == true && context.mounted) {
                                _showSuccessDialog(context);
                              }
                              // paid == false / null: transaksi tetap
                              // tercatat sebagai "pending"/gagal di list,
                              // user bisa cek ulang statusnya dari sana.
                            } else {
                              Navigator.of(context).pop();
                              _showSuccessDialog(context);
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

void _showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
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
            const SizedBox(height: 22),
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  "Okay",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

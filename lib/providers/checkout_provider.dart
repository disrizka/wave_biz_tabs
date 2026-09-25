import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/services/sale_api_service.dart';
import 'package:wave_biz_tabs/services/transaction_service.dart' as tx;

import '../core/constants.dart';
import '../models/sale_request.dart';
import 'auth_provider.dart';
import 'card_provider.dart';
import 'transaction_provider.dart';

enum CheckoutStatus { idle, loading, success, error }

class CheckoutState {
  final CheckoutStatus status;
  final PaymentMethod? selectedMethod;
  final String? errorMessage;

  /// Terisi hanya untuk QRIS: link Snap Midtrans yang harus dibuka di WebView,
  /// dan id transaksi yang baru dibuat (dipakai untuk polling status).
  final String? paymentLink;
  final String? idTransaction;

  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.selectedMethod,
    this.errorMessage,
    this.paymentLink,
    this.idTransaction,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? selectedMethod,
    String? errorMessage,
    bool clearError = false,
    String? paymentLink,
    String? idTransaction,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paymentLink: paymentLink ?? this.paymentLink,
      idTransaction: idTransaction ?? this.idTransaction,
    );
  }
}

class CheckoutNotifier extends Notifier<CheckoutState> {
  late final SaleService _service;

  @override
  CheckoutState build() {
    _service = SaleService();
    return const CheckoutState();
  }

  void selectMethod(PaymentMethod method) {
    state = state.copyWith(selectedMethod: method, clearError: true);
  }

  void reset() {
    state = const CheckoutState();
  }

  Future<void> submit() async {
    final method = state.selectedMethod;
    if (method == null) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Pilih metode pembayaran dulu',
      );
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Keranjang masih kosong',
      );
      return;
    }

    final auth = ref.read(authProvider);
    final businessId = auth.activeBusinessId;
    final accessToken = auth.accessToken;
    if (businessId == null || accessToken == null) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Sesi login tidak valid, silakan login ulang',
      );
      return;
    }

    state = state.copyWith(status: CheckoutStatus.loading, clearError: true);

    final reference = 'REF-${DateTime.now().millisecondsSinceEpoch}';

    // QRIS (Midtrans) — pakai TransactionService supaya dapat payment_link.
    if (method == PaymentMethod.qris) {
      try {
        final result = await tx.TransactionService().createQrisSale(
          accessToken: accessToken,
          businessId: businessId,
          storeLocationId: TransactionConstants.defaultStoreLocationId,
          reference: reference,
          items: cart.items
              .map(
                (item) => tx.SaleItemInput(
                  productId: item.productId,
                  productSkuId: item.skuId.isNotEmpty
                      ? item.skuId
                      : item.productId,
                  qty: item.quantity,
                  price: item.unitPrice,
                ),
              )
              .toList(),
        );

        state = state.copyWith(
          status: CheckoutStatus.success,
          paymentLink: result.paymentLink,
          idTransaction: result.idTransaction,
        );
        ref.read(cartProvider.notifier).clear();
        ref.invalidate(transactionListProvider);
      } catch (e) {
        state = state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: e.toString(),
        );
      }
      return;
    }

    // Cash / Debit — flow lama lewat SaleService.
    final request = SaleRequest(
      storeLocationId: TransactionConstants.defaultStoreLocationId,
      customerId: '', // dikosongkan
      reference: reference,
      paymentMethod: method,
      items: cart.items
          .map(
            (item) => SaleItem(
              productId: item.productId,
              productSkuId: item.skuId.isNotEmpty ? item.skuId : item.productId,
              qty: item.quantity,
              price: item.unitPrice,
            ),
          )
          .toList(),
    );

    try {
      await _service.createSale(
        businessId: businessId,
        accessToken: accessToken,
        request: request,
      );
      state = state.copyWith(status: CheckoutStatus.success);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(transactionListProvider);
    } catch (e) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final checkoutProvider = NotifierProvider<CheckoutNotifier, CheckoutState>(
  CheckoutNotifier.new,
);

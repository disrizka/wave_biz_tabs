import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/services/sale_api_service.dart';

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

  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.selectedMethod,
    this.errorMessage,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? selectedMethod,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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

    if (method == PaymentMethod.qris) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        errorMessage:
            'Pembayaran QRIS belum tersedia (menunggu integrasi Midtrans)',
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

    final request = SaleRequest(
      storeLocationId: TransactionConstants.defaultStoreLocationId,
      customerId: TransactionConstants.defaultCustomerId,
      reference: 'REF-${DateTime.now().millisecondsSinceEpoch}',
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

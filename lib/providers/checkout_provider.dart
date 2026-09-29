import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/services/sale_api_service.dart';
import 'package:wave_biz_tabs/services/transaction_service.dart' as tx;

import '../core/constants.dart';
import '../models/cart_model.dart';
import '../models/receipt_model.dart';
import '../models/sale_request.dart';
import 'auth_provider.dart';
import 'card_provider.dart';
import 'transaction_provider.dart';

enum CheckoutStatus { idle, loading, success, error }

class CheckoutState {
  final CheckoutStatus status;
  final PaymentMethod? selectedMethod;
  final String? errorMessage;
  final String? paymentToken;
  final String? idTransaction;
  final int? amount;

  /// Snapshot struk dari transaksi yang baru berhasil dibuat (dibuat sebelum
  /// keranjang dikosongkan), dipakai untuk mencetak struk.
  final ReceiptData? receipt;

  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.selectedMethod,
    this.errorMessage,
    this.paymentToken,
    this.idTransaction,
    this.amount,
    this.receipt,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? selectedMethod,
    String? errorMessage,
    bool clearError = false,
    String? paymentToken,
    String? idTransaction,
    int? amount,
    ReceiptData? receipt,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paymentToken: paymentToken ?? this.paymentToken,
      idTransaction: idTransaction ?? this.idTransaction,
      amount: amount ?? this.amount,
      receipt: receipt ?? this.receipt,
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

  ReceiptData _buildReceipt({
    required CartState cart,
    required AuthState auth,
    required PaymentMethod method,
    required String reference,
    String transactionId = '',
  }) {
    final user = auth.user;
    final cashier = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
        : (user?.username ?? '');

    return ReceiptData(
      businessName: auth.activeBusiness?.name ?? '',
      cashierName: cashier,
      reference: reference,
      transactionId: transactionId,
      dateTime: DateTime.now(),
      orderTypeLabel: cart.orderType == OrderType.takeaway
          ? 'Take Away'
          : 'Dine In',
      paymentMethodLabel: switch (method) {
        PaymentMethod.cash => 'Tunai',
        PaymentMethod.debit => 'Debit',
        PaymentMethod.qris => 'QRIS',
      },
      items: cart.items
          .map(
            (i) => ReceiptItem(
              name: i.name,
              variantLabel: i.variantLabel,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              note: i.note,
            ),
          )
          .toList(),
      total: cart.totalAmount,
    );
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
          paymentToken: result.paymentToken,
          idTransaction: result.idTransaction,
          amount: result.amount,
          receipt: _buildReceipt(
            cart: cart,
            auth: auth,
            method: method,
            reference: reference,
            transactionId: result.idTransaction,
          ),
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

    final request = SaleRequest(
      storeLocationId: TransactionConstants.defaultStoreLocationId,
      customerId: '',
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
      state = state.copyWith(
        status: CheckoutStatus.success,
        receipt: _buildReceipt(
          cart: cart,
          auth: auth,
          method: method,
          reference: reference,
        ),
      );
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

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_biz_tabs/models/cart_model.dart';
import 'package:wave_biz_tabs/models/product_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';

class CartState {
  final List<CartItem> items;
  final OrderType orderType;
  final bool isLoaded;

  const CartState({
    this.items = const [],
    this.orderType = OrderType.dineIn,
    this.isLoaded = false,
  });

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  int get totalAmount => items.fold(0, (sum, i) => sum + i.lineTotal);
  String get formattedTotal => formatIDR(totalAmount);
  bool get isEmpty => items.isEmpty;

  int quantityOf(String productId) {
    for (final item in items) {
      if (item.productId == productId) return item.quantity;
    }
    return 0;
  }

  CartState copyWith({
    List<CartItem>? items,
    OrderType? orderType,
    bool? isLoaded,
  }) {
    return CartState(
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  static const _itemsKeyPrefix = 'wave_biz_tabs.cart.items.';
  static const _orderTypeKeyPrefix = 'wave_biz_tabs.cart.orderType.';

  String get _businessId =>
      ref.read(authProvider).activeBusinessId ?? 'default';
  String get _itemsKey => '$_itemsKeyPrefix$_businessId';
  String get _orderTypeKey => '$_orderTypeKeyPrefix$_businessId';

  @override
  CartState build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.activeBusinessId != next.activeBusinessId) {
        // Kosongkan cart dulu supaya UI langsung menunjukkan 0,
        // baru load data cart milik bisnis yang baru aktif.
        state = const CartState(items: [], isLoaded: false);
        _load();
      }
    });
    Future.microtask(_load);
    return const CartState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_itemsKey);
      final items = <CartItem>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        items.addAll(decoded.map((e) => CartItem.fromJson(e)));
      }
      final orderTypeRaw = prefs.getString(_orderTypeKey);
      final orderType = orderTypeRaw == 'takeaway'
          ? OrderType.takeaway
          : OrderType.dineIn;
      state = CartState(items: items, orderType: orderType, isLoaded: true);
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _persistItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.items.map((e) => e.toJson()).toList());
    await prefs.setString(_itemsKey, raw);
  }

  Future<void> _persistOrderType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _orderTypeKey,
      state.orderType == OrderType.takeaway ? 'takeaway' : 'dineIn',
    );
  }

  int quantityOf(String productId) => state.quantityOf(productId);

  void setOrderType(OrderType type) {
    state = state.copyWith(orderType: type);
    _persistOrderType();
  }

  void addProduct(ProductModel product) {
    final id = product.idProduct.isNotEmpty ? product.idProduct : product.uuid;
    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == id);
    if (index == -1) {
      items.add(CartItem.fromProduct(product, quantity: 1));
    } else {
      items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
    }
    state = state.copyWith(items: items);
    _persistItems();
  }

  void increment(String productId) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == productId);
    if (index == -1) return;
    items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
    state = state.copyWith(items: items);
    _persistItems();
  }

  void decrement(String productId) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == productId);
    if (index == -1) return;
    final newQty = items[index].quantity - 1;
    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: newQty);
    }
    state = state.copyWith(items: items);
    _persistItems();
  }

  void removeItem(String productId) {
    final items = [...state.items]
      ..removeWhere((i) => i.productId == productId);
    state = state.copyWith(items: items);
    _persistItems();
  }

  void setNote(String productId, String note) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == productId);
    if (index == -1) return;
    items[index] = items[index].copyWith(note: note);
    state = state.copyWith(items: items);
    _persistItems();
  }

  void clear() {
    state = state.copyWith(items: []);
    _persistItems();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

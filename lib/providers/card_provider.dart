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
    final target = normalizeCartId(productId);
    return items
        .where((i) => normalizeCartId(i.productId) == target)
        .fold(0, (sum, i) => sum + i.quantity);
  }

  /// Semua ID yang mungkin dikenali buat produk ini: idProduct, uuid, dan
  /// code — dinormalisasi lewat [normalizeCartId], dipakai buat pencocokan
  /// yang "longgar" di bawah, ketimbang cuma ngandelin satu ID mentah aja.
  static Set<String> _candidateIdsOf(ProductModel product) => {
    if (product.idProduct.isNotEmpty) normalizeCartId(product.idProduct),
    if (product.uuid.isNotEmpty) normalizeCartId(product.uuid),
    if (product.code.isNotEmpty) normalizeCartId(product.code),
  }..removeWhere((v) => v.isEmpty);

  /// Total quantity produk ini di cart, dicocokkan longgar lewat
  /// [_candidateIdsOf] (bukan cuma satu ID kayak [quantityOf]).
  ///
  /// Ini buat nutupin kasus: produk yang udah ke-add ke cart (productId
  /// ke-simpen di situ), terus app di-restart, di-refresh, atau draft
  /// di-muat ulang, dan katalog produk di-fetch ULANG dari server — kalau
  /// ID yang dibalikin server buat produk yang sama ternyata nggak 100%
  /// identik antar-request (mis. angka dikirim sebagai `123` di satu
  /// endpoint dan `123.0` di endpoint lain, atau salah satu ngisi uuid yg
  /// satu nggak), matching berbasis satu ID mentah doang bakal gagal dan
  /// quantity-nya keliatan "reset" ke 0 di kartu produk padahal item-nya
  /// masih ada di cart/order summary.
  int quantityOfProduct(ProductModel product) {
    return items
        .where((i) => itemMatchesProduct(i, product))
        .fold(0, (sum, i) => sum + i.quantity);
  }

  /// Apakah baris cart [item] adalah produk [p] di katalog.
  ///
  /// idProduct/idProductSku di-encode ulang backend di TIAP response, jadi
  /// ID yang tersimpan di cart sebelum restart tidak akan sama dengan ID
  /// katalog yang baru di-fetch. Urutan pencocokan:
  ///  1. UUID produk (stabil) -> paling akurat.
  ///  2. Item lama (belum punya UUID): idProduct/uuid/code, lalu UUID SKU
  ///     (stabil, untuk produk varian), lalu nama produk.
  static bool itemMatchesProduct(CartItem item, ProductModel p) {
    if (item.productUuid.isNotEmpty && p.uuid.isNotEmpty) {
      return normalizeCartId(item.productUuid) == normalizeCartId(p.uuid);
    }
    if (_candidateIdsOf(p).contains(normalizeCartId(item.productId))) {
      return true;
    }
    if (item.skuUuid.isNotEmpty && p.skus.any((s) => s.uuid == item.skuUuid)) {
      return true;
    }
    final itemName = item.name.trim().toLowerCase();
    return item.productUuid.isEmpty &&
        itemName.isNotEmpty &&
        itemName == p.name.trim().toLowerCase();
  }

  /// Cart line non-variant yang match produk ini. Dipakai buat nemuin
  /// cartLineId "asli" yang tersimpan di cart, biar tombol +/-/hapus di
  /// kartu produk tetap ngenain baris yang benar walaupun ID katalog yang
  /// sekarang beda dari yang ke-simpen waktu item itu ditambahin.
  CartItem? matchingItem(ProductModel product) {
    for (final item in items) {
      if (item.skuUuid.isEmpty && itemMatchesProduct(item, product)) {
        return item;
      }
    }
    return null;
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

  void addProduct(
    ProductModel product, {
    ProductSku? sku,
    int quantity = 1,
    String note = '',
  }) {
    final newItem = CartItem.fromProduct(
      product,
      sku: sku,
      quantity: quantity,
      note: note,
    );
    final items = [...state.items];

    // Dicocokkan lewat UUID produk (stabil) + fallback ID lama, supaya produk
    // yang sudah ada di cart (mis. sebelum app di-restart) tidak dobel jadi
    // baris baru hanya karena idProduct dari server berubah.
    final index = items.indexWhere((i) {
      if (i.skuUuid != newItem.skuUuid) return false;
      if (i.cartLineId == newItem.cartLineId) return true;
      return CartState.itemMatchesProduct(i, product);
    });

    if (index == -1) {
      items.add(newItem);
    } else {
      items[index] = items[index].copyWith(
        quantity: items[index].quantity + quantity,
        note: note.isNotEmpty ? note : null,
        // Perbarui ID ke versi katalog terbaru + isi UUID untuk item lama.
        productId: newItem.productId,
        productUuid: newItem.productUuid,
      );
    }
    state = state.copyWith(items: items);
    _persistItems();
  }

  void increment(String cartLineId) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.cartLineId == cartLineId);
    if (index == -1) return;
    items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
    state = state.copyWith(items: items);
    _persistItems();
  }

  void decrement(String cartLineId) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.cartLineId == cartLineId);
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

  void removeItem(String cartLineId) {
    final items = [...state.items]
      ..removeWhere((i) => i.cartLineId == cartLineId);
    state = state.copyWith(items: items);
    _persistItems();
  }

  void setNote(String cartLineId, String note) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.cartLineId == cartLineId);
    if (index == -1) return;
    items[index] = items[index].copyWith(note: note);
    state = state.copyWith(items: items);
    _persistItems();
  }

  void clear() {
    state = state.copyWith(items: []);
    _persistItems();
  }

  void restore({required List<CartItem> items, required OrderType orderType}) {
    state = state.copyWith(items: items, orderType: orderType);
    _persistItems();
    _persistOrderType();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

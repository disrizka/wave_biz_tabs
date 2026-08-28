import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../services/product_service.dart';

const int kPageRevealBatch = 20;

class ProductHomeState {
  final bool isLoading;
  final String? error;

  /// Langsung dari field `allProducts` response API.
  /// true  -> business <= 200 produk, semua kategori & produk sudah lengkap
  ///          di satu response, chip "All Product" tersedia.
  /// false -> business > 200 produk, harus pilih kategori manual, tidak ada
  ///          opsi "All Product" (backend tidak menyediakan itu sekaligus).
  final bool allProducts;

  final List<ProductCategoryModel> categories;

  /// key = categoryName (sesuai grouping dari backend).
  final Map<String, List<ProductModel>> productsByCategoryName;

  /// null hanya valid kalau [allProducts] true (artinya chip "All Product"
  /// yang aktif). Kalau [allProducts] false, ini selalu terisi.
  final String? selectedCategoryId;

  final String search;

  /// Berapa item yang "dibuka" dari list kategori yang lagi aktif -
  /// ini yang bikin UI kerasa nampil cepat (20 dulu), nambah pas discroll,
  /// murni di client (tidak nembak API lagi) selama datanya masih ada.
  final int revealCount;

  final ProductPageMeta? pageMeta;
  final int backendPage;
  final bool loadingMore;

  const ProductHomeState({
    this.isLoading = true,
    this.error,
    this.allProducts = true,
    this.categories = const [],
    this.productsByCategoryName = const {},
    this.selectedCategoryId,
    this.search = '',
    this.revealCount = kPageRevealBatch,
    this.pageMeta,
    this.backendPage = 1,
    this.loadingMore = false,
  });

  String? _categoryNameOf(String? idProductCategory) {
    if (idProductCategory == null) return null;
    for (final c in categories) {
      if (c.idProductCategory == idProductCategory) return c.name;
    }
    return null;
  }

  /// Produk kategori yang lagi aktif (atau semua produk kalau chip "All
  /// Product" dipilih), SEBELUM kena search & reveal-windowing.
  List<ProductModel> get _activeFullList {
    if (selectedCategoryId == null) {
      // Chip "All Product" -> gabung semua kategori yang sudah kita punya.
      return productsByCategoryName.values.expand((e) => e).toList();
    }
    final name = _categoryNameOf(selectedCategoryId);
    return productsByCategoryName[name] ?? const [];
  }

  /// List yang benar-benar dirender di grid.
  /// - Kalau lagi search: tampilkan semua hasil match (datanya sudah ada
  ///   di memori, jadi tidak perlu windowing lagi).
  /// - Kalau tidak search: batasi sejumlah [revealCount] biar render cepat.
  List<ProductModel> get visibleProducts {
    final full = _activeFullList;
    if (search.trim().isEmpty) {
      return full.take(revealCount).toList();
    }
    final q = search.trim().toLowerCase();
    return full.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  bool get isSearching => search.trim().isNotEmpty;

  bool get canRevealMoreLocally =>
      !isSearching && revealCount < _activeFullList.length;

  bool get canFetchMoreFromBackend =>
      !isSearching && (pageMeta?.hasMorePages ?? false);

  ProductHomeState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? allProducts,
    List<ProductCategoryModel>? categories,
    Map<String, List<ProductModel>>? productsByCategoryName,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
    String? search,
    int? revealCount,
    ProductPageMeta? pageMeta,
    int? backendPage,
    bool? loadingMore,
  }) {
    return ProductHomeState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      allProducts: allProducts ?? this.allProducts,
      categories: categories ?? this.categories,
      productsByCategoryName:
          productsByCategoryName ?? this.productsByCategoryName,
      selectedCategoryId: clearSelectedCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      search: search ?? this.search,
      revealCount: revealCount ?? this.revealCount,
      pageMeta: pageMeta ?? this.pageMeta,
      backendPage: backendPage ?? this.backendPage,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// PENTING (Riverpod 3.x): tidak ada lagi `FamilyNotifier<State, Arg>`.
/// Notifier family sekarang tetap pakai `Notifier<State>` biasa, dan
/// argumen family (`businessId`) di-inject lewat CONSTRUCTOR, bukan lewat
/// parameter `build(arg)`. Satu instance notifier dibuat per businessId
/// oleh factory yang dikasih ke `NotifierProvider.family(...)` di bawah.
class ProductHomeNotifier extends Notifier<ProductHomeState> {
  ProductHomeNotifier(this.businessId);

  final String businessId;
  final ProductService _service = ProductService();

  @override
  ProductHomeState build() {
    Future.microtask(_init);
    return const ProductHomeState();
  }

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _service.getProducts(
        accessToken: _accessToken ?? '',
        businessId: businessId,
      );

      if (resp.allProducts) {
        state = state.copyWith(
          isLoading: false,
          allProducts: true,
          categories: resp.categories,
          productsByCategoryName: resp.productsByCategoryName,
          clearSelectedCategory: true, // "All Product" aktif by default
          pageMeta: resp.page,
          backendPage: 1,
          revealCount: kPageRevealBatch,
        );
        return;
      }

      // allProducts == false -> backend ngasih preview 1 kategori default.
      // Cari id kategori yang cocok sama nama grup yang dibalikin, biar
      // chip yang aktif kepilih otomatis & konsisten.
      String? defaultCategoryId;
      if (resp.productsByCategoryName.isNotEmpty) {
        final defaultName = resp.productsByCategoryName.keys.first;
        final match = resp.categories.where((c) => c.name == defaultName);
        if (match.isNotEmpty) defaultCategoryId = match.first.idProductCategory;
      }
      defaultCategoryId ??= resp.categories.isNotEmpty
          ? resp.categories.first.idProductCategory
          : null;

      state = state.copyWith(
        isLoading: false,
        allProducts: false,
        categories: resp.categories,
        productsByCategoryName: resp.productsByCategoryName,
        selectedCategoryId: defaultCategoryId,
        pageMeta: resp.page,
        backendPage: 1,
        revealCount: kPageRevealBatch,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  /// Tap chip kategori ("All Product" cuma ada kalau state.allProducts==true).
  Future<void> selectCategory(String? categoryId) async {
    if (state.allProducts) {
      // Semua data sudah ada di memori -> filter lokal, tanpa network call.
      state = state.copyWith(
        selectedCategoryId: categoryId,
        clearSelectedCategory: categoryId == null,
        revealCount: kPageRevealBatch,
        search: '',
      );
      return;
    }

    if (categoryId == null || categoryId == state.selectedCategoryId) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedCategoryId: categoryId,
      search: '',
      revealCount: kPageRevealBatch,
    );
    try {
      final resp = await _service.getProducts(
        accessToken: _accessToken ?? '',
        businessId: businessId,
        categoryId: categoryId,
      );
      // Ganti isi kategori ini aja (kategori lain yang sempat ke-cache
      // sebelumnya tidak relevan lagi untuk tampilan "all products" karena
      // allProducts == false, jadi cukup replace).
      state = state.copyWith(
        isLoading: false,
        productsByCategoryName: resp.productsByCategoryName,
        pageMeta: resp.page,
        backendPage: 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void search(String query) {
    state = state.copyWith(search: query);
  }

  /// Dipanggil pas scroll mendekati bawah. Ini yang mewujudkan
  /// "tampil 20 dulu, nanti kalau di-scroll/lihat semua baru load lagi".
  Future<void> loadMore() async {
    if (state.loadingMore) return;

    if (state.canRevealMoreLocally) {
      state = state.copyWith(revealCount: state.revealCount + kPageRevealBatch);
      return;
    }

    if (!state.canFetchMoreFromBackend) return;

    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.backendPage + 1;
      final resp = await _service.getProducts(
        accessToken: _accessToken ?? '',
        businessId: businessId,
        categoryId: state.selectedCategoryId,
        page: nextPage,
      );

      final merged = {...state.productsByCategoryName};
      resp.productsByCategoryName.forEach((name, items) {
        merged[name] = [...(merged[name] ?? []), ...items];
      });

      state = state.copyWith(
        productsByCategoryName: merged,
        pageMeta: resp.page,
        backendPage: nextPage,
        revealCount: state.revealCount + kPageRevealBatch,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> refresh() => _init();
}

/// `NotifierProvider.family<NotifierT, StateT, ArgT>(NotifierT Function(ArgT) create)`
/// -> di Riverpod 3.x, `create` cuma nerima `arg` dan harus BIKIN instance
/// notifier-nya sendiri (beda dari v2 yang pakai `.new` + `build(arg)`).
final productHomeProvider =
    NotifierProvider.family<ProductHomeNotifier, ProductHomeState, String>(
      (businessId) => ProductHomeNotifier(businessId),
    );

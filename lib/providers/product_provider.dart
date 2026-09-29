import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/models/product_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';
import 'package:wave_biz_tabs/services/api_service.dart';
import 'package:wave_biz_tabs/services/product_service.dart';

const int kPageRevealBatch = 20;

/// Kalau total produk lebih dari angka ini, search TIDAK lagi difilter lokal
/// per ketikan, tapi diambil dari API (`/product/pos?search=...`) setelah
/// user menekan Enter / tombol search.
const int kServerSearchThreshold = 200;

class ProductHomeState {
  final bool isLoading;
  final String? error;
  final bool allProducts;
  final List<ProductCategoryModel> categories;
  final Map<String, List<ProductModel>> productsByCategoryName;
  final String? selectedCategoryId;
  final String search;
  final int revealCount;
  final ProductPageMeta? pageMeta;
  final int backendPage;
  final bool loadingMore;

  // ---- Server-side search (dipakai kalau produk > kServerSearchThreshold) ----
  /// Keyword yang sudah di-submit (Enter / klik tombol search).
  final String submittedSearch;
  final List<ProductModel> searchResults;
  final ProductPageMeta? searchMeta;
  final int searchPage;
  final bool isSearchLoading;
  final String? searchError;

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
    this.submittedSearch = '',
    this.searchResults = const [],
    this.searchMeta,
    this.searchPage = 1,
    this.isSearchLoading = false,
    this.searchError,
  });

  /// True kalau katalog besar (> 200 produk) sehingga search harus ke API.
  ///
  /// Mode kategori (allProducts == false): list lokal cuma berisi satu
  /// kategori, jadi search SELALU ke API (`/product/pos?search=...`) agar
  /// menjangkau seluruh katalog.
  bool get usesServerSearch =>
      !allProducts || (pageMeta?.totalRows ?? 0) > kServerSearchThreshold;

  String? _categoryNameOf(String? idProductCategory) {
    if (idProductCategory == null) return null;
    for (final c in categories) {
      if (c.idProductCategory == idProductCategory) return c.name;
    }
    return null;
  }

  List<ProductModel> get _activeFullList {
    if (selectedCategoryId == null) {
      return productsByCategoryName.values.expand((e) => e).toList();
    }
    final name = _categoryNameOf(selectedCategoryId);
    return productsByCategoryName[name] ?? const [];
  }

  List<ProductModel> get visibleProducts {
    // Katalog besar: hasil search = bagian "products" dari response API.
    if (usesServerSearch && submittedSearch.trim().isNotEmpty) {
      return searchResults;
    }
    final full = _activeFullList;
    if (search.trim().isEmpty) {
      return full.take(revealCount).toList();
    }
    final q = search.trim().toLowerCase();
    return full.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  bool get isSearching => usesServerSearch
      ? submittedSearch.trim().isNotEmpty
      : search.trim().isNotEmpty;

  bool get canFetchMoreSearch =>
      usesServerSearch &&
      submittedSearch.trim().isNotEmpty &&
      (searchMeta?.hasMorePages ?? false);

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
    String? submittedSearch,
    List<ProductModel>? searchResults,
    ProductPageMeta? searchMeta,
    bool clearSearchMeta = false,
    int? searchPage,
    bool? isSearchLoading,
    String? searchError,
    bool clearSearchError = false,
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
      submittedSearch: submittedSearch ?? this.submittedSearch,
      searchResults: searchResults ?? this.searchResults,
      searchMeta: clearSearchMeta ? null : (searchMeta ?? this.searchMeta),
      searchPage: searchPage ?? this.searchPage,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
    );
  }
}

class ProductHomeNotifier extends Notifier<ProductHomeState> {
  final ProductService _service = ProductService();

  @override
  ProductHomeState build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.activeBusinessId != next.activeBusinessId ||
          previous?.accessToken != next.accessToken) {
        _init();
      }
    });

    Future.microtask(_init);
    return const ProductHomeState();
  }

  String? get _accessToken => ref.read(authProvider).accessToken;
  String? get _businessId => ref.read(authProvider).activeBusinessId;

  Future<ProductPosResponse> _fetchWithRetry({
    String? categoryId,
    String? search,
    int page = 1,
    int maxRetries = 1,
  }) async {
    final token = _accessToken ?? '';
    final bId = _businessId ?? '';

    var attempt = 0;
    while (true) {
      try {
        return await _service.getProducts(
          accessToken: token,
          businessId: bId,
          categoryId: categoryId,
          search: search,
          page: page,
        );
      } on ApiException catch (e) {
        final is401 = e.statusCode == 401;
        if (!is401 || attempt >= maxRetries) rethrow;
        attempt++;
        debugPrint('[ProductHomeNotifier] Retry request ke-$attempt...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<({Map<String, List<ProductModel>> grouped, ProductPageMeta page})>
  _fetchFlatGroupedWithRetry({
    String? categoryId,
    String? fallbackCategoryName,
    int page = 1,
    int maxRetries = 1,
  }) async {
    final token = _accessToken ?? '';
    final bId = _businessId ?? '';

    var attempt = 0;
    while (true) {
      try {
        final resp = await _service.getProductsFlat(
          accessToken: token,
          businessId: bId,
          categoryId: categoryId,
          page: page,
        );
        final Map<String, List<ProductModel>> grouped = {};
        for (final p in resp.products) {
          final key = p.categoryName ?? fallbackCategoryName ?? '';
          grouped.putIfAbsent(key, () => []).add(p);
        }
        return (grouped: grouped, page: resp.page);
      } on ApiException catch (e) {
        final is401 = e.statusCode == 401;
        if (!is401 || attempt >= maxRetries) rethrow;
        attempt++;
        debugPrint('[ProductHomeNotifier] Retry request ke-$attempt...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _init({bool resetState = true}) async {
    final token = _accessToken;
    final bId = _businessId;

    if (resetState) {
      state = const ProductHomeState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    if (token == null || token.isEmpty || bId == null || bId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sesi login atau bisnis aktif belum tersedia.',
      );
      return;
    }

    try {
      final resp = await _fetchWithRetry();

      if (resp.allProducts) {
        Map<String, List<ProductModel>> productsByCategoryName =
            resp.productsByCategoryName;
        ProductPageMeta pageMeta = resp.page;
        try {
          final flat = await _fetchFlatGroupedWithRetry();
          productsByCategoryName = flat.grouped;
          pageMeta = flat.page;
        } catch (_) {}

        state = state.copyWith(
          isLoading: false,
          allProducts: true,
          categories: resp.categories,
          productsByCategoryName: productsByCategoryName,
          clearSelectedCategory: true,
          pageMeta: pageMeta,
          backendPage: 1,
          revealCount: kPageRevealBatch,
        );
        return;
      }

      String? defaultCategoryId;
      String? defaultCategoryName;
      if (resp.productsByCategoryName.isNotEmpty) {
        final defaultName = resp.productsByCategoryName.keys.first;
        final match = resp.categories.where((c) => c.name == defaultName);
        if (match.isNotEmpty) {
          defaultCategoryId = match.first.idProductCategory;
          defaultCategoryName = defaultName;
        }
      }
      defaultCategoryId ??= resp.categories.isNotEmpty
          ? resp.categories.first.idProductCategory
          : null;
      defaultCategoryName ??= resp.categories.isNotEmpty
          ? resp.categories.first.name
          : null;

      Map<String, List<ProductModel>> productsByCategoryName =
          resp.productsByCategoryName;
      ProductPageMeta pageMeta = resp.page;
      if (defaultCategoryId != null) {
        try {
          final flat = await _fetchFlatGroupedWithRetry(
            categoryId: defaultCategoryId,
            fallbackCategoryName: defaultCategoryName,
          );
          productsByCategoryName = flat.grouped;
          pageMeta = flat.page;
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        allProducts: false,
        categories: resp.categories,
        productsByCategoryName: productsByCategoryName,
        selectedCategoryId: defaultCategoryId,
        pageMeta: pageMeta,
        backendPage: 1,
        revealCount: kPageRevealBatch,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    debugPrint(
      '[ProductProvider] selectCategory called: categoryId=$categoryId, '
      'state.allProducts=${state.allProducts}, '
      'state.selectedCategoryId=${state.selectedCategoryId}',
    );

    if (state.allProducts) {
      state = state.copyWith(
        selectedCategoryId: categoryId,
        clearSelectedCategory: categoryId == null,
        revealCount: kPageRevealBatch,
        search: '',
        submittedSearch: '',
        searchResults: const [],
        clearSearchMeta: true,
        clearSearchError: true,
      );
      return;
    }

    if (categoryId == null || categoryId == state.selectedCategoryId) {
      debugPrint(
        '[ProductProvider] selectCategory early-return (null or unchanged)',
      );
      return;
    }

    // Kalau kategori ini udah pernah di-fetch sebelumnya (mis. user sempat
    // pindah ke kategori lain buat cari produk, terus balik lagi), pakai
    // data yang udah ke-cache di [productsByCategoryName] daripada fetch
    // ulang ke server. Ini penting karena fetch ulang bakal bikin instance
    // ProductModel yang baru, dan kalau ID yang dikembalikan server buat
    // produk yang sama ternyata gak 100% identik antar-request, tampilan
    // quantity di ProductCard (yang dicocokkan lewat ID ini ke cart) bisa
    // "reset" ke 0 padahal item-nya masih ada di cart/order summary.
    // Pindah kategori jadi juga lebih instan (gak nunggu loading) buat
    // kategori yang udah pernah dibuka.
    final fallbackName = state._categoryNameOf(categoryId);
    final alreadyLoaded =
        fallbackName != null &&
        (state.productsByCategoryName[fallbackName]?.isNotEmpty ?? false);

    if (alreadyLoaded) {
      state = state.copyWith(
        selectedCategoryId: categoryId,
        search: '',
        submittedSearch: '',
        searchResults: const [],
        clearSearchMeta: true,
        clearSearchError: true,
        revealCount: kPageRevealBatch,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedCategoryId: categoryId,
      search: '',
      submittedSearch: '',
      searchResults: const [],
      clearSearchMeta: true,
      clearSearchError: true,
      revealCount: kPageRevealBatch,
    );
    try {
      final flat = await _fetchFlatGroupedWithRetry(
        categoryId: categoryId,
        fallbackCategoryName: fallbackName,
      );

      // Merge ke map yang udah ada, jangan ditimpa total — biar kategori
      // lain yang udah ke-load sebelumnya (dan produk yang udah ditambahin
      // ke cart dari situ) tetap ada di state, gak ilang pas kita pindah ke
      // kategori yang baru ini.
      final merged = {...state.productsByCategoryName, ...flat.grouped};

      state = state.copyWith(
        isLoading: false,
        productsByCategoryName: merged,
        pageMeta: flat.page,
        backendPage: 1,
      );

      debugPrint(
        '[ProductProvider] After update: selectedCategoryId=${state.selectedCategoryId}, '
        'matchedName=${state._categoryNameOf(state.selectedCategoryId)}, '
        'productsByCategoryName.keys=${state.productsByCategoryName.keys.toList()}, '
        'activeFullList.length=${state._activeFullList.length}, '
        'visibleProducts.length=${state.visibleProducts.length}',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  int _searchSeq = 0;

  /// Dipanggil tiap ketikan (onChanged).
  /// - Produk <= 200: filter lokal langsung (perilaku lama).
  /// - Produk  > 200: hanya simpan teks, TIDAK request. Request baru jalan
  ///   saat [submitSearch] (Enter / klik tombol search).
  void search(String query) {
    if (state.usesServerSearch && query.trim().isEmpty) {
      clearSearch();
      return;
    }
    state = state.copyWith(search: query);
  }

  /// Dipanggil saat user tekan Enter / klik tombol search.
  Future<void> submitSearch(String query) async {
    final q = query.trim();

    if (!state.usesServerSearch) {
      state = state.copyWith(search: query);
      return;
    }
    if (q.isEmpty) {
      clearSearch();
      return;
    }

    final seq = ++_searchSeq;
    state = state.copyWith(
      search: query,
      submittedSearch: q,
      searchResults: const [],
      clearSearchMeta: true,
      clearSearchError: true,
      searchPage: 1,
      isSearchLoading: true,
    );

    try {
      // Sengaja tanpa categoryId: sama seperti request
      // /product/pos?category=&brand=&search=masker (cari di semua kategori).
      final resp = await _fetchWithRetry(search: q);
      if (seq != _searchSeq) return; // ada search yang lebih baru
      state = state.copyWith(
        isSearchLoading: false,
        searchResults: resp.flatProducts, // = data.products
        searchMeta: resp.page,
        searchPage: 1,
      );
    } catch (e) {
      if (seq != _searchSeq) return;
      state = state.copyWith(isSearchLoading: false, searchError: '$e');
    }
  }

  void clearSearch() {
    _searchSeq++; // batalkan request search yang masih jalan
    state = state.copyWith(
      search: '',
      submittedSearch: '',
      searchResults: const [],
      clearSearchMeta: true,
      clearSearchError: true,
      searchPage: 1,
      isSearchLoading: false,
    );
  }

  Future<void> loadMore() async {
    if (state.loadingMore) return;

    if (state.canFetchMoreSearch) {
      final seq = _searchSeq;
      state = state.copyWith(loadingMore: true);
      try {
        final nextPage = state.searchPage + 1;
        final resp = await _fetchWithRetry(
          search: state.submittedSearch,
          page: nextPage,
        );
        if (seq != _searchSeq) return;
        state = state.copyWith(
          searchResults: [...state.searchResults, ...resp.flatProducts],
          searchMeta: resp.page,
          searchPage: nextPage,
          loadingMore: false,
        );
      } catch (_) {
        if (seq == _searchSeq) state = state.copyWith(loadingMore: false);
      }
      return;
    }

    if (state.canRevealMoreLocally) {
      state = state.copyWith(revealCount: state.revealCount + kPageRevealBatch);
      return;
    }

    if (!state.canFetchMoreFromBackend) return;

    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.backendPage + 1;
      final fallbackName = state._categoryNameOf(state.selectedCategoryId);
      final flat = await _fetchFlatGroupedWithRetry(
        categoryId: state.selectedCategoryId,
        fallbackCategoryName: fallbackName,
        page: nextPage,
      );

      final merged = {...state.productsByCategoryName};
      flat.grouped.forEach((name, items) {
        merged[name] = [...(merged[name] ?? []), ...items];
      });

      state = state.copyWith(
        productsByCategoryName: merged,
        pageMeta: flat.page,
        backendPage: nextPage,
        revealCount: state.revealCount + kPageRevealBatch,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> refresh() => _init(resetState: false);
}

final productHomeProvider =
    NotifierProvider<ProductHomeNotifier, ProductHomeState>(
      ProductHomeNotifier.new,
    );

/// Index lengkap SEMUA produk (bukan cuma halaman/kategori yang lagi
/// ke-reveal di [productHomeProvider]), dikunci lewat idProduct, uuid, DAN
/// uuid/id tiap SKU-nya.
///
/// Dipakai sebagai fallback di layar detail transaksi: endpoint
/// payment-check cuma ngirim ProductID/product_id/product_sku_id, bukan
/// nama produk, jadi nama aslinya (mis. "Burger") harus dicocokkan dari
/// katalog produk. Kalau cuma pakai [productHomeProvider] (yang defaultnya
/// cuma nge-reveal halaman pertama demi performa), produk yang ada di
/// halaman belakang bisa gagal ke-match dan jatuh ke fallback
/// "Produk #<id>". Provider ini nge-loop semua halaman sekali supaya
/// pencocokan nama selalu akurat sesuai data API, bukan hardcode.
///
/// SKU juga diindex terpisah karena ID produk yang dikirim balik oleh
/// endpoint transaksi (`ProductID`/`product_id`) kadang tidak match 1:1
/// dengan `idProduct`/`uuid` di endpoint katalog produk — sementara
/// `product_sku_id` yang dikirim saat checkout ([SaleItem.productSkuId])
/// hampir selalu match dengan salah satu SKU produknya, jadi ini jalur
/// pencocokan paling reliable kalau match by product ID gagal.
final productLookupProvider = FutureProvider<Map<String, ProductModel>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  final token = auth.accessToken ?? '';
  final businessId = auth.activeBusinessId ?? '';
  if (token.isEmpty || businessId.isEmpty) return {};

  final service = ProductService();
  final Map<String, ProductModel> byKey = {};

  var page = 1;
  const maxPages = 25; // jaga-jaga, batas wajar biar gak looping tanpa henti
  while (page <= maxPages) {
    final ProductFlatResponse resp;
    try {
      resp = await service.getProductsFlat(
        accessToken: token,
        businessId: businessId,
        page: page,
        limit: 200,
      );
    } catch (_) {
      break;
    }

    for (final p in resp.products) {
      if (p.idProduct.isNotEmpty) byKey[p.idProduct] = p;
      if (p.uuid.isNotEmpty) byKey[p.uuid] = p;
      for (final s in p.skus) {
        if (s.uuid.isNotEmpty) byKey[s.uuid] = p;
        if (s.idProductSku.isNotEmpty) byKey[s.idProductSku] = p;
      }
    }

    if (!resp.page.hasMorePages) break;
    page++;
  }

  debugPrint(
    '[productLookupProvider] selesai: ${byKey.length} key ke-index dari '
    'katalog produk. Contoh key: '
    '${byKey.keys.take(5).toList()}',
  );

  return byKey;
});

/// Detail produk untuk satu item transaksi. Key = "<productUuid>|<productId>".
/// Dicocokkan dari [productLookupProvider] (katalog lengkap).
final productDetailProvider = FutureProvider.family<ProductModel?, String>((
  ref,
  key,
) async {
  final lookup = await ref.watch(productLookupProvider.future);
  for (final k in key.split('|')) {
    if (k.isEmpty) continue;
    final p = lookup[k];
    if (p != null) return p;
  }
  return null;
});

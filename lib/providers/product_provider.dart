import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/models/product_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';
import 'package:wave_biz_tabs/services/api_service.dart';
import 'package:wave_biz_tabs/services/product_service.dart';

const int kPageRevealBatch = 20;

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

  List<ProductModel> get _activeFullList {
    if (selectedCategoryId == null) {
      return productsByCategoryName.values.expand((e) => e).toList();
    }
    final name = _categoryNameOf(selectedCategoryId);
    return productsByCategoryName[name] ?? const [];
  }

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

  Future<void> _init() async {
    final token = _accessToken;
    final bId = _businessId;

    if (token == null || token.isEmpty || bId == null || bId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sesi login atau bisnis aktif belum tersedia.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final resp = await _fetchWithRetry();

      if (resp.allProducts) {
        state = state.copyWith(
          isLoading: false,
          allProducts: true,
          categories: resp.categories,
          productsByCategoryName: resp.productsByCategoryName,
          clearSelectedCategory: true,
          pageMeta: resp.page,
          backendPage: 1,
          revealCount: kPageRevealBatch,
        );
        return;
      }

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

  Future<void> selectCategory(String? categoryId) async {
    if (state.allProducts) {
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
      final resp = await _fetchWithRetry(categoryId: categoryId);

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
      final resp = await _fetchWithRetry(
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

final productHomeProvider =
    NotifierProvider<ProductHomeNotifier, ProductHomeState>(
      ProductHomeNotifier.new,
    );

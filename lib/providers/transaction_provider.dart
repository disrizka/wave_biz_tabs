import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/models/product_model.dart' show ProductPageMeta;
import 'package:wave_biz_tabs/models/transaction_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';
import 'package:wave_biz_tabs/services/api_service.dart';
import 'package:wave_biz_tabs/services/transaction_service.dart';

enum TransactionDateFilter { all, yesterday, weekly, monthly }

class TransactionListState {
  final bool isLoading;
  final String? error;
  final List<TransactionModel> transactions;
  final TransactionDateFilter dateFilter;
  final String search;
  final ProductPageMeta? pageMeta;
  final int backendPage;
  final bool loadingMore;

  const TransactionListState({
    this.isLoading = true,
    this.error,
    this.transactions = const [],
    this.dateFilter = TransactionDateFilter.all,
    this.search = '',
    this.pageMeta,
    this.backendPage = 1,
    this.loadingMore = false,
  });

  bool get isSearching => search.trim().isNotEmpty;

  bool _matchesDateFilter(TransactionModel t) {
    if (dateFilter == TransactionDateFilter.all) return true;
    final dt = t.orderDateTime;
    if (dt == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(dt.year, dt.month, dt.day);

    switch (dateFilter) {
      case TransactionDateFilter.all:
        return true;
      case TransactionDateFilter.yesterday:
        return orderDay == today.subtract(const Duration(days: 1));
      case TransactionDateFilter.weekly:
        return !orderDay.isBefore(today.subtract(const Duration(days: 6))) &&
            !orderDay.isAfter(today);
      case TransactionDateFilter.monthly:
        return dt.year == now.year && dt.month == now.month;
    }
  }

  List<TransactionModel> get visibleTransactions {
    var list = transactions.where(_matchesDateFilter).toList();
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (t) =>
                t.number.toLowerCase().contains(q) ||
                t.customer.name.toLowerCase().contains(q) ||
                t.reference.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  bool get canLoadMore => !isSearching && (pageMeta?.hasMorePages ?? false);

  TransactionListState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<TransactionModel>? transactions,
    TransactionDateFilter? dateFilter,
    String? search,
    ProductPageMeta? pageMeta,
    int? backendPage,
    bool? loadingMore,
  }) {
    return TransactionListState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      transactions: transactions ?? this.transactions,
      dateFilter: dateFilter ?? this.dateFilter,
      search: search ?? this.search,
      pageMeta: pageMeta ?? this.pageMeta,
      backendPage: backendPage ?? this.backendPage,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class TransactionListNotifier extends Notifier<TransactionListState> {
  final TransactionService _service = TransactionService();

  @override
  TransactionListState build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.activeBusinessId != next.activeBusinessId ||
          previous?.accessToken != next.accessToken) {
        _init();
      }
    });

    Future.microtask(_init);
    return const TransactionListState();
  }

  String? get _accessToken => ref.read(authProvider).accessToken;
  String? get _businessId => ref.read(authProvider).activeBusinessId;

  Future<TransactionListResponse> _fetchWithRetry({
    int page = 1,
    int maxRetries = 1,
  }) async {
    final token = _accessToken ?? '';
    final bId = _businessId ?? '';

    var attempt = 0;
    while (true) {
      try {
        return await _service.getTransactions(
          accessToken: token,
          businessId: bId,
          page: page,
        );
      } on ApiException catch (e) {
        final is401 = e.statusCode == 401;
        if (!is401 || attempt >= maxRetries) rethrow;
        attempt++;
        debugPrint('[TransactionListNotifier] Retry request ke-$attempt...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _init({bool resetState = true}) async {
    final token = _accessToken;
    final bId = _businessId;

    if (resetState) {
      state = const TransactionListState(isLoading: true);
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
      state = state.copyWith(
        isLoading: false,
        transactions: resp.transactions,
        pageMeta: resp.page,
        backendPage: 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  void setDateFilter(TransactionDateFilter filter) {
    state = state.copyWith(dateFilter: filter);
  }

  void search(String query) {
    state = state.copyWith(search: query);
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.canLoadMore) return;

    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.backendPage + 1;
      final resp = await _fetchWithRetry(page: nextPage);
      state = state.copyWith(
        transactions: [...state.transactions, ...resp.transactions],
        pageMeta: resp.page,
        backendPage: nextPage,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> refresh() => _init(resetState: false);
}

final transactionListProvider =
    NotifierProvider<TransactionListNotifier, TransactionListState>(
      TransactionListNotifier.new,
    );

/// Detail transaksi per idTransaction, dari endpoint
/// `.../transaction/sales/{idTransaction}/payment-check`.
/// Dipanggil saat sebuah transaksi di list di-klik, contoh:
///
/// ```dart
/// ref.watch(transactionDetailProvider(transaction.idTransaction))
/// ```
final transactionDetailProvider =
    FutureProvider.family<TransactionDetailResponse, String>((
      ref,
      idTransaction,
    ) async {
      final auth = ref.watch(authProvider);
      final token = auth.accessToken ?? '';
      final businessId = auth.activeBusinessId ?? '';

      if (token.isEmpty || businessId.isEmpty) {
        throw ApiException('Sesi login atau bisnis aktif belum tersedia.');
      }

      final service = TransactionService();
      const maxRetries = 1;
      var attempt = 0;

      while (true) {
        try {
          return await service.getTransactionDetail(
            accessToken: token,
            businessId: businessId,
            idTransaction: idTransaction,
          );
        } on ApiException catch (e) {
          final is401 = e.statusCode == 401;
          if (!is401 || attempt >= maxRetries) rethrow;
          attempt++;
          debugPrint(
            '[transactionDetailProvider] Retry request ke-$attempt...',
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    });

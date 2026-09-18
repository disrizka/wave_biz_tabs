import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/models/transaction_model.dart';
import 'package:wave_biz_tabs/providers/transaction_provider.dart';
import 'package:wave_biz_tabs/screens/home/transaction_detail_screen.dart';

const _kAccent = Color(0xFF008080);

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key, this.businessId});

  final String? businessId;

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(transactionListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListProvider);
    final notifier = ref.read(transactionListProvider.notifier);
    final transactions = state.visibleTransactions;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Transaction List',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2430),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _searchField(notifier),
                      const SizedBox(height: 12),
                      _FilterChipRow(
                        selected: state.dateFilter,
                        onSelect: notifier.setDateFilter,
                      ),
                    ],
                  ),
                ),
              ),
              _buildBody(state, notifier, transactions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(TransactionListNotifier notifier) {
    return TextField(
      controller: _searchController,
      onChanged: notifier.search,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      decoration: InputDecoration(
        hintText: 'Quick search order',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
        filled: true,
        fillColor: const Color(0xFFF4F5F9),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kAccent, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildBody(
    TransactionListState state,
    TransactionListNotifier notifier,
    List<TransactionModel> transactions,
  ) {
    if (state.error != null && state.transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorView(message: state.error!, onRetry: notifier.refresh),
      );
    }

    if (state.isLoading && state.transactions.isEmpty) {
      return const SliverFillRemaining(
        // Center both axes: this sits inside a scroll view, so without an
        // Expanded/Fill the spinner would hug the top instead of sitting in
        // the middle of the available space.
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    if (transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  state.isSearching ||
                          state.dateFilter != TransactionDateFilter.all
                      ? 'Tidak ada transaksi yang cocok'
                      : 'Belum ada transaksi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // itemCount * 2 gives each card a SizedBox separator right after it
    // (except the trailing "load more" slot), without depending on the
    // SliverList.separated constructor.
    final itemCount = transactions.length + 1;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, rawIndex) {
          final isSeparator = rawIndex.isOdd;
          final index = rawIndex ~/ 2;

          if (isSeparator) return const SizedBox(height: 10);

          if (index == transactions.length) {
            if (!state.canLoadMore) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: state.loadingMore
                    ? const CircularProgressIndicator(color: _kAccent)
                    : TextButton(
                        onPressed: notifier.loadMore,
                        child: const Text('Muat Lebih Banyak'),
                      ),
              ),
            );
          }
          return _TransactionCard(transaction: transactions[index]);
        }, childCount: itemCount * 2 - 1),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.selected, required this.onSelect});

  final TransactionDateFilter selected;
  final ValueChanged<TransactionDateFilter> onSelect;

  static const _labels = {
    TransactionDateFilter.all: 'All',
    TransactionDateFilter.yesterday: 'Yesterday',
    TransactionDateFilter.weekly: 'Weekly',
    TransactionDateFilter.monthly: 'Monthly',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in TransactionDateFilter.values) ...[
            _FilterChip(
              label: _labels[filter]!,
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kAccent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final TransactionModel transaction;

  void _copyOrderNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: transaction.number));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nomor pesanan disalin'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TransactionDetailScreen(idTransaction: transaction.idTransaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTakeaway = transaction.orderType == TransactionOrderType.takeaway;
    final initials = transaction.customer.name.trim().isNotEmpty
        ? transaction.customer.name.trim()[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isTakeaway
                                  ? Icons.shopping_bag_outlined
                                  : Icons.restaurant_outlined,
                              size: 11,
                              color: _kAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              transaction.orderTypeLabel,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Order number: ${transaction.number}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _copyOrderNumber(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total payment',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.formattedAmount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2430),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _kAccent.withOpacity(0.12),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.customer.name.isNotEmpty
                            ? transaction.customer.name
                            : 'Pelanggan',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2430),
                        ),
                      ),
                      Text(
                        transaction.formattedDate,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (transaction.items.isNotEmpty)
                  Text(
                    '${transaction.totalItemQty} item${transaction.totalItemQty > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

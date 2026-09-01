import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/core/responsive.dart';
import 'package:wave_biz_tabs/providers/product_provider.dart';
import 'package:wave_biz_tabs/screens/home/widgets/category_chip_row.dart';
import 'package:wave_biz_tabs/screens/home/widgets/product_card.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  final String businessId;

  const ProductListScreen({super.key, required this.businessId});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
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
      ref.read(productHomeProvider(widget.businessId).notifier).loadMore();
    }
  }

  int _gridColumns(BuildContext context) {
    if (Responsive.isDesktop(context)) return 5;
    if (Responsive.isTablet(context)) return 4;
    return 2;
  }

  Widget _searchField(ProductHomeState state) {
    return TextField(
      controller: _searchController,
      onChanged: ref
          .read(productHomeProvider(widget.businessId).notifier)
          .search,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      decoration: InputDecoration(
        hintText: state.allProducts
            ? 'Quick search product/menu...'
            : 'Cari produk di kategori ini...',
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
          borderSide: const BorderSide(color: Color(0xFF3B5FE0), width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productHomeProvider(widget.businessId));
    final notifier = ref.read(productHomeProvider(widget.businessId).notifier);
    final columns = _gridColumns(context);
    final products = state.visibleProducts;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: state.error != null
            ? _ErrorView(message: state.error!, onRetry: notifier.refresh)
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isMobile) ...[
                            // Mobile (figma): search dulu di atas, chip di bawahnya.
                            _searchField(state),
                            if (state.categories.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              CategoryChipRow(
                                categories: state.categories,
                                selectedCategoryId: state.selectedCategoryId,
                                showAllChip: state.allProducts,
                                onSelect: notifier.selectCategory,
                              ),
                            ],
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (state.categories.isNotEmpty)
                                  Expanded(
                                    child: CategoryChipRow(
                                      categories: state.categories,
                                      selectedCategoryId:
                                          state.selectedCategoryId,
                                      showAllChip: state.allProducts,
                                      onSelect: notifier.selectCategory,
                                    ),
                                  )
                                else
                                  const Spacer(),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 300,
                                  child: _searchField(state),
                                ),
                              ],
                            ),
                          ],
                          if (!state.allProducts && !state.isSearching)
                            Padding(padding: const EdgeInsets.only(top: 8)),
                        ],
                      ),
                    ),
                  ),
                  if (state.isLoading && products.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (products.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          state.isSearching
                              ? 'Produk tidak ditemukan'
                              : 'Belum ada produk',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final p = products[index];
                          return ProductCard(
                            product: p,
                            onAdd: () {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text('${p.name} ditambahkan'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                            },
                          );
                        }, childCount: products.length),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: state.loadingMore
                              ? const CircularProgressIndicator()
                              : (state.canRevealMoreLocally ||
                                    state.canFetchMoreFromBackend)
                              ? TextButton(
                                  onPressed: notifier.loadMore,
                                  child: const Text('Muat Lebih Banyak'),
                                )
                              : Text(
                                  'Semua produk sudah ditampilkan',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../providers/product_provider.dart';
import 'widgets/category_chip_row.dart';
import 'widgets/product_card.dart';

/// Halaman katalog produk untuk satu business, berdasarkan endpoint ASLI
/// `GET /waveup/{idBusiness}/product/pos?category=&brand=`.
///
/// - Business <= 200 produk (`allProducts: true`): semua kategori & produk
///   didapat sekali fetch. Chip "All Product" tersedia, dan pindah kategori
///   cuma filter lokal (instan, tanpa network call lagi).
/// - Business > 200 produk (`allProducts: false`): tidak ada chip "All
///   Product" (backend memang tidak menyediakan itu sekaligus) - user pilih
///   1 kategori, baru produknya di-fetch. Kategori pertama dipilih otomatis
///   dari preview default yang dikasih backend.
/// - Di kedua mode, grid awalnya cuma nampilin 20 item (`kPageRevealBatch`)
///   biar render cepat, nambah 20 lagi tiap discroll mendekati bawah -
///   ini murni di client selama datanya sudah ke-fetch; kalau kategori itu
///   sendiri > 200 produk (jarang, tapi mungkin), baru nembak API lagi buat
///   halaman berikutnya.
class ProductListScreen extends ConsumerStatefulWidget {
  final String businessId;
  final String businessName;

  const ProductListScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productHomeProvider(widget.businessId));
    final notifier = ref.read(productHomeProvider(widget.businessId).notifier);
    final columns = _gridColumns(context);
    final products = state.visibleProducts;

    return Scaffold(
      appBar: AppBar(title: Text(widget.businessName)),
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
                          if (state.categories.isNotEmpty) ...[
                            CategoryChipRow(
                              categories: state.categories,
                              selectedCategoryId: state.selectedCategoryId,
                              showAllChip: state.allProducts,
                              onSelect: notifier.selectCategory,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _searchController,
                            onChanged: notifier.search,
                            decoration: InputDecoration(
                              hintText: state.allProducts
                                  ? 'Quick search product/menu...'
                                  : 'Cari produk di kategori ini...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (!state.allProducts && !state.isSearching)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Katalog besar (> 200 produk) - browse per kategori supaya tetap cepat.',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              ProductCard(product: products[index]),
                          childCount: products.length,
                        ),
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

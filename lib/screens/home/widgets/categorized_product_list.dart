import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/models/product_model.dart';
import 'package:wave_biz_tabs/screens/home/widgets/cart_connected_product_card.dart';

const _kBrandBlue = Color(0xFF008080);
const _kBarHeight = 38.0;

class CategorizedProductList extends StatefulWidget {
  final Map<String, List<ProductModel>> productsByCategoryName;
  final int columns;

  const CategorizedProductList({
    super.key,
    required this.productsByCategoryName,
    required this.columns,
  });

  @override
  State<CategorizedProductList> createState() => _CategorizedProductListState();
}

class _CategorizedProductListState extends State<CategorizedProductList> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _activeCategory;

  List<String> get _names => widget.productsByCategoryName.keys
      .where((k) => (widget.productsByCategoryName[k] ?? const []).isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateActiveCategory);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateActiveCategory(),
    );
  }

  @override
  void didUpdateWidget(covariant CategorizedProductList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateActiveCategory(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateActiveCategory);
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String name) =>
      _sectionKeys.putIfAbsent(name, () => GlobalKey());

  void _updateActiveCategory() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.offset <= 4) {
      if (_activeCategory != null) setState(() => _activeCategory = null);
      return;
    }

    final scrollBox =
        _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null || !scrollBox.attached) return;
    final origin = scrollBox.localToGlobal(Offset.zero).dy;

    String? best;
    double bestY = -double.infinity;
    for (final name in _names) {
      final ctx = _sectionKeys[name]?.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy - origin - _kBarHeight;
      if (y <= 4 && y > bestY) {
        bestY = y;
        best = name;
      }
    }
    best ??= _names.isNotEmpty ? _names.first : null;
    if (best != _activeCategory) {
      setState(() => _activeCategory = best);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToCategory(String name) {
    final ctx = _sectionKeys[name]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            children: [
              _SimpleChip(
                label: 'All Product',
                selected: _activeCategory == null,
                onTap: _scrollToTop,
              ),
              for (final name in names) ...[
                const SizedBox(width: 8),
                _SimpleChip(
                  label: name,
                  selected: _activeCategory == name,
                  onTap: () => _scrollToCategory(name),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: names.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada produk',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : Stack(
                  children: [
                    CustomScrollView(
                      key: _scrollViewKey,
                      controller: _scrollController,
                      slivers: [
                        // Reserves room so the first section's own label
                        // isn't hidden underneath the sticky bar overlay.
                        const SliverToBoxAdapter(
                          child: SizedBox(height: _kBarHeight),
                        ),
                        for (final name in names) ...[
                          SliverToBoxAdapter(
                            child: Container(
                              key: _keyFor(name),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2430),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: widget.columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.62,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = widget
                                      .productsByCategoryName[name]![index];
                                  return CartConnectedProductCard(
                                    product: product,
                                  );
                                },
                                childCount:
                                    widget.productsByCategoryName[name]!.length,
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                    if (_activeCategory != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Container(
                          height: _kBarHeight,
                          color: Colors.white,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _activeCategory!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2430),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SimpleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SimpleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9.5),
        decoration: BoxDecoration(
          color: selected ? _kBrandBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kBrandBlue : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kBrandBlue.withOpacity(0.24),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

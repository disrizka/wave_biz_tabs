import 'package:flutter/material.dart';

import '../../../models/product_model.dart';

const _kBrandBlue = Color(0xFF3B5FE0);

/// Trigger "All Product" + tombol "Kategori: X v" yang membuka dropdown
/// mega-menu di bawahnya (mirip dropdown "Produk" / "Top Up & Tagihan" di
/// Telkomsel) - isinya SEMUA kategori dalam grid multi-kolom + search,
/// bukan chip yang di-wrap permanen di layar.
class CategoryChipRow extends StatefulWidget {
  const CategoryChipRow({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.showAllChip,
    required this.onSelect,
  });

  final List<ProductCategoryModel> categories;
  final String? selectedCategoryId;
  final bool showAllChip;
  final ValueChanged<String?> onSelect;

  @override
  State<CategoryChipRow> createState() => _CategoryChipRowState();
}

class _CategoryChipRowState extends State<CategoryChipRow> {
  final _link = LayerLink();
  final _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  String? get _selectedName {
    for (final c in widget.categories) {
      if (c.idProductCategory == widget.selectedCategoryId) return c.name;
    }
    return null;
  }

  void _toggleMenu() {
    if (_open) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final buttonSize = box.size;
    final buttonGlobalPos = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    const edgeMargin = 16.0;

    final panelWidth = screenSize.width < 500
        ? screenSize.width - edgeMargin * 2
        : (screenSize.width < 900 ? 480.0 : 640.0);
    final panelMaxHeight = (screenSize.height * 0.6).clamp(280.0, 470.0);

    // Panel by default aligns to the button's left edge. On narrow screens
    // (or when the button sits far right) that can push the panel past the
    // screen edge and get clipped. Shift it left just enough to stay within
    // [edgeMargin, screenWidth - edgeMargin].
    double dx = 0;
    final wouldOverflowRight =
        buttonGlobalPos.dx + panelWidth > screenSize.width - edgeMargin;
    if (wouldOverflowRight) {
      dx = (screenSize.width - edgeMargin) - (buttonGlobalPos.dx + panelWidth);
    }
    final minDx = -(buttonGlobalPos.dx - edgeMargin);
    if (dx < minDx) dx = minDx;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(dx, buttonSize.height + 10),
              child: Material(
                color: Colors.transparent,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _MegaMenuPanel(
                    width: panelWidth,
                    maxHeight: panelMaxHeight,
                    categories: widget.categories,
                    selectedCategoryId: widget.selectedCategoryId,
                    showAllChip: widget.showAllChip,
                    onSelect: (id) {
                      widget.onSelect(id);
                      _closeMenu();
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _open = true);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.selectedCategoryId == null
        ? (widget.showAllChip ? 'All Product' : 'Pilih Kategori')
        : (_selectedName ?? 'Kategori');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showAllChip) ...[
          _Chip(
            label: 'All Product',
            selected: widget.selectedCategoryId == null,
            onTap: () => widget.onSelect(null),
          ),
          const SizedBox(width: 8),
        ],
        CompositedTransformTarget(
          link: _link,
          child: _Chip(
            key: _buttonKey,
            label: widget.selectedCategoryId != null
                ? 'Kategori: $label'
                : 'Kategori',
            selected: widget.selectedCategoryId != null || _open,
            trailingIcon: _open
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            onTap: _toggleMenu,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && trailingIcon == null) ...[
              const Icon(Icons.check, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
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
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(
                trailingIcon,
                size: 18,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Panel mega-menu: search box + grid multi-kolom semua kategori,
/// scrollable kalau isinya banyak (200+). Grid dikasih garis tipis
/// pemisah antar baris/kolom, item aktif ditandai kartu rounded biru
/// muda dengan checklist bulat kecil di kanan.
class _MegaMenuPanel extends StatefulWidget {
  const _MegaMenuPanel({
    required this.width,
    required this.maxHeight,
    required this.categories,
    required this.selectedCategoryId,
    required this.showAllChip,
    required this.onSelect,
  });

  final double width;
  final double maxHeight;
  final List<ProductCategoryModel> categories;
  final String? selectedCategoryId;
  final bool showAllChip;
  final ValueChanged<String?> onSelect;

  @override
  State<_MegaMenuPanel> createState() => _MegaMenuPanelState();
}

class _MegaMenuPanelState extends State<_MegaMenuPanel> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? widget.categories
        : widget.categories
              .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    final columns = widget.width >= 560 ? 3 : (widget.width >= 380 ? 2 : 1);
    final itemCount = filtered.length + (widget.showAllChip ? 1 : 0);
    final rows = (itemCount / columns).ceil();

    return Container(
      width: widget.width,
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kBrandBlue.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800),
              decoration: InputDecoration(
                hintText: 'Cari kategori...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF4F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBrandBlue, width: 1.4),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          color: Colors.grey.shade300,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kategori tidak ditemukan',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: itemCount,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 46,
                        crossAxisSpacing: 0,
                        mainAxisSpacing: 0,
                      ),
                      itemBuilder: (context, index) {
                        final col = index % columns;
                        final row = index ~/ columns;
                        final isLastCol = col == columns - 1;
                        final isLastRow = row == rows - 1;

                        final Widget cell;
                        if (widget.showAllChip && index == 0) {
                          cell = _MenuRow(
                            label: 'All Product',
                            selected: widget.selectedCategoryId == null,
                            onTap: () => widget.onSelect(null),
                          );
                        } else {
                          final c =
                              filtered[index - (widget.showAllChip ? 1 : 0)];
                          cell = _MenuRow(
                            label: c.name,
                            selected:
                                c.idProductCategory ==
                                widget.selectedCategoryId,
                            onTap: () => widget.onSelect(c.idProductCategory),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: isLastCol
                                  ? BorderSide.none
                                  : BorderSide(color: Colors.grey.shade100),
                              bottom: isLastRow
                                  ? BorderSide.none
                                  : BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: cell,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kBrandBlue.withOpacity(0.08) : null,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: _kBrandBlue.withOpacity(0.35))
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selected ? _kBrandBlue : Colors.black87,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: _kBrandBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

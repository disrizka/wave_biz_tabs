import 'package:flutter/material.dart';

import '../../../models/product_model.dart';

class CategoryChipRow extends StatelessWidget {
  final List<ProductCategoryModel> categories;
  final String? selectedCategoryId; // null = "All Product" (kalau ada)
  final bool showAllChip;
  final ValueChanged<String?> onSelect;

  const CategoryChipRow({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
    this.showAllChip = true,
  });

  @override
  Widget build(BuildContext context) {
    final offset = showAllChip ? 1 : 0;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + offset,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = showAllChip && index == 0;
          final category = isAll ? null : categories[index - offset];
          final selected = isAll
              ? selectedCategoryId == null
              : selectedCategoryId == category!.idProductCategory;
          final label = isAll ? 'All Product' : category!.name;

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) =>
                onSelect(isAll ? null : category!.idProductCategory),
            selectedColor: const Color(0xFF3B5FE0),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: Colors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
          );
        },
      ),
    );
  }
}

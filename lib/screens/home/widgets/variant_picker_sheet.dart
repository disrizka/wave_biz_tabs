import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/models/product_model.dart';

const _kAccent = Color(0xFF008080);
const _kAccentTint = Color(0xFFE0F2F1);
const _kAccentBorder = Color(0xFFB2DFDB);

Future<({ProductSku sku, int quantity, String note})?> showVariantPickerSheet(
  BuildContext context,
  ProductModel product,
) {
  return showModalBottomSheet<({ProductSku sku, int quantity, String note})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _VariantPickerSheet(product: product),
  );
}

class _VariantPickerSheet extends StatefulWidget {
  final ProductModel product;

  const _VariantPickerSheet({required this.product});

  @override
  State<_VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<_VariantPickerSheet> {
  late final Map<String, List<String>> _groups = widget.product.variantGroups;
  final Map<String, String> _selection = {};
  final _noteController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  ProductSku? get _matchedSku => widget.product.skuForSelection(_selection);

  bool get _isComplete => _groups.keys.every(_selection.containsKey);

  int get _unitPrice => _matchedSku?.price ?? widget.product.minVariantPrice;

  String _formatRupiah(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return 'Rp. $buffer';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final groupNames = _groups.keys.toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: product.photoPath.isNotEmpty
                              ? Image.network(
                                  product.photoPath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFF4F5F9),
                                    child: Icon(
                                      Icons.fastfood_outlined,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFF4F5F9),
                                  child: Icon(
                                    Icons.fastfood_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1F2430),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatRupiah(_unitPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: _kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _QuantityStepper(
                        quantity: _quantity,
                        onDecrement: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        onIncrement: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20, color: Color(0xFFF0F0F0)),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: groupNames.length,
                    itemBuilder: (context, index) {
                      final name = groupNames[index];
                      final values = _groups[name]!;
                      final selected = _selection[name];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF1F2430),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Required, Only One',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...values.map((value) {
                              final isSelected = selected == value;
                              return InkWell(
                                onTap: () =>
                                    setState(() => _selection[name] = value),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        size: 20,
                                        color: isSelected
                                            ? _kAccent
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.0,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: const Color(0xFF1F2430),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1F2430),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Tambahkan catatan (opsional)',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: _kAccent,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kAccent,
                            side: const BorderSide(color: _kAccentBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isComplete && _matchedSku != null
                              ? () => Navigator.of(context).pop((
                                  sku: _matchedSku!,
                                  quantity: _quantity,
                                  note: _noteController.text.trim(),
                                ))
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccent,
                            disabledBackgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add to cart',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _QuantityStepper({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kAccentTint,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove, onTap: onDecrement),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: Color(0xFF1F2430),
              ),
            ),
          ),
          _StepButton(icon: Icons.add, onTap: onIncrement, filled: true),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  const _StepButton({required this.icon, this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: filled
            ? const BoxDecoration(color: _kAccent, shape: BoxShape.circle)
            : null,
        child: Icon(
          icon,
          size: 15,
          color: onTap == null
              ? Colors.grey.shade400
              : (filled ? Colors.white : _kAccent),
        ),
      ),
    );
  }
}

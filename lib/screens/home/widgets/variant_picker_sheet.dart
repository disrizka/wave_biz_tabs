import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/models/product_model.dart';

const _kAccent = Color(0xFF008080);
const _kAccentTint = Color(0xFFE0F2F1);
const _kAccentBorder = Color(0xFFB2DFDB);
const _kInk = Color(0xFF1F2430);
const _kSubtle = Color(0xFFF4F5F9);

Future<({ProductSku sku, int quantity, String note})?> showVariantPickerSheet(
  BuildContext context,
  ProductModel product,
) {
  return showModalBottomSheet<({ProductSku sku, int quantity, String note})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
  static const int _kNoteMaxLength = 140;

  late final Map<String, List<String>> _groups = widget.product.variantGroups;
  final Map<String, String> _selection = {};
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();
  int _quantity = 1;
  bool _noteFocused = false;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() => setState(() {}));
    _noteFocusNode.addListener(
      () => setState(() => _noteFocused = _noteFocusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  ProductSku? get _matchedSku => widget.product.skuForSelection(_selection);

  bool get _isComplete => _groups.keys.every(_selection.containsKey);

  int get _unitPrice => _matchedSku?.price ?? widget.product.minVariantPrice;

  int get _totalPrice => _unitPrice * _quantity;

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
          initialChildSize: 0.66,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: product.photoPath.isNotEmpty
                              ? Image.network(
                                  product.photoPath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: _kSubtle,
                                    child: Icon(
                                      Icons.fastfood_outlined,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: _kSubtle,
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
                                fontSize: 15.5,
                                color: _kInk,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatRupiah(_unitPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 22, color: Color(0xFFEFEFF2)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: groupNames.length + 1,
                    itemBuilder: (context, index) {
                      if (index == groupNames.length) {
                        return _NotesField(
                          controller: _noteController,
                          focusNode: _noteFocusNode,
                          focused: _noteFocused,
                          maxLength: _kNoteMaxLength,
                        );
                      }

                      final name = groupNames[index];
                      final values = _groups[name]!;
                      final selected = _selection[name];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: _kInk,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kAccentTint,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Required · Pick 1',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _kAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...values.map((value) {
                              final isSelected = selected == value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _selection[name] = value),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _kAccentTint
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? _kAccent
                                            : Colors.grey.shade200,
                                        width: isSelected ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
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
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: _kInk,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatRupiah(_totalPrice),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _kInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kAccent,
                                  side: const BorderSide(color: _kAccentBorder),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Add to cart',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// Polished notes card: soft tinted container, icon, live character counter,
/// and a highlighted border while focused.
class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final int maxLength;

  const _NotesField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final length = controller.text.characters.length;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 18, color: _kAccent),
              const SizedBox(width: 6),
              const Text(
                'Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: _kInk,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(optional)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: focused ? Colors.white : _kSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: focused ? _kAccent : Colors.grey.shade200,
                width: focused ? 1.4 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: maxLength,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _kInk,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. extra spicy, no onions…',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$length/$maxLength',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            width: 26,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: _kInk,
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

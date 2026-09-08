import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/core/snackbar_utils.dart';
import 'package:wave_biz_tabs/models/cart_model.dart';
import 'package:wave_biz_tabs/providers/card_provider.dart';

class OrderSummaryPanel extends ConsumerStatefulWidget {
  const OrderSummaryPanel({super.key});

  @override
  ConsumerState<OrderSummaryPanel> createState() => _OrderSummaryPanelState();
}

class _OrderSummaryPanelState extends ConsumerState<OrderSummaryPanel> {
  String? _editingNoteFor;
  final Map<String, TextEditingController> _noteControllers = {};

  TextEditingController _controllerFor(CartItem item) {
    return _noteControllers.putIfAbsent(
      item.productId,
      () => TextEditingController(text: item.note),
    );
  }

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmRemove(BuildContext context, CartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteProductDialog(productName: item.name),
    );
    if (confirmed == true) {
      final removedQty = item.quantity;
      ref.read(cartProvider.notifier).removeItem(item.productId);
      if (_editingNoteFor == item.productId) {
        setState(() => _editingNoteFor = null);
      }
      _noteControllers.remove(item.productId);
      if (!context.mounted) return;
      showCartSnackBar(
        context,
        message: '${item.name} dihapus dari pesanan (${removedQty}x)',
        icon: Icons.delete_outline_rounded,
        color: Colors.redAccent,
      );
    }
  }

  void _handleIncrement(BuildContext context, CartItem item) {
    ref.read(cartProvider.notifier).increment(item.productId);
    showCartSnackBar(
      context,
      message: '${item.name} ditambah (${item.quantity + 1})',
      icon: Icons.add_circle_rounded,
      color: Colors.green,
    );
  }

  void _handleDecrement(BuildContext context, CartItem item) {
    final remaining = item.quantity - 1;
    ref.read(cartProvider.notifier).decrement(item.productId);
    if (_editingNoteFor == item.productId && remaining <= 0) {
      setState(() => _editingNoteFor = null);
    }
    if (remaining <= 0) {
      _noteControllers.remove(item.productId);
      showCartSnackBar(
        context,
        message: '${item.name} dihapus dari pesanan',
        icon: Icons.delete_outline_rounded,
        color: Colors.redAccent,
      );
    } else {
      showCartSnackBar(
        context,
        message: '${item.name} dikurangi ($remaining)',
        icon: Icons.remove_circle_rounded,
        color: Colors.orange,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final isEmpty = cart.isEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderTypeToggle(
            orderType: cart.orderType,
            onChanged: notifier.setOrderType,
          ),
          const SizedBox(height: 18),
          const Text(
            'Order summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2430),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isEmpty
                ? Center(
                    child: Text(
                      'Belum ada produk ditambahkan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 20, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final isEditing = _editingNoteFor == item.productId;
                      return _CartItemRow(
                        item: item,
                        isEditingNote: isEditing,
                        noteController: _controllerFor(item),
                        onToggleNote: () {
                          setState(() {
                            _editingNoteFor = isEditing ? null : item.productId;
                          });
                        },
                        onSaveNote: (value) {
                          notifier.setNote(item.productId, value);
                          setState(() => _editingNoteFor = null);
                        },
                        onIncrement: () => _handleIncrement(context, item),
                        onDecrement: () => _handleDecrement(context, item),
                        onRemove: () => _confirmRemove(context, item),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1FD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cart.orderType == OrderType.takeaway
                              ? Icons.shopping_bag_outlined
                              : Icons.restaurant_outlined,
                          size: 12,
                          color: const Color(0xFF3B5FE0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cart.orderType == OrderType.takeaway
                              ? 'Takeaway'
                              : 'Dine in',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B5FE0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                isEmpty
                    ? 'Rp 0'
                    : 'Rp ${cart.totalAmount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2430),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: isEmpty ? null : () {},
              icon: const Icon(Icons.credit_card, size: 18),
              label: const Text(
                'Continue Payment',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B5FE0),
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeToggle extends StatelessWidget {
  final OrderType orderType;
  final ValueChanged<OrderType> onChanged;

  const _OrderTypeToggle({required this.orderType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ToggleTab(
              label: 'Dine in',
              selected: orderType == OrderType.dineIn,
              onTap: () => onChanged(OrderType.dineIn),
            ),
          ),
          Expanded(
            child: _ToggleTab(
              label: 'Takeaway',
              selected: orderType == OrderType.takeaway,
              onTap: () => onChanged(OrderType.takeaway),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B5FE0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final bool isEditingNote;
  final TextEditingController noteController;
  final VoidCallback onToggleNote;
  final ValueChanged<String> onSaveNote;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.item,
    required this.isEditingNote,
    required this.noteController,
    required this.onToggleNote,
    required this.onSaveNote,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: item.photoPath.isNotEmpty
                    ? Image.network(
                        item.photoPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF4F5F9),
                          child: Icon(
                            Icons.fastfood_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFF4F5F9),
                        child: Icon(
                          Icons.fastfood_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFF1F2430),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.formattedLineTotal,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: Color(0xFF3B5FE0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      if (isEditingNote) {
                        onSaveNote(noteController.text);
                      } else {
                        onToggleNote();
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1.5),
                          child: Icon(
                            isEditingNote
                                ? Icons.check_circle
                                : (item.note.isNotEmpty
                                      ? Icons.check_circle
                                      : Icons.copy_outlined),
                            size: 13,
                            color: !isEditingNote && item.note.isNotEmpty
                                ? Colors.green
                                : const Color(0xFF3B5FE0),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isEditingNote
                                ? 'Save'
                                : (item.note.isNotEmpty
                                      ? item.note
                                      : 'Add Note'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: TextStyle(
                              color: !isEditingNote && item.note.isNotEmpty
                                  ? Colors.green.shade700
                                  : const Color(0xFF3B5FE0),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MiniQuantityStepper(
              quantity: item.quantity,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
              onRemove: onRemove,
            ),
          ],
        ),
        if (isEditingNote) ...[
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Value',
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
                  color: Color(0xFF3B5FE0),
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: onSaveNote,
          ),
        ],
      ],
    );
  }
}

/// Compact "- qty +" stepper for the order summary sidebar, with a small
/// trash icon underneath to remove the item entirely (with confirmation).
class _MiniQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _MiniQuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniStepperButton(
                icon: Icons.remove,
                onTap: onDecrement,
                color: const Color(0xFF3B5FE0),
              ),
              SizedBox(
                width: 22,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF1F2430),
                  ),
                ),
              ),
              _MiniStepperButton(
                icon: Icons.add,
                onTap: onIncrement,
                color: const Color(0xFF3B5FE0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.delete_outline,
              size: 16,
              color: Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _MiniStepperButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

/// Polished confirmation dialog shown before removing a product from the
/// order — rounded card, warning icon, and a two-button footer.
class _DeleteProductDialog extends StatelessWidget {
  final String productName;

  const _DeleteProductDialog({required this.productName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade400,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hapus produk?',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2430),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hapus "$productName" dari pesanan?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade500,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

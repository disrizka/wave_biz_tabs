import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
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

  const _CartItemRow({
    required this.item,
    required this.isEditingNote,
    required this.noteController,
    required this.onToggleNote,
    required this.onSaveNote,
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
                    '${item.quantity} x ${item.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFF1F2430),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      if (isEditingNote) {
                        onSaveNote(noteController.text);
                      } else {
                        onToggleNote();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
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
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isEditingNote
                                ? 'Save'
                                : (item.note.isNotEmpty
                                      ? item.note
                                      : 'Add Note'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: !isEditingNote && item.note.isNotEmpty
                                  ? Colors.green.shade700
                                  : const Color(0xFF3B5FE0),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.formattedLineTotal,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1F2430),
              ),
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

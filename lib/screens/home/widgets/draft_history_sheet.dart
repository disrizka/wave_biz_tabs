import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/core/snackbar_utils.dart';
import 'package:wave_biz_tabs/models/cart_model.dart';
import 'package:wave_biz_tabs/models/draft_order_model.dart';
import 'package:wave_biz_tabs/providers/card_provider.dart';
import 'package:wave_biz_tabs/providers/draft_provider.dart';

const _kAccent = Color(0xFF008080);

Future<void> showDraftHistorySheet(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (_) => const _DraftHistoryDialog(),
  );
}

class _DraftHistoryDialog extends ConsumerWidget {
  const _DraftHistoryDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Draft Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2430),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              drafts.isEmpty
                  ? 'Belum ada pesanan yang disimpan'
                  : '${drafts.length} pesanan tersimpan',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: drafts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Draft yang kamu simpan akan\nmuncul di sini',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: drafts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final draft = drafts[index];
                        return _DraftCard(
                          draft: draft,
                          onResume: () => _resumeDraft(context, ref, draft),
                          onDelete: () =>
                              _confirmDeleteDraft(context, ref, draft),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resumeDraft(
    BuildContext context,
    WidgetRef ref,
    DraftOrder draft,
  ) async {
    final cart = ref.read(cartProvider);
    if (!cart.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _ReplaceOrderDialog(),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    ref
        .read(cartProvider.notifier)
        .restore(items: draft.items, orderType: draft.orderType);
    await ref.read(draftProvider.notifier).removeDraft(draft.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    showCartSnackBar(
      context,
      message: 'Draft dimuat kembali ke pesanan',
      icon: Icons.history_rounded,
      color: _kAccent,
    );
  }

  Future<void> _confirmDeleteDraft(
    BuildContext context,
    WidgetRef ref,
    DraftOrder draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteDraftDialog(),
    );
    if (confirmed == true) {
      await ref.read(draftProvider.notifier).removeDraft(draft.id);
      if (!context.mounted) return;
      showCartSnackBar(
        context,
        message: 'Draft dihapus',
        icon: Icons.delete_outline_rounded,
        color: Colors.redAccent,
      );
    }
  }
}

class _DraftCard extends StatelessWidget {
  final DraftOrder draft;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onResume,
    required this.onDelete,
  });

  String get _itemsPreview {
    final names = draft.items.map((e) => '${e.quantity}x ${e.name}').toList();
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onResume,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        draft.orderType == OrderType.takeaway
                            ? Icons.shopping_bag_outlined
                            : Icons.restaurant_outlined,
                        size: 11,
                        color: _kAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        draft.orderType == OrderType.takeaway
                            ? 'Takeaway'
                            : 'Dine in',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _kAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(draft.savedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _itemsPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2430),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${draft.totalQuantity} item',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 8),
                Text(
                  draft.formattedTotal,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2430),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 17,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onResume,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Muat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kAccent,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: _kAccent,
                        ),
                      ],
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

class _ReplaceOrderDialog extends StatelessWidget {
  const _ReplaceOrderDialog();

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
                color: const Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: _kAccent,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ganti pesanan berjalan?',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2430),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan yang sedang berjalan belum disimpan. '
              'Memuat draft ini akan menggantikannya.',
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
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Muat Draft',
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

class _DeleteDraftDialog extends StatelessWidget {
  const _DeleteDraftDialog();

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
              'Hapus draft?',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2430),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Draft pesanan ini akan dihapus permanen dari riwayat.',
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

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${dt.day}/${dt.month}/${dt.year}';
}

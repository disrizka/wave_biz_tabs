import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wave_biz_tabs/models/product_model.dart';
import 'package:wave_biz_tabs/models/transaction_model.dart';
import 'package:wave_biz_tabs/providers/product_provider.dart';
import 'package:wave_biz_tabs/providers/transaction_provider.dart';

const _kAccent = Color(0xFF008080);
const _kAccentDark = Color(0xFF00655F);
const _kBg = Color(0xFFF6F7FB);
const _kInk = Color(0xFF1F2430);

class TransactionDetailScreen extends ConsumerWidget {
  final String idTransaction;

  const TransactionDetailScreen({super.key, required this.idTransaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(transactionDetailProvider(idTransaction));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Detail Transaksi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kAccent)),
        error: (err, _) => _ErrorView(
          message: '$err',
          onRetry: () =>
              ref.invalidate(transactionDetailProvider(idTransaction)),
        ),
        data: (detail) => RefreshIndicator(
          color: _kAccent,
          onRefresh: () async =>
              ref.invalidate(transactionDetailProvider(idTransaction)),
          child: _DetailBody(detail: detail),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 30,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final TransactionDetailResponse detail;

  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final t = detail.transaction;
    final paymentStatus = detail.paymentStatus;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _HeroCard(transaction: t),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Customer',
          icon: Icons.person_outline_rounded,
          child: _CustomerContent(transaction: t),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Item (${t.totalItemQty})',
          icon: Icons.shopping_bag_outlined,
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
          child: _ItemsContent(transaction: t),
        ),
        const SizedBox(height: 14),
        _TotalCard(transaction: t),
        if (paymentStatus != null) ...[
          const SizedBox(height: 14),
          _PaymentStatusCard(status: paymentStatus, message: detail.message),
        ],
      ],
    );
  }
}

/// Kartu ringkasan besar di paling atas: nomor order, status, tanggal, toko.
class _HeroCard extends StatelessWidget {
  final TransactionModel transaction;
  const _HeroCard({required this.transaction});

  void _copyOrderNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: transaction.number));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nomor pesanan disalin'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTakeaway = transaction.orderType == TransactionOrderType.takeaway;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.number.isNotEmpty
                          ? transaction.number
                          : transaction.reference,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _copyOrderNumber(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            transaction.reference,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: transaction.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroChip(
                icon: isTakeaway
                    ? Icons.shopping_bag_outlined
                    : Icons.restaurant_outlined,
                label: transaction.orderTypeLabel,
              ),
              const SizedBox(width: 8),
              _HeroChip(
                icon: Icons.schedule_rounded,
                label: transaction.formattedDate,
              ),
            ],
          ),
          if (transaction.storeLocationName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: Colors.white.withOpacity(0.85),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    transaction.storeLocationName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.18)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Pembayaran',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              Text(
                transaction.formattedAmount,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 13,
            color: isPaid ? _kAccent : Colors.orange.shade700,
          ),
          const SizedBox(width: 5),
          Text(
            status.isEmpty ? '-' : status,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isPaid ? _kAccent : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bungkus kartu putih rounded seragam untuk tiap section (Customer, Item, dll).
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final EdgeInsets padding;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _kAccent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _CustomerContent extends StatelessWidget {
  final TransactionModel transaction;
  const _CustomerContent({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final c = transaction.customer;
    final hasCustomer =
        c.name.isNotEmpty || c.phone.isNotEmpty || c.email.isNotEmpty;

    if (!hasCustomer) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'Tidak ada data customer',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
        ),
      );
    }

    final initials = c.name.trim().isNotEmpty
        ? c.name.trim()[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _kAccent.withOpacity(0.12),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.name.isNotEmpty)
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                const SizedBox(height: 4),
                if (c.phone.isNotEmpty)
                  _MutedRow(icon: Icons.phone_outlined, text: c.phone),
                if (c.email.isNotEmpty)
                  _MutedRow(icon: Icons.mail_outline_rounded, text: c.email),
                if (c.address.isNotEmpty)
                  _MutedRow(
                    icon: Icons.location_on_outlined,
                    text: [
                      c.address,
                      if (c.cityName.isNotEmpty) c.cityName,
                    ].join(', '),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MutedRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsContent extends ConsumerWidget {
  final TransactionModel transaction;
  const _ItemsContent({required this.transaction});

  /// Cari produk asli dari katalog yang sudah ke-load, dicocokkan lewat UUID
  /// produk dulu (paling unik), lalu idProduct numerik, dan TERAKHIR lewat
  /// SKU (product_sku_id) — soalnya ID produk yang dibalikin endpoint
  /// transaksi kadang beda skema sama endpoint katalog produk, sementara
  /// SKU yang dipakai pas checkout ([SaleItem.productSkuId]) hampir selalu
  /// match sama salah satu SKU produknya. Endpoint payment-check sendiri
  /// tidak mengirim nama produk, jadi ini satu-satunya cara nampilin nama
  /// asli tanpa nge-hardcode apa pun.
  ProductModel? _matchProduct(
    Iterable<ProductModel> catalog,
    TransactionItemModel item,
  ) {
    if (item.productUuid.isNotEmpty) {
      for (final p in catalog) {
        if (p.uuid == item.productUuid) return p;
      }
    }
    final idStr = item.productId.toString();
    for (final p in catalog) {
      if (p.idProduct.isNotEmpty && p.idProduct == idStr) return p;
    }
    if (item.hasSku) {
      for (final p in catalog) {
        for (final s in p.skus) {
          if (s.uuid == item.skuId || s.idProductSku == item.skuId) return p;
        }
      }
    }
    return null;
  }

  ProductSku? _matchSku(ProductModel? product, TransactionItemModel item) {
    if (product == null || item.skuId.isEmpty) return null;
    for (final s in product.skus) {
      if (s.uuid == item.skuId || s.idProductSku == item.skuId) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transaction.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          'Tidak ada item',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
        ),
      );
    }

    // Katalog yang lagi ke-reveal di layar POS/produk (cepat, tapi cuma
    // sebagian kalau produknya banyak / lagi difilter kategori tertentu).
    final revealedCatalog = ref
        .watch(productHomeProvider)
        .productsByCategoryName
        .values
        .expand((e) => e);

    // Fallback: index SEMUA produk + SKU-nya (semua halaman), dipakai kalau
    // produk item ini tidak ketemu di katalog yang lagi ke-reveal, supaya
    // nama asli tetap muncul sesuai API alih-alih "Produk #<id>".
    final fullLookupAsync = ref.watch(productLookupProvider);
    final fullLookup = fullLookupAsync.asData?.value ?? const {};

    return Column(
      children: [
        for (int i = 0; i < transaction.items.length; i++) ...[
          Builder(
            builder: (_) {
              final item = transaction.items[i];
              var product = _matchProduct(revealedCatalog, item);
              product ??=
                  fullLookup[item.productUuid] ??
                  fullLookup[item.productId.toString()] ??
                  fullLookup[item.skuId];
              if (product == null) {
                debugPrint(
                  '[TransactionDetail] Produk TIDAK ketemu untuk item -> '
                  'ProductID=${item.productId}, '
                  'product_id(uuid)="${item.productUuid}", '
                  'product_sku_id="${item.skuId}". '
                  'revealedCatalog.length=${revealedCatalog.length}, '
                  'fullLookup.length=${fullLookup.length}',
                );
              }
              final sku = _matchSku(product, item);
              return _ItemRow(item: item, product: product, sku: sku);
            },
          ),
          if (i != transaction.items.length - 1)
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: Colors.grey.shade100,
            ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final TransactionItemModel item;
  final ProductModel? product;
  final ProductSku? sku;

  const _ItemRow({required this.item, this.product, this.sku});

  @override
  Widget build(BuildContext context) {
    // Endpoint payment-check tidak mengirim nama produk sendiri (cuma
    // ProductID & product_sku_id), jadi nama diambil dari katalog produk
    // yang sudah ke-load (lihat _ItemsContent._matchProduct). Kalau produknya
    // tidak ketemu di katalog (mis. belum ke-load / sudah dihapus), fallback
    // ke "Produk #<id>" + SKU dipendekin, bukan hash mentah sebagai judul.
    final matched = product != null;
    final shortSku = item.hasSku && item.skuId.length > 10
        ? '${item.skuId.substring(0, 10)}…'
        : item.skuId;
    final title = matched ? product!.name : 'Produk #${item.productId}';

    final subtitleParts = <String>[
      if (matched && sku != null && sku!.label.isNotEmpty) sku!.label,
      '${item.quantity} x ${TransactionModel.formatRupiah(item.price)}',
      if (!matched && item.hasSku) 'SKU $shortSku',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemThumbnail(photoPath: matched ? product!.photoPath : ''),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join('  •  '),
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            TransactionModel.formatRupiah(item.lineTotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemThumbnail extends StatelessWidget {
  final String photoPath;
  const _ItemThumbnail({required this.photoPath});

  @override
  Widget build(BuildContext context) {
    final hasImage = photoPath.startsWith('http');

    if (!hasImage) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _kAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          size: 17,
          color: _kAccent,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        photoPath,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 17,
            color: _kAccent,
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final TransactionModel transaction;
  const _TotalCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', value: transaction.formattedAmount),
          if (transaction.discount > 0)
            _TotalRow(
              label: 'Diskon',
              value: '-${TransactionModel.formatRupiah(transaction.discount)}',
              valueColor: Colors.red.shade400,
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                Text(
                  transaction.formattedAmount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kAccentDark,
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

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TotalRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu status pengecekan pembayaran. Kode "200" ditandai hijau/sukses;
/// kode lain (mis. "404" untuk order tunai yang memang tidak tercatat di
/// gateway online) ditandai netral abu-abu, bukan merah — karena itu bukan
/// error pada transaksinya, cuma info bahwa tidak ada record di payment
/// gateway.
class _PaymentStatusCard extends StatelessWidget {
  final PaymentStatusModel status;
  final String message;

  const _PaymentStatusCard({required this.status, required this.message});

  @override
  Widget build(BuildContext context) {
    final isSuccessCode = status.statusCode == '200';
    final color = isSuccessCode ? _kAccent : Colors.grey.shade600;
    final bg = isSuccessCode
        ? _kAccent.withOpacity(0.08)
        : Colors.grey.shade100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: _kAccent),
              const SizedBox(width: 8),
              const Text(
                'Status Pembayaran',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSuccessCode
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status.statusMessage.isNotEmpty)
                        Text(
                          status.statusMessage,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      if (status.statusCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Kode: ${status.statusCode}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
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

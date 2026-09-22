import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/core/snackbar_utils.dart';
import 'package:wave_biz_tabs/models/product_model.dart';
import 'package:wave_biz_tabs/providers/card_provider.dart';
import 'package:wave_biz_tabs/screens/home/widgets/product_card.dart';
import 'package:wave_biz_tabs/screens/home/widgets/variant_picker_sheet.dart';

class CartConnectedProductCard extends ConsumerWidget {
  final ProductModel product;

  const CartConnectedProductCard({super.key, required this.product});

  String get _id =>
      product.idProduct.isNotEmpty ? product.idProduct : product.uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final qty = cart.quantityOf(_id);

    return ProductCard(
      product: product,
      quantity: qty,
      onAdd: () async {
        if (product.hasVariants) {
          final picked = await showVariantPickerSheet(context, product);
          if (picked == null) return;
          cartNotifier.addProduct(
            product,
            sku: picked.sku,
            quantity: picked.quantity,
            note: picked.note,
          );
          if (!context.mounted) return;
          showCartSnackBar(
            context,
            message: '${product.name} (${picked.sku.label}) ditambahkan',
            icon: Icons.add_shopping_cart_rounded,
            color: Colors.green,
          );
          return;
        }
        cartNotifier.addProduct(product);
        showCartSnackBar(
          context,
          message: '${product.name} ditambahkan',
          icon: Icons.add_shopping_cart_rounded,
          color: Colors.green,
        );
      },
      onIncrement: () {
        cartNotifier.increment(_id);
        showCartSnackBar(
          context,
          message: '${product.name} ditambah (${qty + 1})',
          icon: Icons.add_circle_rounded,
          color: Colors.green,
        );
      },
      onDecrement: () {
        cartNotifier.decrement(_id);
        final remaining = qty - 1;
        if (remaining <= 0) {
          showCartSnackBar(
            context,
            message: '${product.name} dihapus dari pesanan',
            icon: Icons.delete_outline_rounded,
            color: Colors.redAccent,
          );
        } else {
          showCartSnackBar(
            context,
            message: '${product.name} dikurangi ($remaining)',
            icon: Icons.remove_circle_rounded,
            color: Colors.orange,
          );
        }
      },
      onRemove: () {
        final removedQty = qty;
        cartNotifier.removeItem(_id);
        showCartSnackBar(
          context,
          message: '${product.name} dihapus dari pesanan (${removedQty}x)',
          icon: Icons.delete_outline_rounded,
          color: Colors.redAccent,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onAdd;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onRemove;

  const ProductCard({
    super.key,
    required this.product,
    this.onAdd,
    this.quantity = 0,
    this.onIncrement,
    this.onDecrement,
    this.onRemove,
  });

  bool get _showStepper => quantity > 0 && !product.hasVariants;

  Widget _buildProductImage() {
    if (product.photoPath.isNotEmpty) {
      return Image.network(
        product.photoPath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFFF4F5F9),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            '[ProductCard] Gagal memuat gambar: ${product.photoPath} | Error: $error',
          );
          return Container(
            color: Colors.grey.shade100,
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade400,
              size: 36,
            ),
          );
        },
      );
    }

    return Container(
      color: const Color(0xFFF4F5F9),
      child: Icon(
        Icons.fastfood_outlined,
        color: Colors.grey.shade400,
        size: 36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flexible on purpose: the grid cell's height is set by the grid
          // delegate and can vary slightly by breakpoint/font scale. Letting
          // the image fill whatever space is left (instead of a fixed
          // AspectRatio) means the fixed text+button section below can
          // never get pushed past the bottom of the cell (which caused a
          // RenderFlex overflow before), and any extra room just makes the
          // image a bit taller instead of leaving a dead gap under the
          // button.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildProductImage()),
                if (product.isOutOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Out Of Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1F2430),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.isOutOfStock ? '-' : product.priceLabel,
                  style: const TextStyle(
                    color: Color(0xFF008080),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: _showStepper
                      ? _QuantityStepper(
                          quantity: quantity,
                          onIncrement: onIncrement,
                          onDecrement: onDecrement,
                          onRemove: onRemove,
                        )
                      : ElevatedButton.icon(
                          onPressed: product.isOutOfStock ? null : onAdd,
                          icon: Icon(
                            product.hasVariants
                                ? Icons.tune_rounded
                                : Icons.add_shopping_cart,
                            size: 15,
                          ),
                          label: Text(
                            product.hasVariants && quantity > 0
                                ? 'Add Product ($quantity)'
                                : 'Add Product',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008080),
                            disabledBackgroundColor: Colors.grey.shade200,
                            disabledForegroundColor: Colors.grey.shade500,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
  final VoidCallback? onRemove;

  const _QuantityStepper({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: onDecrement,
            color: const Color(0xFF008080),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Color(0xFF1F2430),
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: onIncrement,
            color: const Color(0xFF008080),
          ),
          Container(width: 1, height: 20, color: const Color(0xFFB2DFDB)),
          _StepperButton(
            icon: Icons.delete_outline,
            onTap: onRemove,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _StepperButton({
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
        width: 32,
        height: 32,
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

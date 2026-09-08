import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onAdd;

  const ProductCard({super.key, required this.product, this.onAdd});

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
          Stack(
            children: [
              AspectRatio(aspectRatio: 1.3, child: _buildProductImage()),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Color(0xFF1F2430),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.isOutOfStock ? '-' : product.formattedPrice,
                  style: const TextStyle(
                    color: Color(0xFF3B5FE0),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: product.isOutOfStock ? null : onAdd,
                    icon: const Icon(Icons.add_shopping_cart, size: 15),
                    label: const Text(
                      'Add Product',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B5FE0),
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

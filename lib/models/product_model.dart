library;

class ProductPriceTier {
  final int minQty;
  final int price;

  ProductPriceTier({required this.minQty, required this.price});

  factory ProductPriceTier.fromJson(Map<String, dynamic> json) {
    return ProductPriceTier(
      minQty: (json['minQty'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProductImage {
  final String image;
  final String imagePath;

  ProductImage({required this.image, required this.imagePath});

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      image: json['image'] ?? '',
      imagePath: json['imagePath'] ?? '',
    );
  }
}

class ProductModel {
  final String idProduct;
  final String uuid;
  final String name;
  final List<ProductPriceTier> prices;
  final List<ProductImage> images;
  final String? categoryName;

  ProductModel({
    required this.idProduct,
    required this.uuid,
    required this.name,
    this.prices = const [],
    this.images = const [],
    this.categoryName,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['productCategory'] as Map<String, dynamic>?;
    return ProductModel(
      idProduct: json['idProduct']?.toString() ?? '',
      uuid: json['uuid']?.toString() ?? '',
      name: json['name'] ?? '',
      prices: (json['prices'] as List? ?? [])
          .map((e) => ProductPriceTier.fromJson(e))
          .toList(),
      images: (json['images'] as List? ?? [])
          .map((e) => ProductImage.fromJson(e))
          .toList(),
      categoryName: category?['name']?.toString(),
    );
  }

  int get basePrice {
    if (prices.isEmpty) return 0;
    final exact = prices.where((p) => p.minQty == 1);
    if (exact.isNotEmpty) return exact.first.price;
    final sorted = [...prices]..sort((a, b) => a.minQty.compareTo(b.minQty));
    return sorted.first.price;
  }

  bool get hasWholesalePrice => prices.length > 1;
  String get photoPath => images.isNotEmpty ? images.first.imagePath : '';
  bool get isOutOfStock => false;

  String get formattedPrice {
    final s = basePrice.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return 'Rp. $buffer';
  }
}

class ProductCategoryModel {
  final String idProductCategory;
  final String name;

  ProductCategoryModel({required this.idProductCategory, required this.name});

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) {
    return ProductCategoryModel(
      idProductCategory: json['idProductCategory']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }
}

class ProductPageMeta {
  final int currentPage;
  final int rowPerPage;
  final int totalPages;
  final int totalRows;

  ProductPageMeta({
    required this.currentPage,
    required this.rowPerPage,
    required this.totalPages,
    required this.totalRows,
  });

  factory ProductPageMeta.fromJson(Map<String, dynamic> json) {
    return ProductPageMeta(
      currentPage: json['current_page'] ?? 1,
      rowPerPage: json['row_per_page'] ?? 200,
      totalPages: json['total_pages'] ?? 1,
      totalRows: json['total_rows'] ?? 0,
    );
  }

  bool get hasMorePages => currentPage < totalPages;
}

class ProductPosResponse {
  final bool allProducts;
  final List<ProductCategoryModel> categories;
  final Map<String, List<ProductModel>> productsByCategoryName;
  final ProductPageMeta page;

  ProductPosResponse({
    required this.allProducts,
    required this.categories,
    required this.productsByCategoryName,
    required this.page,
  });

  List<ProductModel> get flatProducts =>
      productsByCategoryName.values.expand((e) => e).toList();

  factory ProductPosResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final categories = (data['categories'] as List? ?? [])
        .map((e) => ProductCategoryModel.fromJson(e))
        .toList();

    final Map<String, List<ProductModel>> grouped = {};
    for (final group in (data['products'] as List? ?? [])) {
      final categoryName = group['categoryName'] ?? '';
      final items = (group['products'] as List? ?? [])
          .map((e) => ProductModel.fromJson(e))
          .toList();
      grouped[categoryName] = items;
    }

    return ProductPosResponse(
      allProducts: data['allProducts'] ?? false,
      categories: categories,
      productsByCategoryName: grouped,
      page: ProductPageMeta.fromJson(
        json['page'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Response shape for GET /waveup/{businessId}/product (flat list endpoint).
/// Unlike /product/pos, this endpoint reliably respects `id_category`.
class ProductFlatResponse {
  final List<ProductModel> products;
  final ProductPageMeta page;

  ProductFlatResponse({required this.products, required this.page});

  factory ProductFlatResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ProductFlatResponse(
      products: items,
      page: ProductPageMeta.fromJson(
        json['page'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

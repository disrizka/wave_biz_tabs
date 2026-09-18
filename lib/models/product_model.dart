library;

/// A single attribute/value pair on a SKU, e.g. {name: "Size", value: "Large"}.
class ProductSkuAttribute {
  final String name;
  final String value;

  ProductSkuAttribute({required this.name, required this.value});

  factory ProductSkuAttribute.fromJson(Map<String, dynamic> json) {
    return ProductSkuAttribute(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

/// A purchasable variant of a product (e.g. Topping: Chicken / Size: Small),
/// as returned inside `productSkus` by GET /waveup/{businessId}/product.
class ProductSku {
  final String uuid;
  final String idProductSku;
  final String code;
  final int price;
  final int qty;
  final List<ProductSkuAttribute> attributes;

  ProductSku({
    required this.uuid,
    required this.idProductSku,
    required this.code,
    required this.price,
    required this.qty,
    this.attributes = const [],
  });

  /// "Chicken, Small" — used as the cart line's variant label.
  String get label => attributes.map((a) => a.value).join(', ');

  factory ProductSku.fromJson(Map<String, dynamic> json) {
    // attributesV2 is the newer/corrected shape; fall back to attributes
    // when it's absent or empty.
    final v2 = (json['attributesV2'] as List?) ?? const [];
    final v1 = (json['attributes'] as List?) ?? const [];
    final raw = v2.isNotEmpty ? v2 : v1;

    return ProductSku(
      uuid: json['uuid']?.toString() ?? '',
      idProductSku: json['idProductSku']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      attributes: raw
          .whereType<Map>()
          .map((e) => ProductSkuAttribute.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

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
  final String code;
  final String name;
  final List<ProductPriceTier> prices;
  final List<ProductImage> images;
  final List<ProductSku> skus;
  final String? categoryName;

  ProductModel({
    required this.idProduct,
    required this.uuid,
    this.code = '',
    required this.name,
    this.prices = const [],
    this.images = const [],
    this.skus = const [],
    this.categoryName,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['productCategory'] as Map<String, dynamic>?;
    // Some endpoints (e.g. GET /waveup/{businessId}/product) use
    // `productImages` instead of `images`.
    final imagesRaw =
        (json['images'] as List?) ?? (json['productImages'] as List?) ?? [];

    return ProductModel(
      idProduct: json['idProduct']?.toString() ?? '',
      uuid: json['uuid']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
      prices: (json['prices'] as List? ?? [])
          .map((e) => ProductPriceTier.fromJson(e))
          .toList(),
      images: imagesRaw.map((e) => ProductImage.fromJson(e)).toList(),
      skus: (json['productSkus'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ProductSku.fromJson(e.cast<String, dynamic>()))
          .toList(),
      categoryName: category?['name']?.toString(),
    );
  }

  /// True when this product is sold through SKU variants (e.g. Topping,
  /// Size) rather than a single flat price — the person must pick one SKU
  /// combination before it can be added to the cart.
  bool get hasVariants => skus.any((s) => s.attributes.isNotEmpty);

  /// Every distinct attribute group and its possible values, in the order
  /// they first appear (e.g. {"Topping": ["Chicken", "Beef"], "Size": [...]})
  Map<String, List<String>> get variantGroups {
    final Map<String, List<String>> groups = {};
    for (final sku in skus) {
      for (final attr in sku.attributes) {
        final values = groups.putIfAbsent(attr.name, () => []);
        if (!values.contains(attr.value)) values.add(attr.value);
      }
    }
    return groups;
  }

  /// Finds the SKU whose attributes exactly match [selection]
  /// (attribute name -> selected value).
  ProductSku? skuForSelection(Map<String, String> selection) {
    for (final sku in skus) {
      final attrMap = {for (final a in sku.attributes) a.name: a.value};
      if (attrMap.length == selection.length &&
          selection.entries.every((e) => attrMap[e.key] == e.value)) {
        return sku;
      }
    }
    return null;
  }

  List<int> get _variantPrices =>
      skus.where((s) => s.attributes.isNotEmpty).map((s) => s.price).toList();

  int get minVariantPrice => _variantPrices.isEmpty
      ? 0
      : _variantPrices.reduce((a, b) => a < b ? a : b);
  int get maxVariantPrice => _variantPrices.isEmpty
      ? 0
      : _variantPrices.reduce((a, b) => a > b ? a : b);

  int get basePrice {
    if (hasVariants) return minVariantPrice;
    if (prices.isEmpty) return 0;
    final exact = prices.where((p) => p.minQty == 1);
    if (exact.isNotEmpty) return exact.first.price;
    final sorted = [...prices]..sort((a, b) => a.minQty.compareTo(b.minQty));
    return sorted.first.price;
  }

  bool get hasWholesalePrice => prices.length > 1;
  String get photoPath => images.isNotEmpty ? images.first.imagePath : '';
  bool get isOutOfStock => false;

  static String _formatRupiah(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }

  String get formattedPrice => 'Rp. ${_formatRupiah(basePrice)}';

  /// What to show on the product card/list: a plain price for simple
  /// products, or "Mulai Rp. X" (starting from) when variants have
  /// different prices.
  String get priceLabel {
    if (hasVariants && minVariantPrice != maxVariantPrice) {
      return 'Mulai Rp. ${_formatRupiah(minVariantPrice)}';
    }
    return formattedPrice;
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

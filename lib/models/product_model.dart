/// Model-model ini disesuaikan dengan response ASLI endpoint
/// `GET {baseUrl}/waveup/{idBusiness}/product/pos?category=&brand=`
/// (dikonfirmasi dari contoh response Postman kamu, 27/08 & 28/08).
library;

/// Satu tingkat harga (grosir). Produk bisa punya beberapa tingkat
/// berdasarkan `minQty`, misal beli >=5 harganya lebih murah.
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

  ProductModel({
    required this.idProduct,
    required this.uuid,
    required this.name,
    this.prices = const [],
    this.images = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
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
    );
  }

  /// Harga dasar (minQty 1). Kalau tidak ada tier minQty==1, pakai yang
  /// paling murah / minQty terkecil sebagai fallback.
  int get basePrice {
    if (prices.isEmpty) return 0;
    final exact = prices.where((p) => p.minQty == 1);
    if (exact.isNotEmpty) return exact.first.price;
    final sorted = [...prices]..sort((a, b) => a.minQty.compareTo(b.minQty));
    return sorted.first.price;
  }

  bool get hasWholesalePrice => prices.length > 1;

  String get photoPath => images.isNotEmpty ? images.first.imagePath : '';

  /// CATATAN: response API ini belum ada field status stok
  /// (misal `isOutOfStock`). Kalau backend nanti nambahin field itu,
  /// tinggal tambah di sini + di UI (`ProductCard`) baca dari sini lagi.
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

/// Kategori produk. Response asli cuma kasih id & nama (tanpa jumlah
/// produk per kategori), jadi tidak ada badge "total produk" per chip.
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

/// Info pagination dari object `page` di response.
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

/// Hasil satu kali fetch endpoint `product/pos`.
///
/// - `allProducts == true`  -> business ini <= 200 produk. `categories` dan
///   `products` SUDAH LENGKAP semuanya dalam satu response ini (tidak perlu
///   fetch lagi per kategori).
/// - `allProducts == false` -> business ini > 200 produk. `categories`
///   tetap lengkap (buat chip), tapi `products` cuma isi kategori yang
///   sedang diminta lewat query `category=` (kalau query kosong, backend
///   balikin preview kategori pertama secara default).
class ProductPosResponse {
  final bool allProducts;
  final List<ProductCategoryModel> categories;

  /// Produk dikelompokkan per kategori sesuai urutan dari backend.
  final Map<String, List<ProductModel>> productsByCategoryName;
  final ProductPageMeta page;

  ProductPosResponse({
    required this.allProducts,
    required this.categories,
    required this.productsByCategoryName,
    required this.page,
  });

  /// Semua produk digabung jadi satu list flat (dipakai buat tab
  /// "All Product" saat `allProducts == true`, atau buat search lokal).
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

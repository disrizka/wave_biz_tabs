import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/product_model.dart';
import 'api_service.dart';

/// Service buat endpoint "[POS] Product List" yang sudah dikonfirmasi:
///
/// `GET {baseUrl}/waveup/{idBusiness}/product/pos?category=&brand=`
///
/// Perilaku (dari contoh response asli):
/// - `category` kosong  -> backend balikin SEMUA kategori (buat chip),
///   dan:
///     - kalau `allProducts: true`  -> `products` juga udah lengkap semua
///       kategori (business ini <= 200 produk, sekali fetch selesai).
///     - kalau `allProducts: false` -> `products` cuma preview 1 kategori
///       default (business > 200 produk, harus pilih kategori manual).
/// - `category=<idProductCategory>` -> `products` isi kategori itu aja.
///
/// ASUMSI yang BELUM dikonfirmasi (tolong cek kalau ada isu):
/// - Param `page` buat lanjut ke halaman berikutnya kalau satu kategori
///   sendiri isinya > `row_per_page` (200). Jarang kejadian karena
///   kategori di data kamu granular banget, tapi tetap di-handle di sini.
/// - Header Authorization pakai `Bearer <access_token>` (pola umum JWT,
///   samain kayak endpoint lain kalau ternyata beda).
class ProductService {
  Future<ProductPosResponse> getProducts({
    required String accessToken,
    required String businessId,
    String? categoryId,
    String? brand,
    int page = 1,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConstants.baseUrl}/waveup/$businessId/product/pos',
        ).replace(
          queryParameters: {
            'category': categoryId ?? '',
            'brand': brand ?? '',
            if (page > 1) 'page': '$page',
          },
        );

    http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
    } catch (e) {
      // Sama seperti login: request gagal di level NETWORK (biasanya CORS
      // kalau lagi run di Chrome/web). Selama enableMockLoginFallback aktif,
      // lanjut pakai data dummy biar UI tetap bisa didemo di browser sambil
      // CORS-nya diurus di sisi backend. Di HP/tab asli (native, tidak kena
      // CORS) baris ini tidak akan pernah kepanggil - request asli sukses.
      if (AppConstants.enableMockLoginFallback) {
        return _mockResponse(businessId: businessId, categoryId: categoryId);
      }
      throw ApiNetworkException(
        'Gagal terhubung ke server saat ambil produk: $e',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Response server tidak valid (bukan JSON). Status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 || decoded['status'] != 200) {
      throw ApiException(
        decoded['message'] ?? 'Gagal mengambil daftar produk.',
        statusCode: response.statusCode,
      );
    }

    return ProductPosResponse.fromJson(decoded);
  }

  /// Data dummy buat testing UI di web/Chrome selama CORS ke wave-api.eon.id
  /// belum dibuka. Diambil dari 2 skenario ASLI (contoh response Postman
  /// kamu, 28/08) supaya kelihatan bedanya:
  /// - `46e96364...` "Burger Restaurant" -> allProducts:true (<=200 produk,
  ///   chip "All Product" ada, tidak perlu fetch ulang pas ganti kategori).
  /// - `f9e4ed4f9...` "Popular Stationery" -> allProducts:false (>200
  ///   kategori/produk, tidak ada chip "All Product", tiap kategori di-fetch
  ///   manual - hanya "Bk Diary" yang ada data produknya di mock ini,
  ///   kategori lain sengaja dibiarkan kosong karena backend asli juga
  ///   belum kasih contoh datanya).
  /// Business lain (id tidak dikenali) -> fallback ke katalog generik.
  /// Set `AppConstants.enableMockLoginFallback = false` untuk mematikan
  /// semua mock ini setelah CORS/network-nya kelar.
  ProductPosResponse _mockResponse({
    required String businessId,
    String? categoryId,
  }) {
    switch (businessId) {
      case '46e96364c42e6f3132525e75813ea514c8cded':
        return _burgerRestaurantMock();
      case 'f9e4ed4f9c121b3186c5690995bce54a91edce':
        return _popularStationeryMock(categoryId: categoryId);
      default:
        return _genericFoodMock();
    }
  }

  /// "Burger Restaurant" - persis dari contoh response asli (3 kategori,
  /// 4 produk, allProducts:true, foto beneran dari wave-cdn).
  ProductPosResponse _burgerRestaurantMock() {
    return ProductPosResponse.fromJson({
      'status': 200,
      'data': {
        'allProducts': true,
        'categories': [
          {
            'idProductCategory': '15fbe58ac9185423511be653c0166eae3930',
            'name': 'Main Course',
          },
          {
            'idProductCategory': '0a162c6bd12aa3d10eef467db1a1ad4a33de',
            'name': 'Snacks',
          },
          {
            'idProductCategory': '2e86b2fdf772649e2e6e057d51129ceef073',
            'name': 'Drinks',
          },
        ],
        'products': [
          {
            'categoryName': 'Main Course',
            'products': [
              {
                'idProduct': 'f0ac420e697f4d2a5285fa5c398db52a52764f',
                'uuid': '30a57a8a-bede-4332-b748-edfb70f12f80',
                'name': 'Burger Ayam Pedas',
                'prices': [
                  {'minQty': 1, 'price': 55000},
                  {'minQty': 5, 'price': 52800},
                ],
                'images': [
                  {
                    'image': '26/08/ClassicCheeseBurger_9-1787549212.jpg',
                    'imagePath':
                        'https://wave-cdn.eon.id/static/product/image/26/08/ClassicCheeseBurger_9-1787549212.jpg',
                  },
                ],
              },
              {
                'idProduct': 'af1470c394dbdf758ab70f495b265f46b38017',
                'uuid': 'e94b55c3-542b-47b7-918b-a51a40833006',
                'name': 'Cheese Burger',
                'prices': [
                  {'minQty': 1, 'price': 45000},
                  {'minQty': 5, 'price': 43000},
                ],
                'images': [
                  {
                    'image':
                        '26/08/juicy-double-cheeseburger-studio-shot-600w-2572134091-1787558983.webp',
                    'imagePath':
                        'https://wave-cdn.eon.id/static/product/image/26/08/juicy-double-cheeseburger-studio-shot-600w-2572134091-1787558983.webp',
                  },
                ],
              },
            ],
          },
          {
            'categoryName': 'Snacks',
            'products': [
              {
                'idProduct': '32ed2154176c789437f86a10dbe61122aa306f',
                'uuid': 'dd5d105b-3c57-4e07-bbf7-8d2dc432378a',
                'name': 'French Fries',
                'prices': [
                  {'minQty': 1, 'price': 37500},
                ],
                'images': [
                  {
                    'image':
                        '26/08/Copycat-McDonalds-French-Fries--1787559417.jpg',
                    'imagePath':
                        'https://wave-cdn.eon.id/static/product/image/26/08/Copycat-McDonalds-French-Fries--1787559417.jpg',
                  },
                ],
              },
            ],
          },
          {
            'categoryName': 'Drinks',
            'products': [
              {
                'idProduct': '120279ef35fb2bb67ef5750534b0aea0edf38f',
                'uuid': '2c1aa963-2adc-4d59-9857-97a102c11d31',
                'name': 'Ice Lemon Tea',
                'prices': [
                  {'minQty': 1, 'price': 14000},
                ],
                'images': [
                  {
                    'image': '26/08/images-2-1787559567.jpeg',
                    'imagePath':
                        'https://wave-cdn.eon.id/static/product/image/26/08/images-2-1787559567.jpeg',
                  },
                ],
              },
            ],
          },
        ],
      },
      'page': {
        'current_page': 1,
        'row_per_page': 200,
        'total_pages': 1,
        'total_rows': 4,
      },
    });
  }

  /// "Popular Stationery" - persis dari contoh response asli: >200 kategori
  /// (daftar lengkap dikirim biar chip-nya kerasa banyak beneran),
  /// allProducts:false. Backend cuma ngasih contoh produk untuk kategori
  /// default "Bk Diary" (tanpa harga/foto - sama persis kayak aslinya),
  /// kategori lain balikin list kosong kalau dipilih.
  ProductPosResponse _popularStationeryMock({String? categoryId}) {
    const categoryNames = [
      'Bk Diary',
      'Bk Notebook',
      'Bk Pramuka',
      'Bk Address',
      'Bk Campuran',
      'Bk Tabelaris',
      'Bk Kas',
      'Bk Nota',
      'Bk Blocknote',
      'Bk Gambar',
      'Bk Sketsa',
      'Bk Menulis',
      'Bk Polos',
      'Bk Octavo',
      'Bk Folio',
      'Bk Halus',
      'Bk Costum',
      'Bk Mewarnai',
      'Bk Klaper',
      'Bk Ekspedisi',
      'Bk Kwitansi',
      'Bk Kwarto',
      'Bk D/F',
      'Bk Kotak',
      'Bk Boxy',
      'Bk Nota NCR',
      'Bendera',
      'Bak Stample',
      'Benang',
      'Balon',
      'Batu',
      'Bola Pingpong',
      'Bola Bekel',
      'CD',
      'Crayon',
      'Cat',
      'Cap',
      'CF',
      'Cutter',
      'Cash Box',
      'Coin Box',
      'Isi Bolpoint',
      'Dus',
      'Dispenser',
      'Gunting Kuku',
      'Gantungan',
      'Guntacker',
      'Gestetner',
      'Gotri',
      'Hand Counter',
      'Isi Pensil',
      'Isi Cutter',
      'Isolasi',
      'Jas Hujan',
      'Jarum',
      'Jepit Comb Ring',
      'HVS',
      'K Cover',
      'K Photo',
      'K NCR',
      'K Roneo',
      'K Garis',
      'K Kado',
      'K Payung',
      'K Pilus',
      'K Asturo',
      'K Manila',
      'K Karton',
      'K Samson',
      'K Roti',
      'Kalkir',
      'K Krep',
      'K Mas',
      'K Lipat',
      'K Daun',
      'Kuas',
      'Klip',
      'Karbon',
      'Kompas',
      'Kamper',
      'Karet',
      'Lakban',
      'Kapur',
      'Kaca Pembesar',
      'Kelereng',
      'Kemoceng',
      'Kanebo',
      'Kain',
      'Kartu',
      'Keyboard',
      'Jangka',
      'Loose Leaf',
      'Lilin',
      'L Campur',
      'Masking',
      'Mika',
      'Map',
      'Mesin',
      'Magic Board',
      'Magnet',
      'Masker',
      'Name Tag',
      'Nomerator',
      'Name Card',
      'Name Plate',
      'Ordner',
      'Clip Board',
      'Pensil Warna',
      'Perforator',
      'Pines',
      'Pisau Cukur',
      'Pisau Potong',
      'Penghapus',
      'Pita Catr',
      'Pengharum',
      'Papan',
      'Plastik',
      'Palet',
      'Peluit',
      'Piringan',
      'Peniti',
      'Post It',
      'Pronto',
      'Pinset',
      'Paper Craft',
      'Pen Stand',
      'Rapido',
      'Rak Susun',
      'Remover',
      'Refill Catridge',
      'Rader',
      'Riso',
      'Room Decor',
      'Pita Campur',
      'Telstruk',
      'Telex',
      'Thermal',
      'Toner',
      'Sampul',
      'Sempoa',
      'Suling',
      'Sabut Cuci',
      'Sedotan',
      'Seal Tape',
      'Lain - Lain',
      'Silet',
      'Standar Buku',
      'Senter',
      'Sendok',
      'Tempat Pensil',
      'Tipp Ex',
      'Tas',
      'Topi',
      'Topeng',
      'Tissue',
      'Tusuk Gigi',
      'Tali',
      'Tempat Brosur',
      'Tempat CD',
      'Tiner',
      'T Campuran',
      'Zegelak',
      'Was',
      'Undangan',
      'K Marmer',
      'Label Harga',
      'Lemari',
      'Label Rol',
      'Mika Cover',
      'Mika Lami',
      'File Box',
      'Fax',
      'Acco',
      'File Case',
      'Filing Cabinet',
      'Meja',
      'SEMBAHYANGAN',
      'Meterai',
      'Kap Plastik',
      'Kap Mika',
      'Flash Disk',
      'Dupa',
      'Lampu',
      'spon',
      'keranjang',
      'Cock',
      'steroform',
      'hero',
      'lap',
      'mouse',
      'bekel',
      'Pianika',
      'Fulpen',
      'Ink Roller',
      'Pentil',
      'Book Organizer',
      'Cotton Buds',
      'Multi Organizer',
      'Tack It',
      'Cutting Mate',
      'Movitex',
      'Box',
      'Divider',
      'Fingerprint',
      'keset',
      'Remaja',
      'Meteran',
      'Sapu',
      'Kebersihan',
      'Fajar',
      'sipoa',
      'Harddisk',
      'Accessories',
      'Hadiah',
      'Stopwatch',
      'Kalender',
      'Test Kategori',
      'Celengan',
      'Kanvas',
      'Memo Stick',
      'correction',
      'HighLighter',
    ];

    final categories = categoryNames
        .map(
          (name) => {
            'idProductCategory': 'stat-${name.hashCode.toUnsigned(32)}',
            'name': name,
          },
        )
        .toList();

    // Backend asli cuma ngasih contoh produk buat "Bk Diary" (tanpa harga
    // & foto). Kategori lain: kalau dipilih, balikin list kosong (belum ada
    // contoh datanya dari backend).
    final bkDiaryId = categories.first['idProductCategory'];
    final requestedName = categoryId == null || categoryId == bkDiaryId
        ? 'Bk Diary'
        : categories.firstWhere(
            (c) => c['idProductCategory'] == categoryId,
            orElse: () => {'name': ''},
          )['name'];

    final products = requestedName == 'Bk Diary'
        ? [
            {
              'idProduct': '9e4fa5fef8e07b36ec48891e2200c7393bf3b2',
              'uuid': 'f20fcd21-b21a-4707-9ef9-0e628064eb94',
              'name': 'Bk Diary Holo Lc Tg',
              'prices': [],
              'images': [],
            },
            {
              'idProduct': '934ead6d9f6019e9d99cf775a54a05105b244f',
              'uuid': 'fd11795b-f4ff-442d-9b96-bc137b60c063',
              'name': 'Bk Diary Orgy Tg 082',
              'prices': [],
              'images': [],
            },
            {
              'idProduct': 'e85a1087e6ab89106f511e669df21ac315b7dbf6',
              'uuid': '516c8746-7afc-4075-b39e-618b0a9d7ad5',
              'name': 'Bk Diary PYK-010',
              'prices': [],
              'images': [],
            },
            {
              'idProduct': '60b3cf8df9b23ab1d1042fe5b161206fd6cf5802',
              'uuid': '9cb5dcef-b9ac-4735-a197-5d4490e66827',
              'name': 'Bk Diary Spiral A5 25100 SL',
              'prices': [],
              'images': [],
            },
          ]
        : [];

    return ProductPosResponse.fromJson({
      'status': 200,
      'data': {
        'allProducts': false,
        'categories': categories,
        'products': [
          {'categoryName': requestedName, 'products': products},
        ],
      },
      'page': {
        'current_page': 1,
        'row_per_page': 200,
        'total_pages': 1,
        'total_rows': products.length,
      },
    });
  }

  /// Fallback generik (dipakai kalau businessId tidak dikenali) - katalog
  /// makanan contoh, foto dari picsum karena tidak ada URL asli buat ini.
  ProductPosResponse _genericFoodMock() {
    const categories = [
      {'idProductCategory': 'cat-breakfast', 'name': 'Breakfast'},
      {'idProductCategory': 'cat-appetizer', 'name': 'Appetizer'},
      {'idProductCategory': 'cat-combo', 'name': 'Combo'},
      {'idProductCategory': 'cat-beverages', 'name': 'Beverages'},
    ];

    Map<String, dynamic> product(String id, String name, String seed) => {
      'idProduct': id,
      'uuid': id,
      'name': name,
      'prices': [
        {'minQty': 1, 'price': 15000},
      ],
      'images': [
        {
          'image': '$seed.jpg',
          'imagePath': 'https://picsum.photos/seed/$seed/400/400',
        },
      ],
    };

    final grouped = {
      'Breakfast': [
        product('p1', 'Garlic Bread', 'garlic-bread'),
        product('p2', 'Blueberry Toast', 'blueberry-toast'),
        product('p3', 'Blueberry Pancake', 'blueberry-pancake'),
      ],
      'Appetizer': [product('p4', 'Ceaser Salad', 'ceaser-salad')],
      'Combo': [
        product('p5', 'Pepperoni Medium Pizza', 'pepperoni-pizza'),
        product('p6', 'Beef Brefskeet', 'beef-brefskeet'),
        product('p7', 'Double Beef Burger', 'double-beef-burger'),
        product('p8', 'Strawberry Cheesecake', 'strawberry-cheesecake'),
      ],
      'Beverages': [
        product('p9', 'Mojito', 'mojito'),
        product('p10', 'Bleezing Sparkling', 'bleezing-sparkling'),
        product('p11', 'Wine', 'wine'),
        product('p12', 'Citrus Spark', 'citrus-spark'),
      ],
    };

    final totalRows = grouped.values.fold<int>(0, (a, b) => a + b.length);

    return ProductPosResponse.fromJson({
      'status': 200,
      'data': {
        'allProducts': true,
        'categories': categories,
        'products': grouped.entries
            .map((e) => {'categoryName': e.key, 'products': e.value})
            .toList(),
      },
      'page': {
        'current_page': 1,
        'row_per_page': 200,
        'total_pages': 1,
        'total_rows': totalRows,
      },
    });
  }
}

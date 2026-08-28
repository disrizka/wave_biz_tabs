class BusinessModel {
  final String idBusiness;
  final String name;
  final String logo;
  final String logoPath;
  final String username;
  final String about;
  final bool canBeSoldOutOfStock;
  final String userRoleName;
  final String roleId;
  final bool isPremium;
  final String? premiumStartAt;
  final String? premiumExpiresAt;
  final String? banned;

  BusinessModel({
    required this.idBusiness,
    required this.name,
    required this.logo,
    required this.logoPath,
    required this.username,
    required this.about,
    required this.canBeSoldOutOfStock,
    required this.userRoleName,
    required this.roleId,
    required this.isPremium,
    this.premiumStartAt,
    this.premiumExpiresAt,
    this.banned,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      idBusiness: json['idBusiness'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
      logoPath: json['logoPath'] ?? '',
      username: json['username'] ?? '',
      about: json['about'] ?? '',
      canBeSoldOutOfStock: json['canBeSoldOutOfStock'] ?? false,
      userRoleName: json['userRoleName'] ?? '',
      roleId: json['roleId'] ?? '',
      isPremium: json['isPremium'] ?? false,
      premiumStartAt: json['premiumStartAt'],
      premiumExpiresAt: json['premiumExpiresAt'],
      banned: json['banned'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idBusiness': idBusiness,
      'name': name,
      'logo': logo,
      'logoPath': logoPath,
      'username': username,
      'about': about,
      'canBeSoldOutOfStock': canBeSoldOutOfStock,
      'userRoleName': userRoleName,
      'roleId': roleId,
      'isPremium': isPremium,
      'premiumStartAt': premiumStartAt,
      'premiumExpiresAt': premiumExpiresAt,
      'banned': banned,
    };
  }
}

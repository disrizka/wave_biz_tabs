class UserModel {
  final String idUser;
  final String firstname;
  final String lastname;
  final String phone;
  final String email;
  final String photo;
  final String photoPath;
  final bool isDeactivated;
  final String username;
  final bool hasPage;
  final String userRoleName;
  final String roleId;

  UserModel({
    required this.idUser,
    required this.firstname,
    required this.lastname,
    required this.phone,
    required this.email,
    required this.photo,
    required this.photoPath,
    required this.isDeactivated,
    required this.username,
    required this.hasPage,
    required this.userRoleName,
    required this.roleId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      idUser: json['idUser'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      photo: json['photo'] ?? '',
      photoPath: json['photoPath'] ?? '',
      isDeactivated: json['isDeactivated'] ?? false,
      username: json['username'] ?? '',
      hasPage: json['hasPage'] ?? false,
      userRoleName: json['userRoleName'] ?? '',
      roleId: json['roleId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idUser': idUser,
      'firstname': firstname,
      'lastname': lastname,
      'phone': phone,
      'email': email,
      'photo': photo,
      'photoPath': photoPath,
      'isDeactivated': isDeactivated,
      'username': username,
      'hasPage': hasPage,
      'userRoleName': userRoleName,
      'roleId': roleId,
    };
  }

  String get fullName => '$firstname $lastname'.trim();
}

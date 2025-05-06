class User {
  final String id;
  final String username;
  final String password;
  final String email;
  final String? avatar;
  final DateTime createdAt;
  final DateTime lastActive;
  final DateTime? birthDate;
  final String? phoneNumber;
  final String? fullname;
  final bool isAdmin; // Thêm thuộc tính isAdmin

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.email,
    this.avatar,
    required this.createdAt,
    required this.lastActive,
    this.birthDate,
    this.phoneNumber,
    this.fullname,
    this.isAdmin = false, // Mặc định là tài khoản thường
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'email': email,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'birthDate': birthDate?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'fullname': fullname,
      'isAdmin': isAdmin ? 1 : 0, // Lưu dưới dạng 1/0 cho SQLite
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      password: map['password'] as String,
      email: map['email'] as String,
      avatar: map['avatar'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastActive: DateTime.parse(map['lastActive'] as String),
      birthDate: map['birthDate'] != null ? DateTime.parse(map['birthDate'] as String) : null,
      phoneNumber: map['phoneNumber'] as String?,
      fullname: map['fullname'] as String?,
      isAdmin: map['isAdmin'] == 1, // Đọc từ SQLite
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? password,
    String? email,
    String? avatar,
    DateTime? createdAt,
    DateTime? lastActive,
    DateTime? birthDate,
    String? phoneNumber,
    String? fullname,
    bool? isAdmin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      birthDate: birthDate ?? this.birthDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullname: fullname ?? this.fullname,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
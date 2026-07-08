class UserModel {
  final String id;
  final String email;
  final String name;
  int scanCount;
  bool isUnlimited;
  final DateTime createdAt;

  // 사업자 정보
  String businessName;      // 상호명
  String businessNumber;    // 사업자 번호
  String ownerName;         // 대표 이름
  String businessAddress;   // 사업장 주소
  String phoneNumber;       // 전화번호 (선택)

  static const int freeScanLimit = 30;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.scanCount = 0,
    this.isUnlimited = false,
    required this.createdAt,
    this.businessName = '',
    this.businessNumber = '',
    this.ownerName = '',
    this.businessAddress = '',
    this.phoneNumber = '',
  });

  int get remainingScans =>
      isUnlimited ? 999 : (freeScanLimit - scanCount).clamp(0, freeScanLimit);

  bool get canScan => isUnlimited || scanCount < freeScanLimit;

  double get scanUsagePercent =>
      isUnlimited ? 1.0 : (scanCount / freeScanLimit).clamp(0.0, 1.0);

  bool get hasBusinessInfo =>
      businessName.isNotEmpty || businessNumber.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'scanCount': scanCount,
        'isUnlimited': isUnlimited,
        'createdAt': createdAt.toIso8601String(),
        'businessName': businessName,
        'businessNumber': businessNumber,
        'ownerName': ownerName,
        'businessAddress': businessAddress,
        'phoneNumber': phoneNumber,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as String,
        email: map['email'] as String,
        name: map['name'] as String,
        scanCount: map['scanCount'] as int? ?? 0,
        isUnlimited: map['isUnlimited'] as bool? ?? false,
        createdAt: DateTime.parse(map['createdAt'] as String),
        businessName: map['businessName'] as String? ?? '',
        businessNumber: map['businessNumber'] as String? ?? '',
        ownerName: map['ownerName'] as String? ?? '',
        businessAddress: map['businessAddress'] as String? ?? '',
        phoneNumber: map['phoneNumber'] as String? ?? '',
      );

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    int? scanCount,
    bool? isUnlimited,
    DateTime? createdAt,
    String? businessName,
    String? businessNumber,
    String? ownerName,
    String? businessAddress,
    String? phoneNumber,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      scanCount: scanCount ?? this.scanCount,
      isUnlimited: isUnlimited ?? this.isUnlimited,
      createdAt: createdAt ?? this.createdAt,
      businessName: businessName ?? this.businessName,
      businessNumber: businessNumber ?? this.businessNumber,
      ownerName: ownerName ?? this.ownerName,
      businessAddress: businessAddress ?? this.businessAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

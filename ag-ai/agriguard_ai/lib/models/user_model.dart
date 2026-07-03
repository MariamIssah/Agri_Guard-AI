import '../models/user_role.dart';

class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.region,
    this.district,
    this.farmSizeHa,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? region;
  final String? district;
  final double? farmSizeHa;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:         json['id'] as String,
        name:       json['name'] as String,
        email:      json['email'] as String,
        phone:      (json['phone'] as String?) ?? '',
        role:       UserRole.fromString(json['role'] as String? ?? 'farmer'),
        region:     json['region'] as String?,
        district:   json['district'] as String?,
        farmSizeHa: (json['farm_size_ha'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'name':        name,
        'email':       email,
        'phone':       phone,
        'role':        role.name,
        'region':      region,
        'district':    district,
        'farm_size_ha': farmSizeHa,
      };
}

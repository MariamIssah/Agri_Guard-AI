enum UserRole {
  farmer,
  buyer,
  admin;

  String get label => switch (this) {
        UserRole.farmer => 'Farmer',
        UserRole.buyer  => 'Buyer / Aggregator',
        UserRole.admin  => 'Administrator',
      };

  String get welcome => switch (this) {
        UserRole.farmer => 'Welcome Farmer',
        UserRole.buyer  => 'Welcome Buyer',
        UserRole.admin  => 'Admin Dashboard',
      };

  static UserRole fromString(String s) => switch (s.toLowerCase()) {
        'buyer' => UserRole.buyer,
        'admin' => UserRole.admin,
        _       => UserRole.farmer,
      };
}

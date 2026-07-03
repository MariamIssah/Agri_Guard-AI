import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class UserSession extends ChangeNotifier {
  UserRole? _role;
  UserModel? _user;

  UserRole? get role => _role;
  UserModel? get user => _user;
  bool get isFarmer => _role == UserRole.farmer;
  bool get isBuyer => _role == UserRole.buyer;
  String get displayName => _user?.name ?? (_role == UserRole.farmer ? 'Farmer' : 'Buyer');

  void setRole(UserRole role) {
    _role = role;
    notifyListeners();
  }

  void setUser(UserModel user) {
    _user = user;
    _role = user.role;
    notifyListeners();
  }

  void clear() {
    _role = null;
    _user = null;
    notifyListeners();
  }
}

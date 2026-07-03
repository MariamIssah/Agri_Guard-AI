import 'package:flutter/foundation.dart';

import '../models/location_data.dart';

class LocationSession extends ChangeNotifier {
  LocationData? _current;
  bool _loading = false;
  String? _error;

  LocationData? get current => _current;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasCoordinates =>
      _current?.latitude != null && _current?.longitude != null;

  void setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  void setLocation(LocationData location) {
    _current = location;
    _error = null;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    if (_loading) {
      _loading = false;
      notifyListeners();
    } else {
      _loading = false;
      notifyListeners();
    }
  }
}

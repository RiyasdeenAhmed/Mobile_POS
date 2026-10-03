import 'package:flutter/foundation.dart';

import '../../../core/utils/result.dart';
import '../data/staff_repository.dart';
import '../domain/staff_user.dart';

class StaffSession extends ChangeNotifier {
  StaffRepository? _repository;

  StaffUser? _current;

  StaffUser? get current => _current;
  bool get isSignedIn => _current != null;
  bool get mustChangePin => _current?.mustChangePin ?? false;
  bool get isAdmin => _current?.role == 'admin';
  String? get staffUuid => _current?.uuid;
  String? get displayName => _current?.displayName;

  void attach(StaffRepository repository) {
    _repository = repository;
  }

  void adopt(StaffUser user) {
    _current = user;
    notifyListeners();
  }

  Future<AppResult<StaffUser>> signIn({
    required String username,
    required String pin,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return failure('Staff service is unavailable', code: 'unavailable');
    }

    final result = await repository.verifyPin(username: username, pin: pin);
    final data = result.dataOrNull;
    if (data != null) {
      _current = data;
      notifyListeners();
    }
    return result;
  }

  Future<AppResult<StaffUser>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final repository = _repository;
    final user = _current;
    if (repository == null || user == null) {
      return failure('Staff service is unavailable', code: 'unavailable');
    }

    final result = await repository.changePin(
      uuid: user.uuid,
      currentPin: currentPin,
      newPin: newPin,
    );
    final data = result.dataOrNull;
    if (data != null) {
      _current = data;
      notifyListeners();
    }
    return result;
  }

  void signOut() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}

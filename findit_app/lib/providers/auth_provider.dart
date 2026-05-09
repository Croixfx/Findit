import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class FindItAuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _apiService = ApiService();

  UserModel? currentUser;
  InstitutionModel? institution;
  bool isLoading = false;
  bool initializing = true;
  bool _loadingUser = false;
  String? error;

  Future<void> _fetchInstitutionById(String institutionId) async {
    try {
      final json = await _apiService.get('/institutions/$institutionId');
      institution = InstitutionModel.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      institution = null;
    }
  }

  Future<void> _loadStaffInstitution() async {
    try {
      final json = await _apiService.get('/institutions/my');
      institution = InstitutionModel.fromJson(json as Map<String, dynamic>);
      return;
    } on ApiException catch (e) {
      // No linked institution yet is an expected state for new staff.
      if (e.statusCode == 404) {
        institution = null;
        return;
      }
      // If /my is unavailable for any reason, fallback to existing ID lookup.
      final institutionId = currentUser?.institutionId;
      if (institutionId != null) {
        await _fetchInstitutionById(institutionId);
      } else {
        institution = null;
      }
    } catch (_) {
      final institutionId = currentUser?.institutionId;
      if (institutionId != null) {
        await _fetchInstitutionById(institutionId);
      } else {
        institution = null;
      }
    }
  }

  Future<void> tryLoadUser() async {
    if (!initializing || _loadingUser) return;
    _loadingUser = true;
    try {
      final json = await _apiService.post('/auth/me', {});
      currentUser = UserModel.fromJson(json as Map<String, dynamic>);
      if (currentUser?.role.toLowerCase() == 'staff') {
        await _loadStaffInstitution();
      } else {
        institution = null;
      }
    } catch (_) {
      currentUser = null;
      institution = null;
    } finally {
      _loadingUser = false;
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _begin();
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      final json = await _apiService.post('/auth/me', {});
      currentUser = UserModel.fromJson(json as Map<String, dynamic>);
      if (currentUser?.role.toLowerCase() == 'staff') {
        await _loadStaffInstitution();
      } else {
        institution = null;
      }
      error = null;
    } catch (e) {
      error = _message(e);
      rethrow;
    } finally {
      initializing = false;
      _end();
    }
  }

  Future<void> register(
    String email,
    String password,
    String fullName,
    String role, {
    String? institutionId,
  }) async {
    _begin();
    try {
      final credential = await _authService.createUserWithEmailAndPassword(
        email,
        password,
      );
      await credential.user?.updateDisplayName(fullName);

      final body = <String, dynamic>{
        'firebase_uid': credential.user!.uid,
        'email': email,
        'full_name': fullName,
        'role': role,
        if (institutionId != null) 'institution_id': institutionId,
      };
      final json = await _apiService.post('/auth/register', body);
      currentUser = UserModel.fromJson(json as Map<String, dynamic>);
      if (currentUser?.role.toLowerCase() == 'staff') {
        await _loadStaffInstitution();
      } else {
        institution = null;
      }
      error = null;
    } catch (e) {
      error = _message(e);
      rethrow;
    } finally {
      initializing = false;
      _end();
    }
  }

  Future<void> setupInstitution({
    required String name,
    required String type,
    String? contactEmail,
  }) async {
    _begin();
    try {
      // POST returns the created institution — use it directly, no round-trip needed
      final instJson = await _apiService.post('/institutions', {
        'name': name,
        'type': type,
        if (contactEmail != null && contactEmail.isNotEmpty)
          'contactEmail': contactEmail,
      });
      institution = InstitutionModel.fromJson(instJson as Map<String, dynamic>);

      // Refresh user to pick up the new institutionId
      final userJson = await _apiService.post('/auth/me', {});
      currentUser = UserModel.fromJson(userJson as Map<String, dynamic>);

      // Guard: if /auth/me hasn't reflected the DB write yet, patch locally
      if (currentUser != null &&
          currentUser!.institutionId == null &&
          institution != null) {
        currentUser = UserModel(
          id: currentUser!.id,
          firebaseUid: currentUser!.firebaseUid,
          email: currentUser!.email,
          fullName: currentUser!.fullName,
          role: currentUser!.role,
          institutionId: institution!.id,
          fcmToken: currentUser!.fcmToken,
        );
      }

      error = null;
    } catch (e) {
      error = _message(e);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    currentUser = null;
    institution = null;
    initializing = true;
    error = null;
    notifyListeners();
  }

  void _begin() {
    isLoading = true;
    error = null;
    notifyListeners();
  }

  void _end() {
    isLoading = false;
    notifyListeners();
  }

  String _message(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }
}

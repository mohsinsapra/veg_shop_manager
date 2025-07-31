import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/storage_service.dart';
import '../../data/models/user_role.dart';

class AuthState {
  final bool isLoggedIn;
  final UserRole? userRole;
  final String? currentShop;
  final bool isLoading;

  const AuthState({
    this.isLoggedIn = false,
    this.userRole,
    this.currentShop,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    UserRole? userRole,
    String? currentShop,
    bool? isLoading,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userRole: userRole ?? this.userRole,
      currentShop: currentShop ?? this.currentShop,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final StorageService _storageService;

  AuthNotifier(this._storageService) : super(const AuthState()) {
    _loadAuthState();
  }

  void _loadAuthState() async {
    try {
      final currentUser = await _storageService.getAuthData(AppConstants.currentUserKey);
      final currentShop = await _storageService.getAuthData(AppConstants.currentShopKey);
      
      if (currentUser != null) {
        final userRole = currentUser == AppConstants.adminCredential 
            ? UserRole.admin 
            : UserRole.shop;
        
        state = state.copyWith(
          isLoggedIn: true,
          userRole: userRole,
          currentShop: currentShop,
        );
      }
    } catch (e) {
      state = const AuthState();
    }
  }

  Future<bool> loginAsShop(String shopId) async {
    if (!AppConstants.predefinedShops.containsKey(shopId)) {
      return false;
    }

    state = state.copyWith(isLoading: true);

    try {
      await _storageService.setAuthData(AppConstants.currentUserKey, shopId);
      await _storageService.setAuthData(AppConstants.currentShopKey, shopId);
      
      state = state.copyWith(
        isLoggedIn: true,
        userRole: UserRole.shop,
        currentShop: shopId,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<bool> loginAsAdmin(String password) async {
    if (password != AppConstants.adminPassword) {
      return false;
    }

    state = state.copyWith(isLoading: true);

    try {
      await _storageService.setAuthData(AppConstants.currentUserKey, AppConstants.adminCredential);
      await _storageService.removeAuthData(AppConstants.currentShopKey);
      
      state = state.copyWith(
        isLoggedIn: true,
        userRole: UserRole.admin,
        currentShop: null,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _storageService.removeAuthData(AppConstants.currentUserKey);
      await _storageService.removeAuthData(AppConstants.currentShopKey);
      
      state = const AuthState();
    } catch (e) {
      state = const AuthState();
    }
  }

  String get currentShopName {
    if (state.currentShop != null) {
      return AppConstants.predefinedShops[state.currentShop] ?? 'Unknown Shop';
    }
    return '';
  }

  bool get isShopUser => state.userRole == UserRole.shop;
  bool get isAdmin => state.userRole == UserRole.admin;
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageServiceFactory.instance;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(storageServiceProvider));
});
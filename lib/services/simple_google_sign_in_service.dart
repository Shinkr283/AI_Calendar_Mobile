import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Auth 없이 순수 Google Sign-In만 사용하는 서비스
/// PigeonUserDetails 오류를 완전히 우회합니다
class SimpleGoogleSignInService {
  static final SimpleGoogleSignInService _instance = SimpleGoogleSignInService._internal();
  factory SimpleGoogleSignInService() => _instance;
  SimpleGoogleSignInService._internal();

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  bool _isInitialized = false;
  
  void initialize() {
    if (_isInitialized) {
      print('⚠️ SimpleGoogleSignInService 이미 초기화됨');
      return;
    }
    
    print('🔧 SimpleGoogleSignInService 초기화 중...');
    try {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        forceCodeForRefreshToken: true,
      );
      _isInitialized = true;
      print('✅ SimpleGoogleSignInService 초기화 완료');
    } catch (e) {
      print('❌ SimpleGoogleSignInService 초기화 실패: $e');
      rethrow;
    }
  }

  /// 앱 시작 시 기존 로그인 상태 복원 (간단한 방식)
  Future<GoogleSignInAccount?> restoreSignInState() async {
    if (!_isInitialized) initialize();
    
    try {
      print('🔄 기존 로그인 상태 확인 중...');
      
      // SharedPreferences에서 로그인 상태 확인
      final prefs = await SharedPreferences.getInstance();
      final isSignedIn = prefs.getBool('is_google_signed_in') ?? false;
      
      if (!isSignedIn) {
        print('❌ 저장된 로그인 상태 없음');
        return null;
      }
      
      print('📱 저장된 로그인 상태 발견, 복원 시도...');
      
      // 1. 현재 로그인된 사용자 확인
      GoogleSignInAccount? googleUser = _googleSignIn?.currentUser;
      if (googleUser != null) {
        _currentUser = googleUser;
        print('✅ 현재 사용자로 로그인 상태 복원: ${googleUser.email}');
        return googleUser;
      }
      
      // 2. 조용한 로그인 시도 (suppressErrors: false로 변경)
      print('🔄 조용한 로그인 시도...');
      try {
        googleUser = await _googleSignIn?.signInSilently(suppressErrors: false);
        if (googleUser != null) {
          _currentUser = googleUser;
          print('✅ 조용한 로그인 성공: ${googleUser.email}');
          return googleUser;
        }
      } catch (e) {
        print('⚠️ 조용한 로그인 오류: $e');
      }
      
      // 3. 저장된 정보가 있으면 로그인 상태로 간주
      final storedUserInfo = await getStoredUserInfo();
      if (storedUserInfo['email'] != null && storedUserInfo['name'] != null) {
        print('✅ 저장된 사용자 정보로 로그인 상태 유지: ${storedUserInfo['email']}');
        
        // 저장된 정보를 _currentUser 필드에 설정하기 위해 더미 값 사용
        // 실제 GoogleSignInAccount가 아니지만 currentUser getter에서 처리됨
        return _googleSignIn?.currentUser; // null이어도 앱에서 로그인 상태로 처리
      }
      
      print('⚠️ 복원 실패, 저장된 상태 삭제');
      await _clearStoredUserInfo();
      return null;
      
    } catch (e) {
      print('❌ 로그인 상태 복원 실패: $e');
      // 저장된 정보가 있으면 그래도 로그인으로 처리
      final prefs = await SharedPreferences.getInstance();
      final isSignedIn = prefs.getBool('is_google_signed_in') ?? false;
      if (isSignedIn) {
        final storedUserInfo = await getStoredUserInfo();
        if (storedUserInfo['email'] != null) {
          print('🔄 오류 시에도 저장된 정보로 세션 유지');
          // 저장된 정보가 있으면 로그인 상태로 처리하도록 더미 값 반환
          return _googleSignIn?.currentUser;
        }
      }
      await _clearStoredUserInfo();
      return null;
    }
  }

  /// Firebase 없는 순수 Google 로그인 (새 로그인만)
  Future<GoogleSignInAccount?> signIn() async {
    if (!_isInitialized) initialize();
    
    try {
      print('🔄 순수 Google 로그인 시작 (Firebase 우회)');
      
      // 이전 세션 정리 (새 로그인만)
      print('🧹 기존 Google 세션 정리...');
      await _clearPreviousSession();
      
      // Google 계정 선택
      print('👤 Google 계정 선택 중...');
      final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
      
      if (googleUser == null) {
        print('❌ 사용자가 로그인을 취소했습니다.');
        throw Exception('사용자가 로그인을 취소했습니다.');
      }
      
      print('✅ Google 계정 선택 완료: ${googleUser.email}');
      
      // 현재 사용자 저장
      _currentUser = googleUser;
      
      // 사용자 정보 저장
      await _saveUserInfo(googleUser);
      
      print('🎉 순수 Google 로그인 완료!');
      return googleUser;
      
    } catch (e) {
      print('❌ 순수 Google 로그인 실패: $e');
      await _clearPreviousSession(); // 실패 시에도 정리
      rethrow;
    }
  }

  /// 이전 세션만 정리 (저장된 사용자 정보는 유지하지 않음)
  Future<void> _clearPreviousSession() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
        print('✅ Google Sign-Out 완료');
        
        try {
          await _googleSignIn!.disconnect();
          print('✅ Google Disconnect 완료');
        } catch (e) {
          print('! Google Disconnect 오류 (무시): $e');
        }
      }
      _currentUser = null;
    } catch (e) {
      print('⚠️ 이전 세션 정리 중 오류: $e');
    }
  }

  /// Google 세션 완전 정리 (로그아웃 시 사용)
  Future<void> _clearGoogleSession() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
        print('✅ Google Sign-Out 완료');
        
        try {
          await _googleSignIn!.disconnect();
          print('✅ Google Disconnect 완료');
        } catch (e) {
          print('⚠️ Google Disconnect 오류 (무시): $e');
        }
      }
      
      _currentUser = null;
      await _clearStoredUserInfo();
      
    } catch (e) {
      print('⚠️ Google 세션 정리 중 오류: $e');
    }
  }

  /// 안전한 로그아웃
  Future<void> signOut() async {
    try {
      print('👋 순수 Google 로그아웃 시작...');
      await _clearGoogleSession();
      print('✅ 순수 Google 로그아웃 완료');
    } catch (e) {
      print('⚠️ 로그아웃 오류: $e');
    }
  }

  /// 사용자 정보 저장
  Future<void> _saveUserInfo(GoogleSignInAccount user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_user_email', user.email);
      await prefs.setString('google_user_name', user.displayName ?? '');
      await prefs.setString('google_user_photo', user.photoUrl ?? '');
      // await prefs.setString('google_user_id', user.id);
      await prefs.setBool('is_google_signed_in', true);
      print('💾 사용자 정보 저장 완료');
    } catch (e) {
      print('⚠️ 사용자 정보 저장 오류: $e');
    }
  }

  /// 저장된 사용자 정보 삭제
  Future<void> _clearStoredUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('google_user_email');
      await prefs.remove('google_user_name');
      await prefs.remove('google_user_photo');
      // await prefs.remove('google_user_id');
      await prefs.setBool('is_google_signed_in', false);
      print('🗑️ 저장된 사용자 정보 삭제 완료');
    } catch (e) {
      print('⚠️ 사용자 정보 삭제 오류: $e');
    }
  }

  /// 저장된 사용자 정보 조회
  Future<Map<String, String?>> getStoredUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('google_user_email'),
        'name': prefs.getString('google_user_name'),
        'photo': prefs.getString('google_user_photo'),
        // 'id': prefs.getString('google_user_id'),
      };
    } catch (e) {
      print('⚠️ 사용자 정보 조회 오류: $e');
      return {};
    }
  }

  /// 현재 로그인된 Google 계정 정보
  GoogleSignInAccount? get currentUser {
    // 실제 Google 계정이 있으면 반환
    final realUser = _currentUser ?? _googleSignIn?.currentUser;
    if (realUser != null) {
      return realUser;
    }
    
    // 저장된 정보가 있으면 임시 사용자 정보 반환을 위해 실제 로그인 시도
    _tryRestoreInBackground();
    return _currentUser ?? _googleSignIn?.currentUser;
  }
  
  /// 백그라운드에서 조용한 로그인 시도
  void _tryRestoreInBackground() {
    if (_isRestoringInBackground) return;
    _isRestoringInBackground = true;
    
    Future.delayed(Duration.zero, () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isSignedIn = prefs.getBool('is_google_signed_in') ?? false;
        if (isSignedIn && _currentUser == null) {
          final googleUser = await _googleSignIn?.signInSilently(suppressErrors: true);
          if (googleUser != null) {
            _currentUser = googleUser;
            print('🎉 백그라운드 자동 로그인 성공: ${googleUser.email}');
          }
        }
      } catch (e) {
        print('⚠️ 백그라운드 자동 로그인 실패: $e');
      } finally {
        _isRestoringInBackground = false;
      }
    });
  }
  
  bool _isRestoringInBackground = false;

  /// 로그인 상태 확인 (SharedPreferences 기반)
  Future<bool> get isSignedIn async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_google_signed_in') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 실시간 로그인 상태 확인
  bool get isSignedInSync {
    try {
      return _currentUser != null || _googleSignIn?.currentUser != null;
    } catch (e) {
      return false;
    }
  }

  /// Google API 호출용 Access Token 가져오기
  Future<String?> getAccessToken() async {
    try {
      final user = _currentUser ?? _googleSignIn?.currentUser;
      if (user == null) {
        print('❌ 로그인된 사용자가 없습니다.');
        return null;
      }

      final auth = await user.authentication;
      return auth.accessToken;
    } catch (e) {
      print('❌ Access Token 가져오기 실패: $e');
      return null;
    }
  }
}

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  GoogleSignIn? _googleSignIn;
  bool _isInitialized = false;
  
  void initialize() {
    if (_isInitialized) {
      print('⚠️ GoogleSignInService 이미 초기화됨');
      return;
    }
    
    print('🔧 GoogleSignInService 초기화 중...');
    try {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // 강제로 계정 선택 창 표시하여 캐시 문제 방지
        forceCodeForRefreshToken: true,
      );
      _isInitialized = true;
      print('✅ GoogleSignInService 초기화 완료');
    } catch (e) {
      print('❌ GoogleSignInService 초기화 실패: $e');
      rethrow;
    }
  }

  /// 완전히 안전한 Google 로그인 (방어적 코딩)
  Future<UserCredential?> signInWithGoogle() async {
    if (!_isInitialized || _googleSignIn == null) {
      throw Exception('GoogleSignInService가 초기화되지 않았습니다.');
    }
    
    try {
      print('🔄 Google 로그인 시작');
      
      // 1단계: 완전한 세션 정리 (중요!)
      print('🧹 모든 기존 세션 완전 정리...');
      await _forceCompleteSignOut();
      
      // 2단계: 잠시 대기 (플랫폼 채널 안정화)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 3단계: 새로운 로그인 시도
      print('👤 새로운 Google 계정 로그인 시도...');
      final GoogleSignInAccount? googleUser = await _safeSignIn();
      
      if (googleUser == null) {
        print('❌ 사용자가 로그인을 취소했습니다.');
        return null;
      }
      print('✅ Google 계정 선택 완료: ${googleUser.email}');

      // 4단계: 안전한 인증 토큰 획득
      print('🔑 인증 토큰 가져오는 중...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ 인증 토큰이 null입니다.');
        throw Exception('인증 토큰을 가져올 수 없습니다.');
      }
      print('✅ 인증 토큰 획득 완료');

      // 5단계: Firebase 인증
      print('🔥 Firebase 인증 중...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print('✅ Firebase 인증 완료: ${userCredential.user?.email}');
      
      // 6단계: 토큰 저장
      if (googleAuth.accessToken != null) {
        await _saveAccessToken(googleAuth.accessToken!);
      }
      
      print('🎉 Google 로그인 전체 과정 완료!');
      return userCredential;
      
    } catch (e, stackTrace) {
      print('❌ Google 로그인 실패: $e');
      print('📊 스택 트레이스: $stackTrace');
      
      // 실패 시 완전한 정리
      await _forceCompleteSignOut();
      rethrow;
    }
  }

  /// 방어적인 Google Sign-In 호출
  Future<GoogleSignInAccount?> _safeSignIn() async {
    if (_googleSignIn == null) return null;
    
    try {
      // 먼저 조용한 로그인 시도
      GoogleSignInAccount? account = await _googleSignIn!.signInSilently(suppressErrors: true);
      
      // 조용한 로그인 실패 시 명시적 로그인
      if (account == null) {
        print('🔄 명시적 Google 로그인 시도...');
        account = await _googleSignIn!.signIn();
      }
      
      return account;
    } catch (e) {
      print('⚠️ Google 로그인 중 오류 (재시도): $e');
      
      // 오류 발생 시 한 번 더 시도
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        return await _googleSignIn!.signIn();
      } catch (e2) {
        print('❌ Google 로그인 재시도 실패: $e2');
        rethrow;
      }
    }
  }

  /// 완전한 로그아웃 및 정리
  Future<void> _forceCompleteSignOut() async {
    try {
      print('🧹 완전한 세션 정리 시작...');
      
      // 1. Firebase 로그아웃
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        print('✅ Firebase 로그아웃 완료');
      }
      
      // 2. Google Sign-In 로그아웃
      if (_googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
          print('✅ Google Sign-Out 완료');
        } catch (e) {
          print('⚠️ Google Sign-Out 오류 (무시): $e');
        }
        
        // 3. 연결 해제 (선택적)
        try {
          await _googleSignIn!.disconnect();
          print('✅ Google Disconnect 완료');
        } catch (e) {
          print('⚠️ Google Disconnect 오류 (무시): $e');
        }
      }
      
      // 4. 저장된 토큰 정리
      await _clearStoredTokens();
      print('✅ 완전한 세션 정리 완료');
      
    } catch (e) {
      print('⚠️ 세션 정리 중 오류 (무시): $e');
    }
  }

  /// 안전한 로그아웃
  Future<void> signOut() async {
    try {
      print('👋 안전한 로그아웃 시작...');
      await _forceCompleteSignOut();
      print('✅ 로그아웃 완료');
    } catch (e) {
      print('⚠️ 로그아웃 오류: $e');
      // 로그아웃은 실패해도 계속 진행
    }
  }

  /// 완전한 연결 해제
  Future<void> disconnect() async {
    try {
      print('🔌 완전한 연결 해제 시작...');
      await _forceCompleteSignOut();
      print('✅ 연결 해제 완료');
    } catch (e) {
      print('⚠️ 연결 해제 오류: $e');
    }
  }

  /// 액세스 토큰 저장
  Future<void> _saveAccessToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_access_token', token);
      print('💾 토큰 저장 완료');
    } catch (e) {
      print('⚠️ 토큰 저장 오류: $e');
    }
  }

  /// 저장된 토큰들 삭제
  Future<void> _clearStoredTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('google_access_token');
      print('🗑️ 저장된 토큰 삭제 완료');
    } catch (e) {
      print('⚠️ 토큰 삭제 오류: $e');
    }
  }

  /// 저장된 액세스 토큰 가져오기
  Future<String?> getStoredAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('google_access_token');
    } catch (e) {
      print('⚠️ 토큰 조회 오류: $e');
      return null;
    }
  }

  /// 현재 로그인된 Google 계정 정보 (안전한 접근)
  GoogleSignInAccount? get currentUser {
    try {
      return _googleSignIn?.currentUser;
    } catch (e) {
      print('⚠️ currentUser 접근 오류: $e');
      return null;
    }
  }

  /// 로그인 상태 확인 (안전한 접근)
  bool get isSignedIn {
    try {
      return _googleSignIn?.currentUser != null;
    } catch (e) {
      print('⚠️ isSignedIn 확인 오류: $e');
      return false;
    }
  }
}
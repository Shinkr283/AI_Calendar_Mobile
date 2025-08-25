import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_sign_in_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  User? _user;
  bool _isLoading = false;
  String? _error;
  final GoogleSignInService _googleSignInService = GoogleSignInService();

  Future<void> signInWithGoogle() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final userCredential = await _googleSignInService.signInWithGoogle();
      
      if (!mounted) return;
      
      if (userCredential != null) {
        setState(() {
          _user = userCredential.user;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = '로그인에 실패했습니다.';
        });
      }
      
    } catch (e) {
      print('Google 로그인 오류: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _error = _simplifyError(e.toString());
      });
    }
  }

  String _simplifyError(String error) {
    print('🔍 오류 분석: $error');
    
    if (error.contains('사용자가 로그인을 취소했습니다')) {
      return '로그인이 취소되었습니다.';
    } else if (error.contains('인증 토큰을 가져올 수 없습니다')) {
      return '구글 인증에 실패했습니다. 다시 시도해주세요.';
    } else if (error.contains('PlatformException')) {
      return '구글 로그인 서비스에 문제가 있습니다. 앱을 재시작하고 다시 시도해주세요.';
    } else if (error.contains('network') || error.contains('Network')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (error.contains('cancelled') || error.contains('SIGN_IN_CANCELLED')) {
      return '로그인이 취소되었습니다.';
    } else if (error.contains('SIGN_IN_FAILED')) {
      return '구글 로그인에 실패했습니다. 구글 계정을 확인해주세요.';
    } else if (error.contains('firebase')) {
      return 'Firebase 인증에 실패했습니다. 잠시 후 다시 시도해주세요.';
    }
    
    // 디버그 모드에서는 전체 오류 표시
    if (error.length > 100) {
      return '로그인 중 오류가 발생했습니다. 앱을 재시작하고 다시 시도해주세요.';
    }
    
    return '로그인 오류: $error';
  }

  Future<void> signOut() async {
    try {
      await _googleSignInService.signOut();
      setState(() {
        _user = null;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '로그아웃 중 오류가 발생했습니다: ${e.toString()}';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _googleSignInService.initialize();
    _user = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('구글 로그인')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _user == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : signInWithGoogle,
                        icon: const Icon(Icons.login),
                        label: const Text('구글 계정으로 로그인'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(250, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          // 디버그 정보 표시
                          try {
                            final service = GoogleSignInService();
                            service.initialize();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Google Sign-In 서비스가 정상적으로 초기화되었습니다.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('초기화 오류: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('서비스 상태 확인', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : () async {
                          // 간단한 테스트 계정 생성
                          try {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            
                            // Firebase 연결 테스트
                            print('🔥 Firebase 연결 테스트 시작');
                            
                            // Firebase 상태 확인
                            final currentUser = FirebaseAuth.instance.currentUser;
                            print('현재 Firebase 사용자: $currentUser');
                            
                            setState(() {
                              _isLoading = false;
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Firebase 연결 상태: ${currentUser != null ? "연결됨" : "연결 안됨"}'),
                                backgroundColor: currentUser != null ? Colors.green : Colors.orange,
                              ),
                            );
                            
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              _error = 'Firebase 테스트 실패: $e';
                            });
                          }
                        },
                        child: const Text('Firebase 연결 테스트', 
                          style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_user!.photoURL != null)
                        CircleAvatar(
                          backgroundImage: NetworkImage(_user!.photoURL!),
                          radius: 40,
                        ),
                      const SizedBox(height: 16),
                      Text('이름: ${_user!.displayName ?? "-"}'),
                      Text('이메일: ${_user!.email ?? "-"}'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: signOut,
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
      ),
    );
  }
} 
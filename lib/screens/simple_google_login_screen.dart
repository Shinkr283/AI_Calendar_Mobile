import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/simple_google_sign_in_service.dart';
import '../main.dart';

class SimpleGoogleLoginScreen extends StatefulWidget {
  const SimpleGoogleLoginScreen({super.key});

  @override
  State<SimpleGoogleLoginScreen> createState() => _SimpleGoogleLoginScreenState();
}

class _SimpleGoogleLoginScreenState extends State<SimpleGoogleLoginScreen> {
  GoogleSignInAccount? _user;
  bool _isLoading = false;
  String? _error;
  final SimpleGoogleSignInService _googleSignInService = SimpleGoogleSignInService();

  @override
  void initState() {
    super.initState();
    _googleSignInService.initialize();
  }

  Future<void> signInWithGoogle() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final googleUser = await _googleSignInService.signIn();
      
      if (!mounted) return;
      
      if (googleUser != null) {
        setState(() {
          _user = googleUser;
          _isLoading = false;
        });
        
        // 메인 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
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
    if (error.contains('사용자가 로그인을 취소했습니다')) {
      return '로그인이 취소되었습니다.';
    }
    if (error.contains('network')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (error.contains('초기화되지 않았습니다')) {
      return '서비스 초기화 오류입니다.';
    }
    return '로그인 중 오류가 발생했습니다.';
  }

  Future<void> signOut() async {
    try {
      await _googleSignInService.signOut();
      if (mounted) {
        setState(() {
          _user = null;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '로그아웃 중 오류가 발생했습니다: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('구글 로그인 (간단 버전)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 구글 로고 대신 아이콘
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.account_circle,
                  size: 50,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'AI 캘린더에 오신 것을 환영합니다!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Google 계정으로 간편하게 로그인하세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 로그인/로그아웃 버튼
              if (_user == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : signInWithGoogle,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login, color: Colors.white),
                    label: Text(
                      _isLoading ? '로그인 중...' : 'Google 계정으로 로그인',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 테스트 버튼들
                TextButton(
                  onPressed: () async {
                    try {
                      final service = SimpleGoogleSignInService();
                      service.initialize();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simple Google Sign-In 서비스가 정상적으로 초기화되었습니다.'),
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
                
              ] else ...[
                // 사용자 정보 표시
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: _user!.photoUrl != null 
                            ? NetworkImage(_user!.photoUrl!) 
                            : null,
                        child: _user!.photoUrl == null 
                            ? const Icon(Icons.person, size: 30)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _user!.displayName ?? '사용자',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user!.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 로그아웃 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      '로그아웃',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 메인 화면으로 이동 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const MainScreen()),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: const Text(
                      '앱 사용하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              
              // 오류 메시지
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // 안내 문구
              Text(
                'Firebase Auth 없이 순수 Google Sign-In만 사용합니다.\nPigeonUserDetails 오류가 발생하지 않습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

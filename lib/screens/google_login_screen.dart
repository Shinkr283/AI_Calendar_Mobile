import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'calendar_sync_prompt_screen.dart';
// import 'calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  User? _user;
  bool _isLoading = false;
  String? _error;

  Future<void> signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: const [
          'email',
          'https://www.googleapis.com/auth/calendar.readonly',
        ],
      ).signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // 로그인 취소
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      // 액세스 토큰 저장 (동기화에서 사용)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_access_token', googleAuth.accessToken ?? '');
      setState(() {
        _user = userCredential.user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    setState(() {
      _user = null;
    });
  }

  @override
  void initState() {
    super.initState();
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
                        onPressed: signInWithGoogle,
                        icon: const Icon(Icons.login),
                        label: const Text('구글 계정으로 로그인'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
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
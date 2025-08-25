import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isInitialized = false;
  
  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;
  
  ThemeData get themeData => _isDarkMode ? _darkTheme : _lightTheme;

  static final ThemeData _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
  );

  Future<void> loadTheme() async {
    if (_isInitialized) return; // 이미 초기화된 경우 중복 실행 방지
    
    try {
      _isDarkMode = await SettingsService().getIsDarkMode();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('테마 로드 실패: $e');
      _isInitialized = true; // 실패해도 초기화 완료로 표시
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      await SettingsService().setIsDarkMode(_isDarkMode);
      notifyListeners();
    } catch (e) {
      print('테마 변경 실패: $e');
    }
  }

  Future<void> setTheme(bool isDark) async {
    try {
      _isDarkMode = isDark;
      await SettingsService().setIsDarkMode(_isDarkMode);
      notifyListeners();
    } catch (e) {
      print('테마 설정 실패: $e');
    }
  }
}

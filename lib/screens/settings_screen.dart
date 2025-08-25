import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Firebase 사용하지 않음
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/simple_google_sign_in_service.dart';
import '../services/native_alarm_service.dart';
import '../services/simple_google_calendar_service.dart';
import '../services/user_service.dart';
// import '../services/google_calendar_service.dart'; // 임시로 주석 처리
import '../services/settings_service.dart';
import '../providers/theme_provider.dart';
import '../models/user_profile.dart';
import 'simple_google_login_screen.dart';
import 'weather_screen.dart';
import 'map_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isDarkMode = false;
  int _weekStartDay = 0; // 0: 일요일, 1: 월요일
  bool _isCalendarSynced = false;
  bool _isDailyNotificationEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await UserService().getCurrentUser();
      if (mounted) {
        setState(() {
          _userProfile = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 정보 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService().getAllSettings();
      if (mounted) {
        setState(() {
          _weekStartDay = settings['weekStartDay'];
          _isDarkMode = settings['isDarkMode'];
          _isCalendarSynced = settings['isCalendarSynced'];
          _isDailyNotificationEnabled = settings['isDailyNotificationEnabled'];
          _notificationTime = settings['notificationTime'];
        });
      }
    } catch (e) {
      print('설정 로드 실패: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await SettingsService().setWeekStartDay(_weekStartDay);
      await SettingsService().setIsDarkMode(_isDarkMode);
      await SettingsService().setIsCalendarSynced(_isCalendarSynced);
      await SettingsService().setIsDailyNotificationEnabled(_isDailyNotificationEnabled);
      await SettingsService().setNotificationTime(_notificationTime);
    } catch (e) {
      print('설정 저장 실패: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      // 안전한 로그아웃
      await SimpleGoogleSignInService().signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SimpleGoogleLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncGoogleCalendar() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (_isCalendarSynced) {
        // 동기화 해제
        setState(() {
          _isCalendarSynced = false;
          _isLoading = false;
        });
        await _saveSettings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('구글 캘린더 동기화를 해제했습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // 동기화 활성화 - 실제 구글 캘린더 동기화 수행
        try {
          print('📅 구글 캘린더 실제 동기화 시작');
          
          // SimpleGoogleCalendarService를 사용하여 실제 동기화
          final calendarService = SimpleGoogleCalendarService();
          final syncedCount = await calendarService.syncFromGoogleCalendar();
          
          setState(() {
            _isCalendarSynced = true;
            _isLoading = false;
          });
          await _saveSettings();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('구글 캘린더 동기화 완료! ${syncedCount}개 일정을 가져왔습니다'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (e) {
          print('❌ 캘린더 동기화 실패: $e');
          
          setState(() {
            _isCalendarSynced = false;
            _isLoading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('구글 캘린더 동기화 실패: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캘린더 동기화 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
      });
      await _saveSettings();
    }
  }

  String _getWeekStartDayText(int day) {
    return day == 0 ? '일요일' : '월요일';
  }

  Widget _buildUserSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(),
      builder: (context, snapshot) {
        Map<String, String?> userInfo = {};
        GoogleSignInAccount? googleUser;
        
        if (snapshot.hasData) {
          userInfo = snapshot.data!['stored'] as Map<String, String?>;
          googleUser = snapshot.data!['google'] as GoogleSignInAccount?;
        }
        
        // 실제 Google 계정 정보가 있으면 우선 사용, 없으면 저장된 정보 사용
        final displayName = googleUser?.displayName ?? userInfo['name'] ?? '사용자';
        final email = googleUser?.email ?? userInfo['email'] ?? '';
        final photoUrl = googleUser?.photoUrl ?? userInfo['photo'];
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 30, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    if (_userProfile?.mbtiType != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'MBTI: ${_userProfile!.mbtiType}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: '로그아웃',
              ),
            ],
          ),
        );
      },
    );
  }

  /// 사용자 정보 가져오기 (저장된 정보 + 실제 Google 계정)
  Future<Map<String, dynamic>> _getUserInfo() async {
    try {
      // 저장된 사용자 정보 먼저 가져오기
      final storedUserInfo = await SimpleGoogleSignInService().getStoredUserInfo();
      
      // 실제 Google 계정 정보 가져오기 (백그라운드 복원 포함)
      final googleUser = SimpleGoogleSignInService().currentUser;
      
      return {
        'stored': storedUserInfo,
        'google': googleUser,
      };
    } catch (e) {
      print('❌ 사용자 정보 가져오기 실패: $e');
      return {
        'stored': <String, String?>{},
        'google': null,
      };
    }
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.grey.shade600),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 사용자 정보 섹션
            _buildUserSection(),

            // 구글 서비스 섹션
            _buildSettingsSection(
              '구글 서비스',
              [
                _buildSettingsTile(
                  icon: Icons.sync,
                  title: '구글 캘린더 동기화',
                  subtitle: _isCalendarSynced ? '동기화됨' : '동기화 안됨',
                  trailing: Switch(
                    value: _isCalendarSynced,
                    onChanged: (value) => _syncGoogleCalendar(),
                  ),
                  onTap: _syncGoogleCalendar,
                  iconColor: _isCalendarSynced ? Colors.green : Colors.grey,
                ),
              ],
            ),

            // 외관 섹션
            _buildSettingsSection(
              '외관',
              [
                _buildSettingsTile(
                  icon: Icons.calendar_view_week,
                  title: '주 시작 요일',
                  subtitle: _getWeekStartDayText(_weekStartDay),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('주 시작 요일 선택'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<int>(
                              title: const Text('일요일'),
                              value: 0,
                              groupValue: _weekStartDay,
                              onChanged: (value) {
                                setState(() {
                                  _weekStartDay = value!;
                                });
                                _saveSettings();
                                Navigator.of(context).pop();
                              },
                            ),
                            RadioListTile<int>(
                              title: const Text('월요일'),
                              value: 1,
                              groupValue: _weekStartDay,
                              onChanged: (value) {
                                setState(() {
                                  _weekStartDay = value!;
                                });
                                _saveSettings();
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  title: '다크 모드',
                  subtitle: _isDarkMode ? '어두운 테마' : '밝은 테마',
                  trailing: Switch(
                    value: _isDarkMode,
                    onChanged: (value) async {
                      setState(() {
                        _isDarkMode = value;
                      });
                      
                      // ThemeProvider를 통해 테마 변경
                      await context.read<ThemeProvider>().setTheme(value);
                      await _saveSettings();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isDarkMode ? '다크 모드가 활성화되었습니다' : '라이트 모드가 활성화되었습니다'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            // 알림 섹션
            _buildSettingsSection(
              '알림',
              [
                _buildSettingsTile(
                  icon: Icons.notifications,
                  title: '하루 일정 알림',
                  subtitle: _isDailyNotificationEnabled 
                      ? '매일 ${_notificationTime.format(context)}에 알림'
                      : '알림 꺼짐',
                  trailing: Switch(
                    value: _isDailyNotificationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isDailyNotificationEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                  iconColor: _isDailyNotificationEnabled ? Colors.orange : Colors.grey,
                ),
                if (_isDailyNotificationEnabled)
                  _buildSettingsTile(
                    icon: Icons.access_time,
                    title: '알림 시간 설정',
                    subtitle: _notificationTime.format(context),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _selectNotificationTime,
                  ),
                _buildSettingsTile(
                  icon: Icons.preview,
                  title: '알림 미리보기',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      // 즉시 실제 기기 알림 발송
                      await NativeAlarmService.scheduleNativeAlarm(
                        title: '📅 AI 캘린더 - 오늘의 일정',
                        body: '회의 3개, 약속 1개가 있습니다. 일정을 확인해보세요!',
                        delaySeconds: 0, // 즉시 알림
                        notificationId: 9999, // 미리보기 전용 ID
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('알림 미리보기 실패: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),

            // 추가 기능 섹션
            _buildSettingsSection(
              '추가 기능',
              [
                _buildSettingsTile(
                  icon: Icons.wb_sunny,
                  title: '날씨 정보 보기',
                  subtitle: '현재 위치의 날씨 확인',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WeatherScreen()),
                    );
                  },
                  iconColor: Colors.orange,
                ),
                _buildSettingsTile(
                  icon: Icons.map,
                  title: '내 위치 지도 보기',
                  subtitle: '현재 위치를 지도에서 확인',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapScreen()),
                    );
                  },
                  iconColor: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

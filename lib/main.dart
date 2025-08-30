import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/event_service.dart';
import 'services/user_service.dart';
import 'services/chat_service.dart';
import 'models/event.dart';
import 'models/user_profile.dart';
import 'models/chat_message.dart';
import 'screens/calendar_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/simple_google_login_screen.dart';
import 'services/simple_google_sign_in_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/weather_screen.dart'; // Added import for WeatherScreen
import 'screens/map_screen.dart'; // MapScreen import 추가
import 'screens/chat_screen.dart';//추가
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';//추가
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'services/location_weather_service.dart';
import 'services/native_alarm_service.dart';
import 'services/holiday_service.dart';
import 'services/chat_prompt_service.dart';
import 'providers/theme_provider.dart';
import 'services/settings_service.dart';


// 권한 요청 및 현재 위치 조회
// 위치 권한 및 현재 위치는 LocationService에서 처리합니다.
// KstTime 클래스 제거됨 (네이티브 알림 사용으로 더 이상 필요없음)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화
  await Firebase.initializeApp();
  // 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko_KR', null);

  // 데이터베이스 초기화를 먼저 수행
  try {
    final databaseService = DatabaseService();
    await databaseService.database; // 초기화 보장
    print('✅ 데이터베이스 초기화 완료');
  } catch (e) {
    print('❌ 데이터베이스 초기화 실패: $e');
  }

  // 앱 로딩 속도를 위해 일부 초기화를 백그라운드로 이동
  _initializeBackgroundServices();
    runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const AICalendarApp(),
    ),
  );
}

/// 알림 권한 요청 함수
Future<void> _requestNotificationPermission() async {
  try {
    // 안드로이드 알림 권한 확인
    PermissionStatus permission = await Permission.notification.status;
    
    print('📱 현재 알림 권한 상태: $permission');
    
    if (permission.isDenied) {
      print('🔔 알림 권한을 요청합니다...');
      
      // 알림 권한 요청
      PermissionStatus result = await Permission.notification.request();
      
      if (result.isGranted) {
        print('✅ 알림 권한이 허용되었습니다!');
      } else if (result.isDenied) {
        print('❌ 알림 권한이 거부되었습니다.');
        print('💡 설정에서 수동으로 허용해주세요: 설정 > 앱 > ai_calendar_mobile > 알림');
      } else if (result.isPermanentlyDenied) {
        print('🚫 알림 권한이 영구적으로 거부되었습니다.');
        print('💡 설정에서 수동으로 허용해주세요: 설정 > 앱 > ai_calendar_mobile > 알림');
      }
    } else if (permission.isGranted) {
      print('✅ 알림 권한이 이미 허용되어 있습니다!');
    } else if (permission.isPermanentlyDenied) {
      print('🚫 알림 권한이 영구적으로 거부되어 있습니다.');
      print('💡 설정에서 수동으로 허용해주세요: 설정 > 앱 > ai_calendar_mobile > 알림');
    }
    
  } catch (e) {
    print('❌ 알림 권한 확인 중 오류: $e');
  }

// 중복된 runApp 호출 제거됨
}

/// 백그라운드에서 실행할 초기화 작업들
void _initializeBackgroundServices() {
  Future.delayed(const Duration(milliseconds: 500), () async {
    // 알림 권한 요청
    await _requestNotificationPermission();
    
    // 기존 일정들의 labelColor 업데이트
    try {
      final databaseService = DatabaseService();
      await databaseService.updateExistingEventsLabelColor();
      print('✅ 기존 일정들의 labelColor 업데이트 완료');
    } catch (e) {
      print('❌ labelColor 업데이트 실패: $e');
    }
    
    // 위치 서비스 초기화
    try {
      final locationWeatherService = LocationWeatherService();
      final pos = await locationWeatherService.getCurrentPosition(accuracy: LocationAccuracy.high);
      print('초기 위치: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      print('초기 위치 확인 실패: $e');
    }

    // 한국 공휴일 미리 로드 (올해)
    try {
      await HolidayService().preloadForYear(DateTime.now().year);
    } catch (e) {
      print('공휴일 로드 실패: $e');
    }

    // 하루 일정 알림 복원
    try {
      await SettingsService().restoreDailyNotification();
      await PromptService().initialize();
      // await UserService().getCurrentUser();
    } catch (e) {
      print('하루 일정 알림 복원 실패: $e');
    }
  });
}

class AICalendarApp extends StatefulWidget {
  const AICalendarApp({super.key});

  @override
  State<AICalendarApp> createState() => _AICalendarAppState();
}

class _AICalendarAppState extends State<AICalendarApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱 시작 시 한 번만 테마 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ThemeProvider>().loadTheme();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DatabaseService().dispose(); // 앱 종료 시 연결 해제
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // 앱이 완전히 종료될 때 데이터베이스 연결 해제
      DatabaseService().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'AI 캘린더',
          theme: themeProvider.themeData,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
                          home: FutureBuilder<bool>(
                  future: _checkLoginStatus(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('앱 초기화 중...'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.data == true) {
                      return const MainScreen();
                    }
                    return const SimpleGoogleLoginScreen();
                  },
                ),
        );
      },
    );
  }

  /// 로그인 상태 확인 및 복원
  Future<bool> _checkLoginStatus() async {
    try {
      // SimpleGoogleSignInService 초기화
      final signInService = SimpleGoogleSignInService();
      
      // SharedPreferences에서 로그인 상태 확인
      final isSignedIn = await signInService.isSignedIn;
      
      if (isSignedIn) {
        print('📱 저장된 로그인 상태 발견, 백그라운드 복원 시작');
        // 백그라운드에서 실제 로그인 복원 시도
        signInService.restoreSignInState().then((user) {
          if (user != null) {
            print('✅ 백그라운드 로그인 복원 성공: ${user.email}');
          } else {
            print('⚠️ 백그라운드 로그인 복원 실패');
          }
        }).catchError((e) {
          print('❌ 백그라운드 로그인 복원 오류: $e');
        });
        
        return true; // 저장된 상태가 있으면 일단 메인 화면으로
      }
      
      return false; // 로그인 화면으로
    } catch (e) {
      print('❌ 로그인 상태 확인 오류: $e');
      return false;
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // 각 탭의 화면들
  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const ChatScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'AI 비서',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

// 임시 화면들 (나중에 별도 파일로 분리할 예정)
class CalendarTabScreen extends StatelessWidget {
  const CalendarTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _testEventService(context),
            tooltip: '일정 서비스 테스트',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 64,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              '캘린더 화면',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '일정 관리 기능이 여기에 들어갑니다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '🐛 우상단 버그 아이콘을 눌러서 일정 서비스를 테스트해보세요!',
              style: TextStyle(fontSize: 14, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _testEventService(BuildContext context) async {
    try {
      final eventService = EventService();
      
      // 테스트 일정 생성
      final event = await eventService.createEvent(
        title: '테스트 회의',
        description: '데이터베이스 테스트용 일정입니다',
        startTime: DateTime.now().add(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        location: '회의실 A',
        alarmMinutesBefore: 10,
      );

      // 생성된 일정 조회
      final retrievedEvent = await eventService.getEvent(event.id);
      
      // 오늘 일정 조회
      final todayEvents = await eventService.getTodayEvents();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ 일정 서비스 테스트 성공!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('생성된 일정: ${event.title}'),
                Text('일정 ID: ${event.id}'),
                Text('조회 성공: ${retrievedEvent != null ? '✅' : '❌'}'),
                Text('오늘 일정 개수: ${todayEvents.length}개'),
                const SizedBox(height: 8),
                const Text('데이터베이스가 정상적으로 작동합니다!'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ 테스트 실패'),
            content: Text('오류: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }
}

// 기존 SettingsTabScreen 제거됨 - 새로운 SettingsScreen으로 대체

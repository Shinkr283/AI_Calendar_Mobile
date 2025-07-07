import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 서비스 import 추가
import 'services/database_service.dart';
import 'services/event_service.dart';
import 'services/user_service.dart';
import 'services/chat_service.dart';
import 'models/event.dart';
import 'models/user_profile.dart';
import 'models/chat_message.dart';
import 'screens/calendar_screen.dart';

void main() {
  runApp(const AICalendarApp());
}

class AICalendarApp extends StatelessWidget {
  const AICalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'AI 캘린더',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // 각 탭의 화면들 (나중에 실제 화면으로 교체할 예정)
  final List<Widget> _screens = [
    const CalendarScreen(),
    const ChatTabScreen(),
    const SettingsTabScreen(),
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
        category: EventCategory.work,
        priority: EventPriority.high,
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

class ChatTabScreen extends StatelessWidget {
  const ChatTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 비서'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _testChatService(context),
            tooltip: '채팅 서비스 테스트',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text(
              'AI 비서 화면',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'AI 챗봇 기능이 여기에 들어갑니다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '🐛 우상단 버그 아이콘을 눌러서 채팅 서비스를 테스트해보세요!',
              style: TextStyle(fontSize: 14, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _testChatService(BuildContext context) async {
    try {
      final chatService = ChatService();
      
      // 테스트 채팅 세션 생성
      final session = await chatService.createChatSession(title: '테스트 대화');
      
      // 테스트 메시지 추가
      final userMessage = await chatService.addUserMessage('안녕하세요! 테스트 메시지입니다.');
      final aiMessage = await chatService.addAssistantMessage('안녕하세요! AI 비서입니다. 무엇을 도와드릴까요?');
      
      // 메시지 조회
      final messages = await chatService.getCurrentSessionMessages();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ 채팅 서비스 테스트 성공!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('세션 생성: ${session.title}'),
                Text('세션 ID: ${session.id}'),
                Text('사용자 메시지: ${userMessage.content}'),
                Text('AI 메시지: ${aiMessage.content}'),
                Text('총 메시지 수: ${messages.length}개'),
                const SizedBox(height: 8),
                const Text('채팅 시스템이 정상적으로 작동합니다!'),
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

class SettingsTabScreen extends StatelessWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _testUserService(context),
            tooltip: '사용자 서비스 테스트',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              '설정 화면',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '앱 설정 기능이 여기에 들어갑니다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '🐛 우상단 버그 아이콘을 눌러서 사용자 서비스를 테스트해보세요!',
              style: TextStyle(fontSize: 14, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _testUserService(BuildContext context) async {
    try {
      final userService = UserService();
      
      // 테스트 사용자 생성
      final user = await userService.createUser(
        name: '테스트 사용자',
        email: 'test@example.com',
        mbtiType: 'INTJ',
      );
      
      // MBTI 설정 테스트
      await userService.setMBTIType('ENFP');
      
      // 선호도 설정 테스트
      await userService.setThemeMode('dark');
      await userService.setWorkingHours(9, 18);
      
      // 현재 사용자 조회
      final currentUser = await userService.getCurrentUser();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ 사용자 서비스 테스트 성공!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('사용자 이름: ${user.name}'),
                Text('이메일: ${user.email}'),
                Text('MBTI: ${currentUser?.mbtiType ?? 'N/A'}'),
                Text('사용자 ID: ${user.id}'),
                const SizedBox(height: 8),
                const Text('사용자 관리 시스템이 정상적으로 작동합니다!'),
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

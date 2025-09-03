import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';
import '../services/chat_service.dart'; // ChatProvider를 import
import '../services/places_service.dart';
import 'map_screen.dart';
import '../services/chat_briefing_service.dart';
import '../services/location_weather_service.dart';
import '../models/event.dart';
import '../services/chat_personalize_service.dart';

class ChatScreen extends StatefulWidget {
  final Event? initialEvent;
  final String? initialTopic;

  const ChatScreen({super.key, this.initialEvent, this.initialTopic});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // ChatScreen에 처음 들어올 때 메시지 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChatProvider>(context, listen: false);
      provider.clearMessages();
    });
  }

  // 토픽별 인사말 반환
  String _getTopicGreeting(String topic) {
    switch (topic) {
      case '날씨':
        return '안녕하세요! 날씨 AI 비서입니다. 🌤️\n\n오늘 날씨에 대해 궁금한 점이 있으시거나, 날씨 관련 조언이 필요하시면 언제든 말씀해주세요!';
      case '위치':
        return '안녕하세요! 위치 AI 비서입니다. 📍\n\n현재 위치나 주변 정보에 대해 궁금한 점이 있으시면 언제든 말씀해주세요!';
      case '건강':
        return '안녕하세요! 건강 AI 비서입니다. 💪\n\n건강 관리나 운동에 대한 조언이 필요하시면 언제든 말씀해주세요!';
      case '학습':
        return '안녕하세요! 학습 AI 비서입니다. 📚\n\n학습 방법이나 동기부여가 필요하시면 언제든 말씀해주세요!';
      case '스타일':
        return '안녕하세요! 스타일 AI 비서입니다. 👗\n\n패션이나 스타일링에 대한 조언이 필요하시면 언제든 말씀해주세요!';
      case '여행':
        return '안녕하세요! 여행 AI 비서입니다. ✈️\n\n여행 계획이나 추천이 필요하시면 언제든 말씀해주세요!';
      default:
        return '안녕하세요! 무엇을 도와드릴까요?';
    }
  }

  // 토픽별 개인화된 응답 처리
  Future<void> _handlePersonalizedResponse(
    ChatProvider provider,
    String userMessage,
    String topic,
  ) async {
    // 사용자 메시지 추가
    provider.addUserText(userMessage);

    try {
      final personalizeService = ChatPersonalizeService();
      String selectedType = 'general';
      Map<String, String> contextData = {};

      // 토픽별 타입과 컨텍스트 데이터 설정
      switch (topic) {
        case '건강':
          selectedType = 'health';
          // 건강 관련 컨텍스트 데이터 수집
          final locationWeatherService = LocationWeatherService();
          final weather = await locationWeatherService
              .fetchAndSaveLocationWeather();
          if (weather != null) {
            contextData['localWeather'] =
                '현재 날씨: ${weather['weather']?[0]?['description']}, 온도: ${weather['main']?['temp']}°C';
          }
          break;
        case '학습':
          selectedType = 'learning';
          // 학습 관련 컨텍스트 데이터 수집
          contextData['deadlines'] = '현재 시점: ${DateTime.now().toString()}';
          break;
        case '스타일':
          selectedType = 'style';
          // 스타일 관련 컨텍스트 데이터 수집
          final locationWeatherService = LocationWeatherService();
          final weather = await locationWeatherService
              .fetchAndSaveLocationWeather();
          if (weather != null) {
            contextData['forecastByEvent'] =
                '현재 날씨: ${weather['weather']?[0]?['description']}, 온도: ${weather['main']?['temp']}°C';
          }
          break;
        case '여행':
          selectedType = 'travel';
          // 여행 관련 컨텍스트 데이터 수집
          contextData['tripOverview'] = '여행 계획에 대한 조언을 제공합니다.';
          break;
      }

      // 개인화된 응답 생성
      final response = await personalizeService.generatePersonalizedResponse(
        userMessage: userMessage,
        selectedType: selectedType,
        contextData: contextData,
        // conversationHistory: conversationHistory,
      );

      provider.addAssistantText(response);
    } catch (e) {
      print('❌ 개인화된 응답 생성 실패: $e');
      provider.addAssistantText('죄송합니다. 응답을 생성하는 중 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = const types.User(id: 'user'); // 사용자 정보는 여기서 정의

    return Scaffold(
      body: SafeArea(
        child: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            // 로딩 중이고, 메시지가 비어있을 때 로딩 인디케이터를 표시
            if (provider.isLoading && provider.messages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('잠시만 기다려주세요.', style: TextStyle(fontSize: 16)),
                  ],
                ),
              );
            }

            // 최초 진입 시 인사말 또는 일정 관련 대화 시작
            if (!provider.isLoading && provider.messages.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // 이중 추가 방지: 콜백 시점에 빈 경우에만
                if (provider.messages.isEmpty) {
                  if (widget.initialEvent != null) {
                    // 일정이 있는 경우 해당 일정에 대한 대화 시작
                    final event = widget.initialEvent!;
                    final startTime =
                        '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}';
                    final endTime =
                        '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}';

                    String eventDescription =
                        '${event.title} 일정에 대해 이야기해보겠습니다.\n\n';
                    eventDescription += '📅 일정: ${event.title}\n';
                    eventDescription += '⏰ 시간: $startTime ~ $endTime\n';
                    if (event.location.isNotEmpty) {
                      eventDescription += '📍 장소: ${event.location}\n';
                    }
                    if (event.description.isNotEmpty) {
                      eventDescription += '📝 설명: ${event.description}\n';
                    }
                    eventDescription +=
                        '\n이 일정에 대해 궁금한 점이 있으시거나 도움이 필요한 부분이 있으시면 언제든 말씀해주세요!';

                    provider.addAssistantText(eventDescription);
                  } else if (widget.initialTopic != null) {
                    // 토픽 기반 채팅 시작
                    String topicGreeting = _getTopicGreeting(
                      widget.initialTopic!,
                    );
                    provider.addAssistantText(topicGreeting);
                  } else {
                    // 일반적인 인사말
                    provider.addAssistantText('안녕하세요! 무엇을 도와드릴까요?');
                  }
                }
              });
            }

            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Chat(
                user: user,
                messages: provider.messages,
                onSendPressed: (partial) async {
                  final text = partial.text.trim();
                  // 날짜별 브리핑 요청: 'YYYY-MM-DD 브리핑'
                  final dateBrf = RegExp(
                    r"^(\d{4})[-.](\d{1,2})[-.](\d{1,2})\s*브리핑",
                  ).firstMatch(text);
                  if (dateBrf != null) {
                    final y = int.parse(dateBrf.group(1)!);
                    final m = int.parse(dateBrf.group(2)!);
                    final d = int.parse(dateBrf.group(3)!);
                    final date = DateTime(y, m, d);
                    final briefing = await BriefingService().getBriefingForDate(
                      date,
                    );
                    provider.addAssistantText(briefing);
                    return;
                  }
                  // 오늘 브리핑 요청: '브리핑'
                  if (text == '브리핑') {
                    await provider.requestBriefing();
                    return;
                  }
                  // '<장소> 날씨' 요청: 챗으로 날씨 정보 응답
                  final weatherMatch = RegExp(r'(.+?)\s*날씨').firstMatch(text);
                  if (weatherMatch != null) {
                    final location = weatherMatch.group(1)!.trim();
                    provider.addUserText(text);
                    final place = await PlacesService.geocodeAddress(location);
                    if (place != null) {
                      final locationWeatherService = LocationWeatherService();
                      final weather = await locationWeatherService.fetchWeather(
                        place.latitude,
                        place.longitude,
                      );
                      if (weather != null) {
                        final desc =
                            (weather['weather']?[0]?['description'] ?? '')
                                .toString();
                        final temp = (weather['main']?['temp'] ?? '')
                            .toString();
                        provider.addAssistantText(
                          '"${place.address}"의 날씨: $desc, 기온: ${temp}°C',
                        );
                      } else {
                        provider.addAssistantText(
                          '죄송합니다. "${place.address}"의 날씨 정보를 가져올 수 없습니다.',
                        );
                      }
                    } else {
                      provider.addAssistantText(
                        '죄송합니다. "$location" 위치를 찾을 수 없습니다.',
                      );
                    }
                    return;
                  }
                  // '<장소> 위치' 요청: 먼저 사용자 발화를 채팅에 남기고, 그 다음 지도 화면으로 이동
                  final locMatch = RegExp(
                    r'(.+?)\s*(위치|장소)\s*(보여줘|알려줘)',
                  ).firstMatch(text);
                  if (locMatch != null) {
                    final location = locMatch.group(1)!.trim();
                    provider.addUserText(text);
                    final place = await PlacesService.geocodeAddress(location);
                    if (place != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MapScreen(
                            initialLat: place.latitude,
                            initialLon: place.longitude,
                            initialAddress: place.address,
                          ),
                        ),
                      );
                      provider.addAssistantText(
                        '"${place.address}"의 위치를 지도에서 확인해보세요!',
                      );
                    } else {
                      provider.addAssistantText(
                        '죄송합니다. "$location" 위치를 찾을 수 없습니다.',
                      );
                    }
                    return;
                  }

                  // 토픽별 개인화된 응답 처리
                  if (widget.initialTopic != null) {
                    if (widget.initialTopic == '위치') {
                      // 위치 토픽의 일반적인 대화 처리
                      await provider.sendMessage(partial);
                      return;
                    } else if ([
                      '건강',
                      '학습',
                      '스타일',
                      '여행',
                    ].contains(widget.initialTopic)) {
                      await _handlePersonalizedResponse(
                        provider,
                        text,
                        widget.initialTopic!,
                      );
                      return;
                    }
                  }

                  // 일반적인 대화 처리
                  await provider.sendMessage(partial);
                  return;
                },
                theme: DefaultChatTheme(
                  primaryColor: Colors.blue,
                  secondaryColor: const Color(0xffF5F5F5),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                isAttachmentUploading: provider.isLoading, // 하단 입력창 옆 로딩 인디케이터
              ),
            );
          },
        ),
      ),
    );
  }
}

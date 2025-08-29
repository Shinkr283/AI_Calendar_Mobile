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

class ChatScreen extends StatelessWidget {
  final Event? initialEvent;
  
  const ChatScreen({
    super.key,
    this.initialEvent,
  });

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
                    Text(
                      '잠시만 기다려주세요.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            
            // 최초 진입 시 인사말 또는 일정 관련 대화 시작
            if (!provider.isLoading && provider.messages.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // 이중 추가 방지: 콜백 시점에 빈 경우에만
                if (provider.messages.isEmpty) {
                  if (initialEvent != null) {
                    // 일정이 있는 경우 해당 일정에 대한 대화 시작
                    final event = initialEvent!;
                    final startTime = '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}';
                    final endTime = '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}';
                    
                    String eventDescription = '${event.title} 일정에 대해 이야기해보겠습니다.\n\n';
                    eventDescription += '📅 일정: ${event.title}\n';
                    eventDescription += '⏰ 시간: $startTime ~ $endTime\n';
                    if (event.location.isNotEmpty) {
                      eventDescription += '📍 장소: ${event.location}\n';
                    }
                    if (event.description.isNotEmpty) {
                      eventDescription += '📝 설명: ${event.description}\n';
                    }
                    eventDescription += '\n이 일정에 대해 궁금한 점이 있으시거나 도움이 필요한 부분이 있으시면 언제든 말씀해주세요!';
                    
                    provider.addAssistantText(eventDescription);
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
                  final dateBrf = RegExp(r"^(\d{4})[-.](\d{1,2})[-.](\d{1,2})\s*브리핑").firstMatch(text);
                  if (dateBrf != null) {
                    final y = int.parse(dateBrf.group(1)!);
                    final m = int.parse(dateBrf.group(2)!);
                    final d = int.parse(dateBrf.group(3)!);
                    final date = DateTime(y, m, d);
                    final briefing = await BriefingService().getBriefingForDate(date);
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
                      final weather = await locationWeatherService.fetchWeather(place.latitude, place.longitude);
                      if (weather != null) {
                        final desc = (weather['weather']?[0]?['description'] ?? '').toString();
                        final temp = (weather['main']?['temp'] ?? '').toString();
                        provider.addAssistantText('"${place.address}"의 날씨: $desc, 기온: ${temp}°C');
                      } else {
                        provider.addAssistantText('죄송합니다. "${place.address}"의 날씨 정보를 가져올 수 없습니다.');
                      }
                    } else {
                      provider.addAssistantText('죄송합니다. "$location" 위치를 찾을 수 없습니다.');
                    }
                    return;
                  }
                  // '<장소> 위치' 요청: 먼저 사용자 발화를 채팅에 남기고, 그 다음 지도 화면으로 이동
                  final locMatch = RegExp(r'(.+?)\s*(위치|장소)\s*(보여줘|알려줘)').firstMatch(text);
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
                      provider.addAssistantText('"${place.address}"의 위치를 지도에서 확인해보세요!');
                    } else {
                      provider.addAssistantText('죄송합니다. "$location" 위치를 찾을 수 없습니다.');
                    }
                    return;
                  }
                  
                                     // 일반적인 대화 처리
                   provider.addUserText(text);
                   await provider.sendMessage(partial);
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
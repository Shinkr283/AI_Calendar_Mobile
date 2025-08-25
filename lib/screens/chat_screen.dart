import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';
import '../services/chat_service.dart'; // ChatProvider를 import
import '../services/weather_service.dart';
import '../services/places_service.dart';
import 'map_screen.dart';
import '../services/chat_briefing_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = const types.User(id: 'user'); // 사용자 정보는 여기서 정의

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 비서'),
      ),
      body: Consumer<ChatProvider>(
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
                    '잠시만 기다려주세요. 브리핑을 준비 중입니다.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }
          
          return Chat(
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
                final place = await PlacesService.geocodeAddress(location);
                if (place != null) {
                  final weather = await WeatherService().fetchWeather(place.latitude, place.longitude);
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
              // '<장소> 위치' 요청: 지도 화면으로 이동
              final locMatch = RegExp(r'(.+?)\s*(위치|장소)\s*(보여줘|알려줘)').firstMatch(text);
              if (locMatch != null) {
                final location = locMatch.group(1)!.trim();
                final place = await PlacesService.geocodeAddress(location);
                if (place != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => MapScreen(
                        initialLat: place.latitude,
                        initialLon: place.longitude,
                        initialAddress: place.address,
                      ),
                    ),
                  );
                  return;
                } else {
                  provider.addAssistantText('죄송합니다. "$location" 위치를 찾을 수 없습니다.');
                  return;
                }
              }
              // 그 외 일반 메시지
              await provider.sendMessage(partial);
            },
            user: user,
            theme: const DefaultChatTheme(
              primaryColor: Colors.blue,
              secondaryColor: Color(0xffF5F5F5),
            ),
            isAttachmentUploading: provider.isLoading, // 하단 입력창 옆 로딩 인디케이터
          );
        },
      ),
    );
  }
} 
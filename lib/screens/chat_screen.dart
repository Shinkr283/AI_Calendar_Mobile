import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';
import '../services/chat_service.dart'; // ChatProvider를 import

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ChatProvider 인스턴스를 가져옵니다.
    final chatProvider = Provider.of<ChatProvider>(context);
    final user = const types.User(id: 'user'); // 사용자 정보는 여기서 정의

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 비서'),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          // 로딩 중이고, 메시지가 비어있을 때 로딩 인디케이터를 표시
          if (provider.isLoading && provider.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Chat(
            messages: provider.messages,
            onSendPressed: provider.sendMessage,
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
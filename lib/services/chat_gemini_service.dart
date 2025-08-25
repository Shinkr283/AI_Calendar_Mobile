import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // 메시지 전송 (Function calling 지원)
  Future<GeminiResponse> sendMessage({
    required String message,
    required String systemPrompt,
    required List<Map<String, dynamic>> functionDeclarations,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    final apiKey = ApiKeys.geminiApiKey;
    
    final url = '$_baseUrl?key=$apiKey';
    
    // 대화 히스토리 구성
    final contents = <Map<String, dynamic>>[];
    
    // 시스템 프롬프트 추가
    contents.add({
      'parts': [{'text': systemPrompt}],
      'role': 'user'
    });
    contents.add({
      'parts': [{'text': '네, 알겠습니다. 해당 역할과 성격으로 대화하겠습니다.'}],
      'role': 'model'
    });

    // 기존 대화 히스토리 추가
    contents.addAll(conversationHistory);
    
    // 현재 사용자 메시지 추가
    contents.add({
      'parts': [{'text': message}],
      'role': 'user'
    });

    final requestBody = {
      'contents': contents,
      'tools': [
        {
          'functionDeclarations': functionDeclarations
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 1,
        'topP': 1,
        'maxOutputTokens': 2048, // increased token limit to prevent truncation
      }
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GeminiResponse.fromJson(data);
      } else {
        throw Exception('Gemini API 호출 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // Function response 전송
  Future<GeminiResponse> sendFunctionResponse({
    required String functionName,
    required Map<String, dynamic> functionResult,
    required String systemPrompt,
    required List<Map<String, dynamic>> functionDeclarations,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    final apiKey = ApiKeys.geminiApiKey;

    final url = '$_baseUrl?key=$apiKey';
    
    final contents = <Map<String, dynamic>>[];
    
    // 시스템 프롬프트 추가
    contents.add({
      'parts': [{'text': systemPrompt}],
      'role': 'user'
    });
    contents.add({
      'parts': [{'text': '네, 알겠습니다. 해당 역할과 성격으로 대화하겠습니다.'}],
      'role': 'model'
    });

    // 기존 대화 히스토리 추가
    contents.addAll(conversationHistory);
    
    // Function response 추가
    contents.add({
      'parts': [
        {
          'functionResponse': {
            'name': functionName,
            'response': functionResult
          }
        }
      ],
      'role': 'user'
    });

    final requestBody = {
      'contents': contents,
      'tools': [
        {
          'functionDeclarations': functionDeclarations
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 1,
        'topP': 1,
        'maxOutputTokens': 2048, // increased token limit
      }
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GeminiResponse.fromJson(data);
      } else {
        throw Exception('Gemini API 호출 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }
}

// Gemini API 응답 클래스
class GeminiResponse {
  final String? text;
  final List<GeminiFunctionCall> functionCalls;

  GeminiResponse({
    this.text,
    this.functionCalls = const [],
  });

  factory GeminiResponse.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) {
      return GeminiResponse();
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>? ?? {};
    final parts = content['parts'] as List<dynamic>? ?? [];

    String? text;
    List<GeminiFunctionCall> functionCalls = [];

    for (final part in parts) {
      final partMap = part as Map<String, dynamic>;
      
      if (partMap.containsKey('text')) {
        text = partMap['text'] as String?;
      } else if (partMap.containsKey('functionCall')) {
        final functionCallData = partMap['functionCall'] as Map<String, dynamic>;
        functionCalls.add(GeminiFunctionCall.fromJson(functionCallData));
      }
    }

    return GeminiResponse(
      text: text,
      functionCalls: functionCalls,
    );
  }
}

// Function call 클래스
class GeminiFunctionCall {
  final String name;
  final Map<String, dynamic> args;

  GeminiFunctionCall({
    required this.name,
    required this.args,
  });

  factory GeminiFunctionCall.fromJson(Map<String, dynamic> json) {
    return GeminiFunctionCall(
      name: json['name'] as String,
      args: json['args'] as Map<String, dynamic>? ?? {},
    );
  }
} 
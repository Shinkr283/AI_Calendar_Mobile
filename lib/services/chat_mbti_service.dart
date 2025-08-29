
import '../models/chat_mbti.dart';
import 'user_service.dart';
import 'chat_gemini_service.dart';
import 'chat_prompt_service.dart';

class MbtiService {
  static final MbtiService _instance = MbtiService._internal();
  factory MbtiService() => _instance;
  MbtiService._internal();

  // MBTI 관련 Function declaration
  static const Map<String, dynamic> setMbtiFunction = {
    'name': 'setMbtiType',
    'description': '사용자의 MBTI 유형을 설정하고, 그에 맞는 AI 챗봇의 성격을 적용합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'mbti': {
          'type': 'string',
          'description': '설정할 MBTI 유형 (예: INFP, ESTJ)',
          'enum': ['INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP', 'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP']
        }
      },
      'required': ['mbti']
    }
  };

  // MBTI 관련 모든 functions 목록
  static List<Map<String, dynamic>> get functions => [
    setMbtiFunction,
  ];

  // MBTI Function call 처리
  Future<Map<String, dynamic>> handleFunctionCall(GeminiFunctionCall call) async {
    if (call.name == 'setMbtiType') {
      final mbti = call.args['mbti'] as String?;
      if (mbti != null) {
        return await setMbtiType(mbti);
      } else {
        return {'status': '오류: MBTI 유형이 제공되지 않았습니다.'};
      }
    }
    return {'status': '오류: 알 수 없는 MBTI 함수입니다.'};
  }

  // MBTI 유형 설정
  Future<Map<String, dynamic>> setMbtiType(String mbti) async {
    if (mbti.isNotEmpty && MbtiData.isValid(mbti)) {
      try {
        final userService = UserService();
        await userService.setMBTIType(mbti.toUpperCase());
        
        // PromptService 캐시 업데이트
        await PromptService().updateMbti(mbti.toUpperCase());
        
        return {'status': '성공적으로 ${mbti.toUpperCase()}로 설정되었습니다. 이제 새로운 성격으로 대화하겠습니다.'};
      } catch (e) {
        return {'status': '오류: MBTI를 설정하는 동안 데이터베이스에 문제가 발생했습니다.'};
      }
    } else {
      return {'status': '오류: 유효하지 않은 MBTI 유형입니다. (${MbtiData.allTypes.join(', ')}) 중 하나를 입력해주세요.'};
    }
  }

  // 현재 사용자의 MBTI 유형 가져오기
  Future<String> getCurrentMbtiType() async {
    final userService = UserService();
    final user = await userService.getCurrentUser();
    return user?.mbtiType ?? 'INFP';
  }

  // MBTI 프로필 정보 가져오기
  MbtiChatbotProfile getMbtiProfile(String mbtiType) {
    return MbtiData.getChatbotProfile(mbtiType);
  }

  // MBTI 유형 유효성 검사
  bool isValidMbtiType(String mbti) {
    return MbtiData.isValid(mbti);
  }

  // 모든 MBTI 유형 목록
  List<String> getAllMbtiTypes() {
    return MbtiData.allTypes;
  }
} 
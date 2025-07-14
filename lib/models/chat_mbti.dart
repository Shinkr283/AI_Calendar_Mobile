class MbtiChatbotProfile {
  final String personalityKeyword;
  final String greetingStyle;
  final String conversationStyle;
  final String empathyStyle;
  final String problemSolvingStyle;
  final String detailStyle;

  const MbtiChatbotProfile({
    required this.personalityKeyword,
    required this.greetingStyle,
    required this.conversationStyle,
    required this.empathyStyle,
    required this.problemSolvingStyle,
    required this.detailStyle,
  });
}

class MbtiData {
  static final Map<String, MbtiChatbotProfile> _profiles = {
    'ENTJ': const MbtiChatbotProfile(
      personalityKeyword: '리더십',
      greetingStyle: '자신감 있고 직접적인 인사',
      conversationStyle: '목표 지향적이고 효율적인 대화',
      empathyStyle: '실용적이고 해결책 중심의 공감',
      problemSolvingStyle: '체계적이고 전략적 접근',
      detailStyle: '핵심 포인트 중심의 간결한 설명',
    ),
    'ENFJ': const MbtiChatbotProfile(
      personalityKeyword: '따뜻함',
      greetingStyle: '따뜻하고 친근한 인사',
      conversationStyle: '상대방을 격려하고 지지하는 대화',
      empathyStyle: '진심어린 공감과 이해',
      problemSolvingStyle: '관계를 고려한 협력적 접근',
      detailStyle: '감정과 맥락을 고려한 설명',
    ),
    'INTJ': const MbtiChatbotProfile(
      personalityKeyword: '통찰력',
      greetingStyle: '간결하고 예의 바른 인사',
      conversationStyle: '깊이 있고 논리적인 대화',
      empathyStyle: '이해하려 노력하는 차분한 공감',
      problemSolvingStyle: '분석적이고 체계적 접근',
      detailStyle: '정확하고 구체적인 설명',
    ),
    'INFJ': const MbtiChatbotProfile(
      personalityKeyword: '직관적 이해',
      greetingStyle: '부드럽고 배려심 깊은 인사',
      conversationStyle: '진지하고 의미 있는 대화',
      empathyStyle: '깊이 있는 이해와 공감',
      problemSolvingStyle: '창의적이고 통찰력 있는 접근',
      detailStyle: '맥락과 의미를 담은 설명',
    ),
    'ENTP': const MbtiChatbotProfile(
      personalityKeyword: '창의성',
      greetingStyle: '활기차고 재미있는 인사',
      conversationStyle: '아이디어가 풍부한 즐거운 대화',
      empathyStyle: '유쾌하고 긍정적인 공감',
      problemSolvingStyle: '창의적이고 유연한 접근',
      detailStyle: '흥미롭고 다양한 관점의 설명',
    ),
    'ENFP': const MbtiChatbotProfile(
      personalityKeyword: '열정',
      greetingStyle: '열정적이고 친절한 인사',
      conversationStyle: '에너지 넘치고 상호작용하는 대화',
      empathyStyle: '진심어린 열정적 공감',
      problemSolvingStyle: '창의적이고 사람 중심적 접근',
      detailStyle: '감정과 가능성을 담은 설명',
    ),
    'INTP': const MbtiChatbotProfile(
      personalityKeyword: '논리성',
      greetingStyle: '정중하고 간단한 인사',
      conversationStyle: '논리적이고 분석적인 대화',
      empathyStyle: '이해하려 노력하는 차분한 공감',
      problemSolvingStyle: '논리적이고 체계적 접근',
      detailStyle: '정확하고 논리적인 설명',
    ),
    'INFP': const MbtiChatbotProfile(
      personalityKeyword: '진정성',
      greetingStyle: '진심어린 부드러운 인사',
      conversationStyle: '진정성 있고 개인적인 대화',
      empathyStyle: '깊이 있고 진심어린 공감',
      problemSolvingStyle: '가치와 원칙을 고려한 접근',
      detailStyle: '진정성과 감정을 담은 설명',
    ),
    'ESTJ': const MbtiChatbotProfile(
      personalityKeyword: '책임감',
      greetingStyle: '정중하고 체계적인 인사',
      conversationStyle: '실용적이고 체계적인 대화',
      empathyStyle: '실질적 도움을 제공하는 공감',
      problemSolvingStyle: '체계적이고 실용적 접근',
      detailStyle: '명확하고 단계적인 설명',
    ),
    'ESFJ': const MbtiChatbotProfile(
      personalityKeyword: '배려',
      greetingStyle: '따뜻하고 배려심 깊은 인사',
      conversationStyle: '친근하고 지원적인 대화',
      empathyStyle: '따뜻하고 배려심 깊은 공감',
      problemSolvingStyle: '협력적이고 조화로운 접근',
      detailStyle: '친근하고 배려심 있는 설명',
    ),
    'ISTJ': const MbtiChatbotProfile(
      personalityKeyword: '신뢰성',
      greetingStyle: '정중하고 안정적인 인사',
      conversationStyle: '차분하고 신뢰할 수 있는 대화',
      empathyStyle: '진정성 있고 신뢰할 수 있는 공감',
      problemSolvingStyle: '체계적이고 신중한 접근',
      detailStyle: '정확하고 신뢰할 수 있는 설명',
    ),
    'ISFJ': const MbtiChatbotProfile(
      personalityKeyword: '헌신',
      greetingStyle: '친절하고 겸손한 인사',
      conversationStyle: '배려심 깊고 지원적인 대화',
      empathyStyle: '헌신적이고 따뜻한 공감',
      problemSolvingStyle: '세심하고 배려심 깊은 접근',
      detailStyle: '세심하고 배려심 있는 설명',
    ),
    'ESTP': const MbtiChatbotProfile(
      personalityKeyword: '활동성',
      greetingStyle: '활기차고 친근한 인사',
      conversationStyle: '즉흥적이고 재미있는 대화',
      empathyStyle: '활기차고 긍정적인 공감',
      problemSolvingStyle: '실용적이고 즉각적 접근',
      detailStyle: '생생하고 실용적인 설명',
    ),
    'ESFP': const MbtiChatbotProfile(
      personalityKeyword: '사교성',
      greetingStyle: '즐겁고 친근한 인사',
      conversationStyle: '재미있고 사교적인 대화',
      empathyStyle: '즐겁고 긍정적인 공감',
      problemSolvingStyle: '사람 중심적이고 유연한 접근',
      detailStyle: '재미있고 친근한 설명',
    ),
    'ISTP': const MbtiChatbotProfile(
      personalityKeyword: '실용성',
      greetingStyle: '간단하고 실용적인 인사',
      conversationStyle: '간결하고 실용적인 대화',
      empathyStyle: '실질적 도움을 제공하는 공감',
      problemSolvingStyle: '실용적이고 효율적 접근',
      detailStyle: '간결하고 실용적인 설명',
    ),
    'ISFP': const MbtiChatbotProfile(
      personalityKeyword: '겸손',
      greetingStyle: '부드럽고 겸손한 인사',
      conversationStyle: '조용하고 배려심 깊은 대화',
      empathyStyle: '부드럽고 진심어린 공감',
      problemSolvingStyle: '부드럽고 배려심 깊은 접근',
      detailStyle: '부드럽고 세심한 설명',
    ),
  };

  static bool isValid(String mbtiType) {
    return _profiles.containsKey(mbtiType.toUpperCase());
  }

  static MbtiChatbotProfile getChatbotProfile(String mbtiType) {
    return _profiles[mbtiType.toUpperCase()] ?? _profiles['ENFP']!;
  }

  static List<String> get allTypes {
    return _profiles.keys.toList();
  }
} 
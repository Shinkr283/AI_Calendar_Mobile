// API 키 설정 파일 (예시)
// 실제 사용 시 이 파일을 복사해서 api_keys.dart로 만들고 실제 키를 입력하세요
// api_keys.dart는 .gitignore에 포함되어 있어 Git에 업로드되지 않습니다

class ApiKeys {
  // Google Maps API Key
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
  
  // OpenWeatherMap API Key  
  static const String weatherApiKey = 'YOUR_WEATHER_API_KEY_HERE';
  
  // Gemini AI API Key
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  
  // Google Calendar API 설정
  static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID_HERE';
  static const String googleClientSecret = 'YOUR_GOOGLE_CLIENT_SECRET_HERE';
}

// 사용법:
// 1. 이 파일을 api_keys.dart로 복사
// 2. 실제 API 키들을 입력
// 3. api_keys.dart는 Git에 업로드되지 않음 (.gitignore에 포함됨)
// 4. 팀원과는 별도로 API 키 공유 (Slack, 카톡 등으로) 
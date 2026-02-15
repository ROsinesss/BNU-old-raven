/// API 配置
class ApiConfig {
  // 后端服务地址（本地测试）
  static const String baseUrl = 'http://192.168.0.104:8000';

  // API 端点
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String schedule = '/api/schedule';
  static const String grades = '/api/grades';
  static const String exams = '/api/exams';
  static const String semesterInfo = '/api/semester-info';
}

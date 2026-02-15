import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// 全局 API 服务 — 基于 Dio
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _token;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // 请求拦截器：自动携带 token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        debugPrint('API Error: ${e.requestOptions.path} → ${e.message}');
        return handler.next(e);
      },
    ));
  }

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  // ============ 认证 ============

  /// 登录，返回原始 JSON
  Future<Map<String, dynamic>> login(String studentId, String password) async {
    final res = await _dio.post(ApiConfig.login, data: {
      'student_id': studentId,
      'password': password,
    });
    return res.data;
  }

  /// 登出
  Future<void> logout(String studentId) async {
    try {
      await _dio.post(ApiConfig.logout, queryParameters: {
        'student_id': studentId,
      });
    } catch (_) {
      // 忽略登出失败
    }
  }

  // ============ 课表 ============

  Future<Map<String, dynamic>> getSchedule({int year = 2025, int semester = 1}) async {
    final res = await _dio.get(ApiConfig.schedule, queryParameters: {
      'year': year,
      'semester': semester,
    });
    return res.data;
  }

  // ============ 成绩 ============

  Future<Map<String, dynamic>> getGrades({
    int year = 0,
    int yearEnd = 0,
    int semester = -1,
  }) async {
    final res = await _dio.get(ApiConfig.grades, queryParameters: {
      'year': year,
      'year_end': yearEnd,
      'semester': semester,
    });
    return res.data;
  }

  // ============ 考试 ============

  Future<Map<String, dynamic>> getExams() async {
    final res = await _dio.get(ApiConfig.exams);
    return res.data;
  }
}

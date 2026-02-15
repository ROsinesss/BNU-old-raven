import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final Box _settings = Hive.box('settings');

  bool _loading = false;
  String? _error;

  // 用户信息
  String? _token;
  String? _studentId;
  String? _name;
  String? _className;

  AuthProvider() {
    // 从本地缓存恢复登录状态
    _token = _settings.get('token');
    _studentId = _settings.get('studentId');
    _name = _settings.get('name');
    _className = _settings.get('className');
    if (_token != null) {
      _api.setToken(_token!);
    }
  }

  bool get isLoggedIn => _token != null;
  bool get loading => _loading;
  String? get error => _error;
  String? get token => _token;
  String? get studentId => _studentId;
  String? get name => _name;
  String? get className => _className;

  /// 登录
  Future<bool> login(String studentId, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.login(studentId, password);
      _token = data['token'];
      _studentId = data['student_id'];
      _name = data['name'];
      _className = data['class_name'] ?? '';

      _api.setToken(_token!);

      // 缓存到本地
      await _settings.put('token', _token);
      await _settings.put('studentId', _studentId);
      await _settings.put('name', _name);
      await _settings.put('className', _className);

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    if (_studentId != null) {
      await _api.logout(_studentId!);
    }
    _api.clearToken();
    _token = null;
    _studentId = null;
    _name = null;
    _className = null;

    await _settings.delete('token');
    await _settings.delete('studentId');
    await _settings.delete('name');
    await _settings.delete('className');

    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('401')) return '学号或密码错误';
      if (msg.contains('timeout') || msg.contains('Timeout')) return '连接超时，请检查网络';
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        return '无法连接服务器';
      }
    }
    return '登录失败，请稍后重试';
  }
}

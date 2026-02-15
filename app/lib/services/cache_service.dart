import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 本地数据缓存服务 — 基于 Hive
/// 将 API 响应 JSON 缓存到本地，下次打开 app 立即可用
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Box get _box => Hive.box('cache');

  /// 保存 JSON 数据
  Future<void> put(String key, Map<String, dynamic> data) async {
    try {
      await _box.put(key, jsonEncode(data));
    } catch (e) {
      debugPrint('[Cache] 保存失败 $key: $e');
    }
  }

  /// 读取 JSON 数据
  Map<String, dynamic>? get(String key) {
    try {
      final raw = _box.get(key);
      if (raw is String && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Cache] 读取失败 $key: $e');
    }
    return null;
  }

  /// 删除
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  /// 清空所有缓存
  Future<void> clear() async {
    await _box.clear();
  }

  // ---- 便捷 key 生成 ----
  static String scheduleKey(int year, int semester) => 'schedule_${year}_$semester';
  static String gradesKey(int year, int yearEnd, int semester) =>
      'grades_${year}_${yearEnd}_$semester';
  static String examsKey(int year, int semester) => 'exams_${year}_$semester';
  static String semesterInfoKey(int year, int semester) =>
      'seminfo_${year}_$semester';
}

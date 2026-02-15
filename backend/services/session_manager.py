"""
Session 管理器

管理用户的 WebVPN 会话，支持 session 缓存和自动续期。
"""

import time
import logging
from typing import Optional

from services.auth import AuthService

logger = logging.getLogger(__name__)

# 会话缓存：student_id → (AuthService, last_active_time)
_session_cache: dict[str, tuple[AuthService, float]] = {}

# Session 最大空闲时间（秒）
SESSION_MAX_IDLE = 30 * 60  # 30 分钟
# 跳过 HTTP 验证的时间窗口（秒）— 在此时间内直接复用 session
SESSION_SKIP_VERIFY = 5 * 60  # 5 分钟


def get_or_create_session(student_id: str, password: str = "") -> tuple[Optional[AuthService], str]:
    """
    获取或创建用户会话
    
    如果已有活跃会话则复用，否则创建新会话。
    
    Returns:
        (AuthService | None, error_message)
    """
    now = time.time()
    
    # 检查缓存中是否有有效 session
    if student_id in _session_cache:
        auth_service, last_active = _session_cache[student_id]
        
        # 检查是否过期
        if now - last_active < SESSION_MAX_IDLE:
            # 5 分钟内活跃过的 session 跳过 HTTP 验证，直接复用
            if now - last_active < SESSION_SKIP_VERIFY:
                _session_cache[student_id] = (auth_service, now)
                return auth_service, ""
            # 超过 5 分钟，需要验证 session 是否仍有效
            if auth_service.ensure_logged_in():
                _session_cache[student_id] = (auth_service, now)
                return auth_service, ""
            else:
                logger.info(f"Session 已过期，重新登录: {student_id}")
                del _session_cache[student_id]
        else:
            logger.info(f"Session 空闲超时: {student_id}")
            del _session_cache[student_id]
    
    # 需要登录
    if not password:
        return None, "需要密码"
    
    auth_service = AuthService()
    result = auth_service.login(student_id, password)
    
    if not result["success"]:
        return None, result.get("message", "登录失败，请检查学号和密码")
    
    # 额外验证：确认 session 确实可以访问受保护页面
    if not auth_service.ensure_logged_in():
        logger.warning(f"登录声称成功但 session 验证失败: {student_id}")
        return None, "学号或密码错误"
    
    _session_cache[student_id] = (auth_service, now)
    return auth_service, ""


def get_cached_session(student_id: str) -> Optional[AuthService]:
    """仅获取缓存的 session，不创建新的"""
    if student_id in _session_cache:
        auth_service, last_active = _session_cache[student_id]
        now = time.time()
        if now - last_active < SESSION_MAX_IDLE and auth_service.is_logged_in:
            _session_cache[student_id] = (auth_service, now)
            return auth_service
    return None


def invalidate_session(student_id: str):
    """使 session 失效"""
    if student_id in _session_cache:
        del _session_cache[student_id]


def cleanup_expired_sessions():
    """清理过期的 session"""
    now = time.time()
    expired = [
        sid for sid, (_, last_active) in _session_cache.items()
        if now - last_active >= SESSION_MAX_IDLE
    ]
    for sid in expired:
        del _session_cache[sid]

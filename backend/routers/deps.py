"""
路由依赖项：JWT 认证和 session 获取
"""

import logging
from fastapi import Header, HTTPException
from jose import jwt, JWTError

from config import JWT_SECRET_KEY, JWT_ALGORITHM
from services.session_manager import get_cached_session

logger = logging.getLogger(__name__)


async def get_current_session(authorization: str = Header(...)):
    """
    从 JWT token 中提取用户信息，并获取对应的已登录 session。
    
    请求头格式：Authorization: Bearer <token>
    """
    # 解析 Bearer token
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="无效的认证头")
    
    token = authorization.replace("Bearer ", "")
    
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        student_id = payload.get("sub")
        if not student_id:
            raise HTTPException(status_code=401, detail="无效的 token")
    except JWTError as e:
        logger.error(f"JWT 解码失败: {e}")
        raise HTTPException(status_code=401, detail="token 已过期或无效")
    
    # 获取缓存的 session
    logger.info(f"获取缓存 session: student_id={student_id}")
    auth_service = get_cached_session(student_id)
    if not auth_service:
        logger.warning(f"未找到缓存 session: {student_id}")
        raise HTTPException(status_code=401, detail="会话已过期，请重新登录")
    
    session = auth_service.get_session()
    if not session:
        logger.warning(f"session 无效: {student_id}")
        raise HTTPException(
            status_code=401,
            detail="会话已过期，请重新登录"
        )
    
    return {
        "student_id": student_id,
        "session": session,
        "auth_service": auth_service,
    }

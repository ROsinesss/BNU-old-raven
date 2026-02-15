"""
认证路由
"""

from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException
from jose import jwt

from config import JWT_SECRET_KEY, JWT_ALGORITHM, JWT_EXPIRE_MINUTES
from models.schemas import LoginRequest, LoginResponse
from services.session_manager import get_or_create_session, invalidate_session

router = APIRouter(prefix="/api/auth", tags=["认证"])


@router.post("/login", response_model=LoginResponse)
async def login(req: LoginRequest):
    """用户登录"""
    auth_service = get_or_create_session(req.student_id, req.password)
    
    if not auth_service:
        raise HTTPException(status_code=401, detail="登录失败，请检查学号和密码")
    
    # 生成 JWT token
    expire = datetime.utcnow() + timedelta(minutes=JWT_EXPIRE_MINUTES)
    payload = {
        "sub": req.student_id,
        "exp": expire,
    }
    token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    
    return LoginResponse(
        token=token,
        student_id=req.student_id,
        name=auth_service.student_name or "未知",
        class_name=auth_service.class_name or "",
    )


@router.post("/logout")
async def logout(student_id: str):
    """用户登出"""
    invalidate_session(student_id)
    return {"message": "已登出"}

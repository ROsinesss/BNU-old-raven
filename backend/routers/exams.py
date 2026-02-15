"""
考试安排路由
"""

from fastapi import APIRouter, Depends

from models.schemas import ExamsResponse
from services.exams import fetch_exams
from routers.deps import get_current_session

router = APIRouter(prefix="/api", tags=["考试"])


@router.get("/exams", response_model=ExamsResponse)
async def get_exams(session_info=Depends(get_current_session)):
    """获取考试安排"""
    session = session_info["session"]
    result = fetch_exams(session)
    return result

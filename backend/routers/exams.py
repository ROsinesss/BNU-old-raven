"""
考试安排路由
"""

from fastapi import APIRouter, Depends, Query

from models.schemas import ExamsResponse
from services.exams import fetch_exams
from routers.deps import get_current_session

router = APIRouter(prefix="/api", tags=["考试"])


@router.get("/exams", response_model=ExamsResponse)
async def get_exams(
    year: int = Query(0, description="学年起始年份，0=当前"),
    semester: int = Query(-1, description="学期：-1=当前, 0=秋季, 1=春季"),
    session_info=Depends(get_current_session),
):
    """获取考试安排"""
    session = session_info["session"]
    student_id = session_info["student_id"]
    result = fetch_exams(session, student_id=student_id, year=year, semester=semester)
    return result

"""
成绩路由
"""

from fastapi import APIRouter, Depends

from models.schemas import GradesResponse
from services.grades import fetch_grades
from routers.deps import get_current_session

router = APIRouter(prefix="/api", tags=["成绩"])


@router.get("/grades", response_model=GradesResponse)
async def get_grades(year: int = 0, year_end: int = 0, semester: int = -1,
                     session_info=Depends(get_current_session)):
    """
    获取成绩
    
    - year: 学年起始年份，0=全部
    - year_end: 学年结束年份
    - semester: -1=全部, 0=秋季, 1=春季
    """
    session = session_info["session"]
    
    result = fetch_grades(session, year=year, year_end=year_end, semester=semester)
    return result

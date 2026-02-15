"""
学期信息路由
"""

from fastapi import APIRouter, Query

from services.semester import fetch_semester_info

router = APIRouter(prefix="/api", tags=["学期"])


@router.get("/semester-info")
async def get_semester_info(
    year: int = Query(0, description="学年起始年份，0=自动"),
    semester: int = Query(-1, description="学期：-1=自动, 0=秋季, 1=春季"),
):
    """获取学期信息（学期开始日期、当前周次）— 无需认证（纯日期计算）"""
    return fetch_semester_info(year=year, semester=semester)

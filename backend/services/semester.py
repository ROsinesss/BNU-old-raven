"""
学期信息服务

由于教务系统页面全部 JS 渲染，无法服务端提取当前周次。
采用硬编码的北师大校历学期起始日期 + 当前日期来计算当前教学周。
"""

import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

# ---- 北师大校历：已知学期第一周的周一日期 ----
# key = (学年起始年份, 学期代号)  学期: 0=秋, 1=春
SEMESTER_STARTS: dict[tuple[int, int], str] = {
    (2023, 0): "2023-09-11",  # 2023-2024 秋季 (9月15日附近周一)
    (2023, 1): "2024-03-04",  # 2023-2024 春季 (3月第一个周一)
    (2024, 0): "2024-09-09",  # 2024-2025 秋季 (9月15日附近周一)
    (2024, 1): "2025-03-03",  # 2024-2025 春季 (3月第一个周一)
    (2025, 0): "2025-09-15",  # 2025-2026 秋季 (9月15日是周一)
    (2025, 1): "2026-03-02",  # 2025-2026 春季 (3月第一个周一)
    (2026, 0): "2026-09-07",  # 2026-2027 秋季 (9月7日开学)
}


def _guess_semester_start(year: int, semester: int) -> str:
    """
    若查找表中没有，根据惯例估算学期第一周周一:
    - 秋季: 该年9月第一个周一
    - 春季: 次年2月最后一个周一
    """
    if semester == 0:
        # 秋季：9月15日附近的周一
        sep15 = datetime(year, 9, 15)
        if sep15.weekday() == 0:
            monday = sep15  # 如果就是周一
        elif sep15.weekday() <= 3:
            # 周二-周四：往前找到周一
            monday = sep15 - timedelta(days=sep15.weekday())
        else:
            # 周五-周日：往后找到周一
            monday = sep15 + timedelta(days=(7 - sep15.weekday()))
    else:
        # 春季：3月第一个周一（次年）
        spring_year = year + 1
        mar1 = datetime(spring_year, 3, 1)
        # 找到3月1日当周或之后的第一个周一
        if mar1.weekday() == 0:
            monday = mar1
        else:
            monday = mar1 + timedelta(days=(7 - mar1.weekday()))

    return monday.strftime("%Y-%m-%d")


def get_semester_start(year: int, semester: int) -> str:
    """获取学期开始日期（第一周周一）"""
    key = (year, semester)
    if key in SEMESTER_STARTS:
        return SEMESTER_STARTS[key]
    return _guess_semester_start(year, semester)


def detect_current_semester() -> tuple[int, int]:
    """根据当前日期自动判断学期: 返回 (学年起始年份, 学期代号)
    
    假期时自动返回下一学期:
    - 1-2月(寒假): 返回春季学期
    - 7-8月(暑假): 返回秋季学期
    """
    now = datetime.now()
    if now.month >= 9:
        return now.year, 0  # 秋季
    elif now.month <= 2:
        return now.year - 1, 1  # 寒假 → 春季
    elif now.month <= 6:
        return now.year - 1, 1  # 春季
    else:
        return now.year, 0  # 暑假 → 秋季


def fetch_semester_info(session=None, year: int = 0, semester: int = -1) -> dict:
    """
    获取学期信息

    Args:
        session: 未使用（保留兼容性）
        year: 学年起始年份，0=自动
        semester: -1=自动, 0=秋, 1=春

    Returns:
        {
            "semester_start": "2025-09-01",
            "current_week": 3,
            "semester_label": "2025-2026学年秋季学期",
            "year": 2025,
            "semester": 0,
        }
    """
    # 自动检测学期
    if year <= 0 or semester < 0:
        year, semester = detect_current_semester()

    start_str = get_semester_start(year, semester)
    start_date = datetime.strptime(start_str, "%Y-%m-%d")

    # 计算当前教学周
    now = datetime.now()
    diff_days = (now - start_date).days
    if diff_days >= 0:
        current_week = diff_days // 7 + 1
        current_week = min(current_week, 25)  # 上限
    else:
        current_week = 1  # 未到开学

    # 学期标签
    sem_name = "秋季" if semester == 0 else "春季"
    label = f"{year}-{year + 1}学年{sem_name}学期"

    result = {
        "semester_start": start_str,
        "current_week": current_week,
        "semester_label": label,
        "year": year,
        "semester": semester,
    }

    logger.info(f"学期信息: {label}, 第{current_week}周, 起始={start_str}")
    return result

"""
课表数据抓取与解析

数据来源：/wsxk/xkjg.ckdgxsxdkchj_data10319.jsp
请求方式：GET
参数：params=Base64(xn=年份&xq=学期号), t=安全token
响应：GBK 编码的 HTML 表格

上课时间地点格式示例：
  "1-3,8周 三[5-6] 在线教学(400)"
  "5-6周 四[9-10] 八101(210),7-9周 五[3-4] 八101(210)"
  "1-15周 一[9-11] 七202(80),1-15周 一[12] 七202(80)"
"""

import re
import base64
import logging
from typing import Optional

import requests
from bs4 import BeautifulSoup

from config import vpn_url, SCHEDULE_DATA_PATH, SCHEDULE_PAGE_PATH

# 教务系统要求 Referer 头
EDU_REFERER = {"Referer": vpn_url("frame/homes.html")}
from models.schemas import Course, ScheduleSlot, ScheduleResponse

logger = logging.getLogger(__name__)

# 星期映射
DAY_MAP = {
    "一": 1, "二": 2, "三": 3, "四": 4,
    "五": 5, "六": 6, "日": 7, "七": 7,
}

# 上课时间地点的正则
# 匹配：1-3,8周 三[5-6] 在线教学(400)
TIME_LOCATION_PATTERN = re.compile(
    r'([\d,\-]+)周\s*'           # 周次：1-3,8
    r'([一二三四五六日七])'        # 星期：三
    r'\[(\d+(?:-\d+)?)\]\s*'     # 节次：[5-6] 或 [12]
    r'([^(]+)'                   # 教室：在线教学
    r'\((\d+)\)'                 # 容量：(400)
)


def parse_weeks(weeks_str: str) -> list[int]:
    """
    解析周次字符串
    "1-3,8" → [1, 2, 3, 8]
    "1-15" → [1, 2, ..., 15]
    """
    weeks = []
    for part in weeks_str.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start, end = part.split("-", 1)
            weeks.extend(range(int(start), int(end) + 1))
        else:
            weeks.append(int(part))
    return sorted(set(weeks))


def parse_time_location(raw_text: str) -> list[ScheduleSlot]:
    """
    解析上课时间地点文本，返回 ScheduleSlot 列表

    输入示例：
      "1-3,8周 三[5-6] 在线教学(400),4周 三[5-6] 二101(210)"
    """
    slots = []
    
    # 按逗号分割，但要注意逗号可能在周次内部（如 1-3,8周）
    # 使用正则直接匹配所有时间段
    matches = TIME_LOCATION_PATTERN.findall(raw_text)
    
    for match in matches:
        weeks_str, day_str, section_str, classroom, capacity = match
        
        weeks = parse_weeks(weeks_str)
        day = DAY_MAP.get(day_str, 0)
        
        # 解析节次
        if "-" in section_str:
            start, end = section_str.split("-", 1)
            start_section = int(start)
            end_section = int(end)
        else:
            start_section = end_section = int(section_str)
        
        slots.append(ScheduleSlot(
            weeks=weeks,
            day_of_week=day,
            start_section=start_section,
            end_section=end_section,
            classroom=classroom.strip(),
            capacity=int(capacity),
        ))
    
    return slots


def get_schedule_token(session: requests.Session) -> str:
    """从课表页面获取安全 token"""
    try:
        page_url = vpn_url(SCHEDULE_PAGE_PATH)
        resp = session.get(page_url, timeout=15, headers=EDU_REFERER)
        resp.encoding = "gbk"
        
        # 从页面 JS 中提取 token
        # 通常在 getToken 调用或隐藏字段中
        token_match = re.search(r'["\']([A-F0-9]{64,})["\']', resp.text)
        if token_match:
            return token_match.group(1)
        
        # 尝试从 cookie 或其他方式获取
        token_match = re.search(r'token["\s:=]+["\']?([^"\'&\s]+)', resp.text)
        if token_match:
            return token_match.group(1)
        
        # 尝试从 t= 参数中提取
        token_match = re.search(r't=([A-Za-z0-9+/=]{20,})', resp.text)
        if token_match:
            return token_match.group(1)
            
    except Exception as e:
        logger.warning(f"获取课表 token 失败: {e}")
    
    return ""


def fetch_schedule(session: requests.Session, year: int = 2025,
                   semester: int = 1, token: str = "") -> ScheduleResponse:
    """
    获取课表数据
    
    Args:
        session: 已登录的 requests.Session
        year: 学年起始年份
        semester: 0=秋季, 1=春季
        token: 安全 token
    """
    # 构造 params 参数（Base64 编码）
    params_raw = f"xn={year}&xq={semester}"
    params_b64 = base64.b64encode(params_raw.encode()).decode()
    
    # 如果没有 token，尝试获取
    if not token:
        token = get_schedule_token(session)
    
    # 构造请求 URL
    query = f"params={params_b64}"
    if token:
        query += f"&t={token}"
    
    url = vpn_url(f"{SCHEDULE_DATA_PATH}?{query}")
    
    logger.info(f"请求课表：year={year}, semester={semester}")
    
    try:
        resp = session.get(url, timeout=15, headers=EDU_REFERER)
        resp.encoding = "gbk"
        
        if resp.status_code != 200:
            logger.error(f"课表请求失败: HTTP {resp.status_code}")
            return ScheduleResponse()
        
        return parse_schedule_html(resp.text)
    
    except Exception as e:
        logger.exception(f"获取课表失败: {e}")
        return ScheduleResponse()


def parse_schedule_html(html: str) -> ScheduleResponse:
    """解析课表 HTML 页面"""
    soup = BeautifulSoup(html, "lxml")
    response = ScheduleResponse()
    
    # 提取学期标签
    semester_el = soup.find("font", style=lambda s: s and "font-size:13px" in s)
    if semester_el:
        response.semester_label = semester_el.get_text(strip=True).strip("（）()")
    
    # 提取学生信息
    divs = soup.find_all("div", style=lambda s: s and "float:left" in str(s))
    for div in divs:
        text = div.get_text(strip=True)
        if text.startswith("学号"):
            response.student_id = text.split("：")[-1].split(":")[-1].strip()
        elif text.startswith("姓名"):
            response.student_name = text.split("：")[-1].split(":")[-1].strip()
        elif text.startswith("所在班级"):
            response.class_name = text.split("：")[-1].split(":")[-1].strip()
    
    # 提取课程总数和总学分
    right_div = soup.find("div", style=lambda s: s and "float:right" in str(s))
    if right_div:
        text = right_div.get_text()
        count_match = re.search(r'课程门数[：:](\d+)', text)
        credits_match = re.search(r'总学分[：:](\d+\.?\d*)', text)
        if count_match:
            response.total_courses = int(count_match.group(1))
        if credits_match:
            response.total_credits = float(credits_match.group(1))
    
    # 解析课程表格
    table = soup.find("table")
    if not table:
        logger.warning("未找到课表表格")
        return response
    
    tbody = table.find("tbody")
    if not tbody:
        tbody = table
    
    rows = tbody.find_all("tr")
    courses = []
    
    for row in rows:
        cells = row.find_all("td")
        if len(cells) < 6:
            continue
        
        # 提取可见单元格的文本
        visible_cells = [
            td for td in cells
            if not td.get("style") or "display: none" not in td.get("style", "")
        ]
        
        if len(visible_cells) < 6:
            continue
        
        # 解析课程号和课程名
        course_text = visible_cells[0].get_text(strip=True)
        course_id_match = re.match(r'\[([^\]]+)\](.+)', course_text)
        
        if course_id_match:
            course_id = course_id_match.group(1)
            course_name = course_id_match.group(2)
        else:
            course_id = ""
            course_name = course_text
        
        # 上课时间地点
        raw_time_location = visible_cells[5].get_text(strip=True)
        slots = parse_time_location(raw_time_location)
        
        # 教师列表
        teachers_text = visible_cells[4].get_text(strip=True)
        teachers = [t.strip() for t in teachers_text.split(";") if t.strip()]
        
        course = Course(
            course_id=course_id,
            course_name=course_name,
            total_hours=_safe_int(visible_cells[1].get_text(strip=True)),
            credits=_safe_float(visible_cells[2].get_text(strip=True)),
            class_number=visible_cells[3].get_text(strip=True),
            teachers=teachers,
            slots=slots,
            course_type=visible_cells[6].get_text(strip=True) if len(visible_cells) > 6 else "",
            is_minor=visible_cells[7].get_text(strip=True) if len(visible_cells) > 7 else "",
            raw_time_location=raw_time_location,
        )
        courses.append(course)
    
    response.courses = courses
    return response


def _safe_int(s: str) -> int:
    try:
        return int(s)
    except (ValueError, TypeError):
        return 0


def _safe_float(s: str) -> float:
    try:
        return float(s)
    except (ValueError, TypeError):
        return 0.0

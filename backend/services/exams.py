"""
考试安排数据抓取与解析

数据来源：POST /taglib/DataTable.jsp?tableId=2538
参数：form data (xh, xn, xq, kslc, xnxqkslc, menucode_current)
响应：GBK 编码的 HTML 表格
表头：序号、课程、学分、类别、考核方式、考试时间、考试地点、座位号

注意：VPN/教务系统对 DataTable.jsp 有请求限制，
大约 4 次成功请求后就不再返回数据。
因此需要做 session 级缓存——同一 session 同一学期只抓一次。
"""

import re
import logging
import time
from typing import Optional

import requests
from bs4 import BeautifulSoup

from config import vpn_url, EXAM_PATH

# 教务系统要求 Referer 头
EDU_REFERER = {"Referer": vpn_url("frame/homes.html")}
KSAP_REFERER = {"Referer": vpn_url("student/ksap.ksapb.html")}
from models.schemas import Exam, ExamsResponse

logger = logging.getLogger(__name__)

# ---- 缓存：key = (student_id, year, semester) ----
_exam_cache: dict[tuple[str, int, int], ExamsResponse] = {}


def fetch_exams(session: requests.Session, student_id: str = "",
                table_id: str = "2538", year: int = 0,
                semester: int = -1) -> ExamsResponse:
    """
    获取考试安排，遍历所有考试轮次并合并结果。
    结果会被缓存，相同 (student_id, year, semester) 不再重复请求。

    Args:
        session: 已登录的 requests.Session
        student_id: 学号 (xh)
        table_id: DataTable 的 ID
        year: 学年起始年份，0=当前
        semester: -1=当前, 0=秋季, 1=春季
    """
    # 确定学年学期
    if year <= 0 or semester < 0:
        from datetime import datetime
        now = datetime.now()
        if now.month >= 9:
            year = now.year
            semester = 0  # 秋季
        elif now.month <= 2:
            year = now.year - 1
            semester = 0  # 秋季（上学年）
        else:
            year = now.year - 1
            semester = 1  # 春季

    # 检查缓存
    cache_key = (student_id, year, semester)
    if cache_key in _exam_cache:
        cached = _exam_cache[cache_key]
        logger.info(f"考试数据命中缓存: {student_id} {year}/{semester}, "
                    f"{len(cached.exams)} 条")
        return cached

    # 先访问考试安排页面建立上下文
    try:
        session.get(vpn_url("student/ksap.ksapb.html"), timeout=10,
                    headers=EDU_REFERER)
    except Exception:
        pass

    all_exams = []

    # 只遍历有数据的考试轮次: 1(随堂考试/考查) 和 3(期末考试)
    # kslc=2 和 kslc=4 在实际测试中始终返回空，跳过以避免浪费请求配额
    for kslc in [1, 3]:
        # 每个轮次前重新访问考试页面，刷新 VPN 上下文
        try:
            session.get(vpn_url("student/ksap.ksapb.html"), timeout=10,
                        headers=EDU_REFERER)
        except Exception:
            pass

        # 轮次间较长延迟，避免 VPN 限流
        if kslc > 1:
            time.sleep(2.0)

        # 使用 POST 表单提交，与浏览器行为一致
        url = vpn_url(f"{EXAM_PATH}?tableId={table_id}")
        form_data = {
            "xh": student_id,
            "xn": str(year),
            "xq": str(semester),
            "kslc": str(kslc),
            "xnxqkslc": f"{year},{semester},{kslc}",
            "menucode_current": "JW130603",
        }

        try:
            resp = session.post(url, data=form_data, timeout=15,
                                headers=KSAP_REFERER)
            resp.encoding = "gbk"

            if resp.status_code != 200:
                continue

            exams = parse_exams_html(resp.text)
            all_exams.extend(exams)
            logger.info(f"考试轮次 kslc={kslc}: {len(exams)} 条")

        except Exception as e:
            logger.warning(f"获取考试轮次 kslc={kslc} 失败: {e}")

    result = ExamsResponse(exams=all_exams)

    # 写入缓存（即使为空也缓存，避免反复请求触发限制）
    if all_exams:
        _exam_cache[cache_key] = result
        logger.info(f"考试数据已缓存: {student_id} {year}/{semester}, "
                    f"{len(all_exams)} 条")
    # 空结果不缓存，下次可重试

    return result


def clear_exam_cache(student_id: str = ""):
    """清除考试缓存，student_id 为空则清除全部"""
    if not student_id:
        _exam_cache.clear()
        return
    keys_to_remove = [k for k in _exam_cache if k[0] == student_id]
    for k in keys_to_remove:
        del _exam_cache[k]


def parse_exams_html(html: str) -> list[Exam]:
    """解析考试安排 HTML，返回 Exam 列表"""
    soup = BeautifulSoup(html, "lxml")
    exams = []

    if "没有检索到记录" in html or "暂无" in html:
        return exams

    table = soup.find("table")
    if not table:
        return exams

    # 获取表头
    header_cells = []
    first_row = table.find("tr")
    if first_row:
        header_cells = [td.get_text(strip=True) for td in first_row.find_all(["td", "th"])]

    # 构建列索引映射
    col_map = _build_column_map(header_cells)

    rows = table.find_all("tr")
    for row in rows[1:] if header_cells else rows:  # 跳过表头行
        cells = row.find_all("td")
        if len(cells) < 3:
            continue

        texts = [td.get_text(strip=True) for td in cells]

        # 跳过空行或表头行
        if not any(texts) or "序号" in texts[0] or "课程" in texts[0]:
            continue

        exam = _parse_exam_row_by_map(texts, col_map)
        if exam:
            exams.append(exam)

    return exams


def _build_column_map(headers: list[str]) -> dict[str, int]:
    """根据表头构建列名到索引的映射"""
    col_map = {}
    keywords = {
        "序号": "index",
        "课程": "course",
        "学分": "credits",
        "类别": "category",
        "考核方式": "exam_type",
        "考试时间": "exam_time",
        "时间": "exam_time",
        "考试地点": "location",
        "地点": "location",
        "考场": "location",
        "座位号": "seat",
        "座位": "seat",
    }
    for i, h in enumerate(headers):
        for kw, key in keywords.items():
            if kw in h and key not in col_map:
                col_map[key] = i
                break
    return col_map


def _parse_exam_row_by_map(texts: list[str], col_map: dict[str, int]) -> Optional[Exam]:
    """根据列映射解析一行考试数据"""
    try:
        def get(key: str) -> str:
            idx = col_map.get(key, -1)
            if 0 <= idx < len(texts):
                return texts[idx]
            return ""

        course_name = get("course")
        if not course_name:
            # 回退：尝试跳过序号列
            offset = 1 if texts[0].isdigit() and len(texts[0]) <= 3 else 0
            course_name = texts[offset] if offset < len(texts) else ""

        if not course_name:
            return None

        exam = Exam(
            course_name=course_name,
            credits=get("credits"),
            category=get("category"),
            exam_type=get("exam_type"),
            exam_time=get("exam_time"),
            exam_location=get("location"),
            seat_number=get("seat"),
        )

        # 回退：如果没有通过列映射找到考试时间，尝试正则匹配
        if not exam.exam_time:
            for t in texts:
                if re.search(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}', t):
                    exam.exam_time = t
                    break

        return exam

    except Exception as e:
        logger.warning(f"解析考试行失败: {e}")
        return None

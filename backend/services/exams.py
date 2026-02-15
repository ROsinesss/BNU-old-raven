"""
考试安排数据抓取与解析

数据来源：GET /taglib/DataTable.jsp?tableId=2538（需进一步确认参数）
响应：GBK 编码的 HTML 表格
"""

import re
import logging
from typing import Optional

import requests
from bs4 import BeautifulSoup

from config import vpn_url, EXAM_PATH

# 教务系统要求 Referer 头
EDU_REFERER = {"Referer": vpn_url("frame/homes.html")}
from models.schemas import Exam, ExamsResponse

logger = logging.getLogger(__name__)


def fetch_exams(session: requests.Session, table_id: str = "2538",
                token: str = "") -> ExamsResponse:
    """
    获取考试安排

    Args:
        session: 已登录的 requests.Session
        table_id: DataTable 的 ID
        token: 安全 token
    """
    query = f"tableId={table_id}"
    if token:
        query += f"&t={token}"
    
    url = vpn_url(f"{EXAM_PATH}?{query}")
    
    logger.info("请求考试安排")
    
    try:
        resp = session.get(url, timeout=15, headers=EDU_REFERER)
        resp.encoding = "gbk"
        
        if resp.status_code != 200:
            logger.error(f"考试安排请求失败: HTTP {resp.status_code}")
            return ExamsResponse()
        
        return parse_exams_html(resp.text)
    
    except Exception as e:
        logger.exception(f"获取考试安排失败: {e}")
        return ExamsResponse()


def parse_exams_html(html: str) -> ExamsResponse:
    """解析考试安排 HTML"""
    soup = BeautifulSoup(html, "lxml")
    response = ExamsResponse()
    
    if "没有检索到记录" in html or "暂无" in html:
        return response
    
    table = soup.find("table")
    if not table:
        return response
    
    tbody = table.find("tbody")
    if not tbody:
        tbody = table
    
    rows = tbody.find_all("tr")
    exams = []
    
    for row in rows:
        cells = row.find_all("td")
        if len(cells) < 3:
            continue
        
        texts = [td.get_text(strip=True) for td in cells]
        
        # 跳过表头
        if any(k in texts[0] for k in ["序号", "考试", "课程"]):
            continue
        
        exam = _parse_exam_row(texts)
        if exam:
            exams.append(exam)
    
    response.exams = exams
    return response


def _parse_exam_row(texts: list[str]) -> Optional[Exam]:
    """解析考试安排的一行"""
    try:
        # 典型字段：序号、考试场次、课程名称、考核方式、考试形式、考试时间、考场、座位号、准考证号、备注
        offset = 0
        if texts[0].isdigit() and len(texts[0]) <= 3:
            offset = 1
        
        exam = Exam()
        
        # 尝试提取课程名称
        if offset + 1 < len(texts):
            # 可能是「场次」或直接就是课程名
            candidate = texts[offset]
            if any(c.isdigit() for c in candidate) and len(candidate) <= 5:
                # 可能是场次号，课程名在下一列
                offset += 1
            exam.course_name = texts[offset] if offset < len(texts) else ""
        
        # 尝试提取考试类型
        for i, t in enumerate(texts):
            if t in ["考试", "考查", "机试", "开卷", "闭卷"]:
                exam.exam_type = t
        
        # 尝试提取考试时间（匹配日期格式）
        for t in texts:
            if re.search(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}', t):
                exam.exam_time = t
                break
        
        # 尝试提取考试地点
        for i, t in enumerate(texts):
            if any(k in t for k in ["教室", "楼", "座", "机房", "实验"]) or re.match(r'[一-龥]+\d+', t):
                exam.exam_location = t
                break
        
        # 尝试提取座位号
        for t in texts:
            if re.match(r'^\d{1,3}$', t) and t != texts[0]:
                exam.seat_number = t
        
        if exam.course_name:
            return exam
    
    except Exception as e:
        logger.warning(f"解析考试行失败: {e}")
    
    return None

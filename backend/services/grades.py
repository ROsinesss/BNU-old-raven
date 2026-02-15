"""
成绩数据抓取与解析

流程（模拟浏览器操作 "学业成绩" 页面）：
1. GET homes.html → 建立教务上下文
2. GET student/xscj.stuckcj.jsp → 成绩查询主页面
3. GET student/xscj.stuckcj.my.jsp → 隐藏 iframe（token 初始化）
4. POST frame/menus/js/SetTokenkey.jsp → 获取 kingoKey token
5. POST student/xscj.stuckcj_data.jsp → 提交查询表单

数据表格列：
  学年学期 | 课程/环节 | 学分 | 类别 | 课程性质 | 考核方式 | 修读性质
  | 平时成绩 | 期末成绩 | 综合成绩 | 辅修标记 | 备注
"""

import re
import logging

import requests
from bs4 import BeautifulSoup

from config import (
    vpn_url,
    GRADES_DATA_PATH,
    GRADES_PAGE_PATH,
    GRADES_MY_PATH,
    SET_TOKEN_PATH,
    HOME_PATH,
)
from models.schemas import Grade, GradesResponse

logger = logging.getLogger(__name__)

EDU_REFERER = {"Referer": vpn_url("frame/homes.html")}


def _get_grades_token(session: requests.Session) -> str:
    """
    获取成绩查询所需的 token（kingoKey）。

    完整流程：访问主页面 → 访问隐藏 iframe → 调用 SetTokenkey 获取 token
    """
    page_url = vpn_url(GRADES_PAGE_PATH)
    my_url = vpn_url(GRADES_MY_PATH)
    token_url = vpn_url(SET_TOKEN_PATH)

    try:
        # 1. 访问主页面（建立页面上下文）
        session.get(page_url, timeout=15, headers=EDU_REFERER)

        # 2. 访问隐藏 iframe（模拟浏览器加载）
        session.get(my_url, timeout=15, headers={"Referer": page_url})

        # 3. 获取主页面 token（setFoken，非必需但模拟完整流程）
        session.post(
            token_url,
            data="menucode=xscj.stuckcj.jsp",
            headers={
                "Referer": page_url,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            timeout=15,
        )

        # 4. 获取 iframe token（setToken → kingoKey，用于表单提交）
        resp = session.post(
            token_url,
            data="menucode=xscj.stuckcj.my.jsp",
            headers={
                "Referer": my_url,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            timeout=15,
        )

        token = resp.text.strip()
        if token and not token.startswith("<"):
            logger.info(f"成绩 token 获取成功: {token[:20]}...")
            return token
        else:
            logger.warning(f"成绩 token 无效: {token[:60]}")
            return ""

    except Exception as e:
        logger.warning(f"获取成绩 token 失败: {e}")
        return ""


def fetch_grades(session: requests.Session, year: int = 0,
                 year_end: int = 0, semester: int = -1,
                 token: str = "") -> GradesResponse:
    """
    获取成绩数据

    Args:
        session: 已登录的 requests.Session
        year: 学年起始年份，0=全部（入学以来）
        year_end: 学年结束年份
        semester: -1=全部, 0=秋季, 1=春季
        token: token（可选，会自动获取）
    """
    # 访问 homes.html 确保上下文
    try:
        session.get(vpn_url(HOME_PATH), timeout=15)
    except Exception:
        pass

    # 获取 token
    if not token:
        token = _get_grades_token(session)

    if not token:
        logger.warning("无法获取成绩 token，尝试无 token 查询")

    # 构建表单数据
    # 根据查询类型选择 sjxz：
    #   sjxz1 = 入学以来（xn/xq disabled，不发送）
    #   sjxz2 = 学年（xq disabled）
    #   sjxz3 = 学期（xn/xq 均启用）
    page_url = vpn_url(GRADES_PAGE_PATH)

    if year == 0 and semester == -1:
        # 入学以来：不发送 xn 和 xq
        form_data = {
            "sjxz": "sjxz1",
            "ysyx": "yscj",
            "zfx": "0",
            "t": token,
            "xn1": "",
            "sjxzS": "on",
            "ysyxS": "on",
            "zfxS": "on",
        }
    elif semester == -1:
        # 按学年查（不发送 xq）
        form_data = {
            "sjxz": "sjxz2",
            "ysyx": "yscj",
            "zfx": "0",
            "t": token,
            "xn": str(year),
            "xn1": str(year_end) if year_end > 0 else str(year + 1),
            "sjxzS": "on",
            "ysyxS": "on",
            "zfxS": "on",
        }
    else:
        # 按学期查
        form_data = {
            "sjxz": "sjxz3",
            "ysyx": "yscj",
            "zfx": "0",
            "t": token,
            "xn": str(year) if year > 0 else "",
            "xn1": str(year_end) if year_end > 0 else (str(year + 1) if year > 0 else ""),
            "xq": str(semester),
            "sjxzS": "on",
            "ysyxS": "on",
            "zfxS": "on",
        }

    url = vpn_url(GRADES_DATA_PATH)
    grades_referer = {"Referer": page_url}

    logger.info(f"查询成绩: sjxz={form_data['sjxz']}, year={year}, semester={semester}")

    try:
        resp = session.post(url, data=form_data, timeout=15, headers=grades_referer)
        resp.encoding = "gbk"

        if resp.status_code != 200:
            logger.warning(f"成绩请求失败: HTTP {resp.status_code}")
            return GradesResponse()

        return parse_grades_html(resp.text)

    except Exception as e:
        logger.exception(f"获取成绩失败: {e}")
        return GradesResponse()


def _score_to_gpa(score_str: str) -> float:
    """
    将成绩转换为 4.0 制绩点

    数值成绩使用通用转换：
      90-100 → 4.0, 85-89 → 3.7, 82-84 → 3.3,
      78-81 → 3.0, 75-77 → 2.7, 72-74 → 2.3,
      68-71 → 2.0, 64-67 → 1.5, 60-63 → 1.0,
      <60 → 0.0

    等级成绩：
      优秀 → 4.0, 良好 → 3.0, 中等 → 2.0, 及格 → 1.0,
      合格 → 0 (通常不计入 GPA), 不及格 → 0.0
    """
    score_str = score_str.strip()

    # 尝试解析数值
    try:
        score = float(score_str)
        if score >= 90:
            return 4.0
        elif score >= 85:
            return 3.7
        elif score >= 82:
            return 3.3
        elif score >= 78:
            return 3.0
        elif score >= 75:
            return 2.7
        elif score >= 72:
            return 2.3
        elif score >= 68:
            return 2.0
        elif score >= 64:
            return 1.5
        elif score >= 60:
            return 1.0
        else:
            return 0.0
    except (ValueError, TypeError):
        pass

    # 等级成绩
    grade_map = {
        "优秀": 4.0, "优": 4.0,
        "良好": 3.0, "良": 3.0,
        "中等": 2.0, "中": 2.0,
        "及格": 1.0,
        "合格": 0.0,  # 通常不计入 GPA
        "不及格": 0.0, "不合格": 0.0, "不通过": 0.0,
    }
    return grade_map.get(score_str, 0.0)


def parse_grades_html(html: str) -> GradesResponse:
    """
    解析成绩 HTML 页面。

    表格列（共 12 列）：
      0: 学年学期
      1: 课程/环节 → [课程号]课程名
      2: 学分
      3: 类别
      4: 课程性质
      5: 考核方式
      6: 修读性质
      7: 平时成绩
      8: 期末成绩
      9: 综合成绩
      10: 辅修标记
      11: 备注
    """
    response = GradesResponse()

    if not html or "没有检索到记录" in html:
        return response

    if "频繁" in html or "1分钟" in html:
        logger.warning("成绩查询被频率限制")
        return response

    soup = BeautifulSoup(html, "lxml")
    table = soup.find("table")
    if not table:
        return response

    tbody = table.find("tbody") or table
    rows = tbody.find_all("tr")

    grades = []
    current_semester = ""
    total_weighted_gpa = 0.0
    total_credits = 0.0

    for row in rows:
        cells = row.find_all("td")
        if len(cells) < 10:
            continue

        texts = [td.get_text(strip=True) for td in cells]

        # 跳过表头行
        if texts[0] == "学年学期" or texts[1] == "课程/环节":
            continue

        # 学年学期（可能为空 → 同上一行的学期）
        if texts[0]:
            current_semester = texts[0]

        # 课程名（格式：[GRA20038701]马克思主义与社会科学方法论）
        raw_course = texts[1]
        course_id = ""
        course_name = raw_course
        id_match = re.match(r'\[([^\]]+)\](.+)', raw_course)
        if id_match:
            course_id = id_match.group(1)
            course_name = id_match.group(2).strip()

        if not course_name:
            continue

        # 学分
        credits = _safe_float(texts[2])

        # 类别、课程性质、考核方式、修读性质
        category = texts[3]       # 研究生/公共选修
        nature = texts[4]         # 选修/必修
        exam_type = texts[5]      # 考试/考查
        study_type = texts[6]     # 初修/重修

        # 成绩
        regular_score = texts[7]   # 平时成绩
        final_score = texts[8]     # 期末成绩
        composite_score = texts[9] # 综合成绩

        # 辅修标记、备注
        remark = texts[11] if len(texts) > 11 else ""

        # 计算绩点
        gpa_point = _score_to_gpa(composite_score)

        grade = Grade(
            semester=current_semester,
            course_id=course_id,
            course_name=course_name,
            score=composite_score,
            credits=credits,
            gpa_point=gpa_point,
            exam_type=exam_type,
            course_category=category,
            course_nature=nature,
            regular_score=regular_score,
            final_score=final_score,
            study_type=study_type,
            remark=remark,
        )
        grades.append(grade)

        # GPA 累计（仅数值成绩且 > 0 参与计算，"合格"类不计入）
        if credits > 0 and gpa_point > 0:
            total_weighted_gpa += gpa_point * credits
            total_credits += credits

    response.grades = grades
    response.total_credits = total_credits
    if total_credits > 0:
        response.total_gpa = round(total_weighted_gpa / total_credits, 4)

    return response


def _safe_float(s: str) -> float:
    try:
        return float(s)
    except (ValueError, TypeError):
        return 0.0

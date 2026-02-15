"""
Pydantic 数据模型
"""

from typing import Optional

from pydantic import BaseModel


# ============ 请求模型 ============

class LoginRequest(BaseModel):
    student_id: str
    password: str


class ScheduleRequest(BaseModel):
    year: int = 2025       # 学年起始年份
    semester: int = 1      # 0=秋季, 1=春季


class GradesRequest(BaseModel):
    year: int = 0          # 0 = 全部
    year_end: int = 0
    semester: int = 0      # 0 = 全部


# ============ 响应模型 ============

class LoginResponse(BaseModel):
    token: str
    student_id: str
    name: str
    class_name: str = ""
    message: str = "登录成功"


class ScheduleSlot(BaseModel):
    """课表中的一个时间段"""
    weeks: list[int]           # 上课周次列表，如 [1,2,3,8]
    day_of_week: int           # 星期几 (1=周一, 7=周日)
    start_section: int         # 起始节次
    end_section: int           # 结束节次
    classroom: str             # 教室
    capacity: int = 0          # 教室容量


class Course(BaseModel):
    """课程信息"""
    course_id: str             # 课程号，如 EDU20202211
    course_name: str           # 课程名
    total_hours: int = 0       # 总学时
    credits: float = 0.0      # 学分
    class_number: str = ""     # 上课班号
    teachers: list[str] = []   # 任课教师列表
    slots: list[ScheduleSlot] = []  # 上课时间地点列表
    course_type: str = ""      # 修读性质（初修/重修等）
    is_minor: str = ""         # 辅修标识
    raw_time_location: str = ""  # 原始上课时间地点文本


class ScheduleResponse(BaseModel):
    semester_label: str = ""   # 学期标签，如 "2025-2026学年春季学期"
    student_id: str = ""
    student_name: str = ""
    class_name: str = ""
    total_courses: int = 0
    total_credits: float = 0.0
    courses: list[Course] = []


class Grade(BaseModel):
    """成绩记录"""
    semester: str = ""         # 学期，如 "2025-2026学年秋季学期"
    course_id: str = ""        # 课程号
    course_name: str = ""      # 课程名
    score: str = ""            # 综合成绩
    credits: float = 0.0      # 学分
    total_hours: int = 0       # 总学时
    gpa_point: float = 0.0    # 绩点
    exam_type: str = ""        # 考核方式（考试/考查）
    course_category: str = ""  # 课程类别（研究生/公共选修 等）
    course_nature: str = ""    # 课程性质（选修/必修）
    regular_score: str = ""    # 平时成绩
    final_score: str = ""      # 期末成绩
    study_type: str = ""       # 修读性质（初修/重修）
    remark: str = ""           # 备注（缺考 等）


class GradesResponse(BaseModel):
    grades: list[Grade] = []
    semester_gpa: float = 0.0
    total_gpa: float = 0.0
    total_credits: float = 0.0


class Exam(BaseModel):
    """考试安排"""
    course_name: str = ""
    exam_time: str = ""
    exam_location: str = ""
    seat_number: str = ""
    exam_type: str = ""


class ExamsResponse(BaseModel):
    exams: list[Exam] = []


class Semester(BaseModel):
    year: int
    year_end: int
    semester: int              # 0=秋季, 1=春季
    label: str                 # 显示标签


class SemestersResponse(BaseModel):
    semesters: list[Semester] = []
    current_year: int = 0
    current_semester: int = 0

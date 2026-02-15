"""
北师大教务系统 App 后端配置
"""

# WebVPN 配置
WEBVPN_HOST = "onevpn.bnu.edu.cn"
WEBVPN_LOGIN_URL = f"https://{WEBVPN_HOST}/login"
WEBVPN_KEY = b"wrdvpnisthebest!"
WEBVPN_IV = b"wrdvpnisthebest!"

# 教务系统域名（内网）
JWXT_DOMAIN = "zyfw.bnu.edu.cn"
JWXT_PROTOCOL = "http"

# 教务系统加密后的域名（预计算）
JWXT_ENCRYPTED_DOMAIN = "77726476706e69737468656265737421eaee478b69326645300d8db9d6562d"

# CAS 域名
CAS_DOMAIN = "cas.bnu.edu.cn"
CAS_ENCRYPTED_DOMAIN = "77726476706e69737468656265737421f3f652d2253e7d1e7b0c9ce29b5b"

# 教务系统接口路径（通过 WebVPN 代理）
def vpn_url(path: str) -> str:
    """构建通过 WebVPN 代理的教务系统 URL"""
    return f"https://{WEBVPN_HOST}/{JWXT_PROTOCOL}/{JWXT_ENCRYPTED_DOMAIN}/{path.lstrip('/')}"

def cas_vpn_url(path: str) -> str:
    """构建通过 WebVPN 代理的 CAS URL"""
    return f"https://{WEBVPN_HOST}/https/{CAS_ENCRYPTED_DOMAIN}/{path.lstrip('/')}"

# 教务系统页面路径
SCHEDULE_DATA_PATH = "wsxk/xkjg.ckdgxsxdkchj_data10319.jsp"
GRADES_PAGE_PATH = "student/xscj.stuckcj.jsp"
GRADES_MY_PATH = "student/xscj.stuckcj.my.jsp"
GRADES_DATA_PATH = "student/xscj.stuckcj_data.jsp"
SET_TOKEN_PATH = "frame/menus/js/SetTokenkey.jsp"
SCHEDULE_PAGE_PATH = "student/xkjg.wdkb.jsp"
YEAR_TERM_PATH = "jw/common/showYearTerm.action"
EXAM_PATH = "taglib/DataTable.jsp"
HOME_PATH = "frame/homes.html"

# JWT 配置
JWT_SECRET_KEY = "bnu-schedule-app-secret-key-change-in-production"
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 1440  # 24 小时

# 请求头
DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
}

"""
onevpn 统一身份认证登录服务

流程：
1. GET onevpn.bnu.edu.cn/login → 被重定向到 CAS 登录页
2. 解析 CAS 表单：提取 lt、execution
3. 使用 DES 加密 (username + password + lt) → rsa 字段
4. POST secondAuth 预验证凭据 (AJAX)
5. 预验证通过后 POST loginForm 完成登录
6. CAS 验证通过 → 重定向回 WebVPN → session 获得 VPN ticket
"""

import re
import random
import logging
from typing import Optional
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

from config import (
    WEBVPN_HOST,
    WEBVPN_LOGIN_URL,
    DEFAULT_HEADERS,
    HOME_PATH,
    SCHEDULE_DATA_PATH,
    vpn_url,
    cas_vpn_url,
)
from utils.cas_des import str_enc

logger = logging.getLogger(__name__)


class AuthService:
    """onevpn 登录认证服务"""
    
    def __init__(self):
        self.session: Optional[requests.Session] = None
        self.student_id: str = ""
        self.student_name: str = ""
        self.class_name: str = ""
        self.is_logged_in: bool = False
    
    def login(self, student_id: str, password: str) -> dict:
        """
        登录 onevpn 统一身份认证（两步流程）
        
        Returns:
            dict: {"success": bool, "message": str, "name": str, "class_name": str}
        """
        self.session = requests.Session()
        self.session.headers.update(DEFAULT_HEADERS)
        self.student_id = student_id
        
        try:
            # ── Step 1: 获取 CAS 登录页面 ──
            logger.info("正在获取 CAS 登录页面...")
            resp = self.session.get(WEBVPN_LOGIN_URL, timeout=15)
            resp.raise_for_status()
            cas_page_url = resp.url  # 记住 CAS 页面的完整 URL
            
            soup = BeautifulSoup(resp.text, "lxml")
            lt = self._get_input_value(soup, "lt")
            execution = self._get_input_value(soup, "execution")
            
            if not lt:
                logger.error("未能获取 lt 参数")
                return {"success": False, "message": "无法解析登录页面（缺少 lt）"}
            
            # ── Step 2: DES 加密 ──
            rsa = str_enc(student_id + password + lt, "1", "2", "3")
            ul = str(len(student_id))
            pl = str(len(password))
            
            # ── Step 3: 构造 secondAuth URL（相对于 CAS 页面） ──
            # CAS 页面 URL 形如: .../cas/login?service=...
            # secondAuth 相对路径解析为: .../cas/secondAuth
            cas_base = cas_page_url.split("?")[0]  # 去掉 query string
            # 去掉 ;jsessionid=xxx
            cas_base = cas_base.split(";")[0]
            # 把 /login 替换为 /secondAuth
            if cas_base.endswith("/login"):
                second_auth_url = cas_base[:-6] + "/secondAuth"
            else:
                second_auth_url = cas_base.rsplit("/", 1)[0] + "/secondAuth"
            
            logger.info(f"secondAuth URL: {second_auth_url}")
            
            # ── Step 4: POST secondAuth 预验证 ──
            second_auth_data = (
                f"method=check"
                f"&captcha="
                f"&ul={ul}"
                f"&pl={pl}"
                f"&rsa={rsa}"
                f"&random={random.random()}"
            )
            
            second_auth_headers = {
                "Content-Type": "application/x-www-form-urlencoded",
                "Origin": f"https://{WEBVPN_HOST}",
                "Referer": cas_page_url,
                "X-Requested-With": "XMLHttpRequest",
            }
            
            logger.info("正在调用 secondAuth 预验证...")
            resp_sa = self.session.post(
                second_auth_url,
                data=second_auth_data,
                headers=second_auth_headers,
                timeout=15,
            )
            
            logger.info(f"secondAuth 响应: {resp_sa.status_code} {resp_sa.text[:200]}")
            
            try:
                sa_result = resp_sa.json()
            except Exception:
                logger.error(f"secondAuth 返回非 JSON: {resp_sa.text[:500]}")
                return {"success": False, "message": "认证服务异常"}
            
            if sa_result.get("result") != "true":
                error = sa_result.get("error", "认证失败")
                logger.warning(f"secondAuth 失败: {error}")
                return {"success": False, "message": error}
            
            # 检查是否需要二次认证
            auth_info = sa_result.get("info", "")
            if auth_info != "noAuth":
                logger.warning(f"需要二次认证: {auth_info}")
                return {"success": False, "message": f"需要二次认证（{auth_info}），暂不支持"}
            
            # ── Step 5: secondAuth 成功，提交 loginForm ──
            logger.info("secondAuth 通过，正在提交 loginForm...")
            form = soup.find("form", id="loginForm") or soup.find("form")
            action = form.get("action", "") if form else ""
            if action:
                if action.startswith("/"):
                    login_url = f"https://{WEBVPN_HOST}{action}"
                elif not action.startswith("http"):
                    login_url = urljoin(cas_page_url, action)
                else:
                    login_url = action
            else:
                login_url = cas_page_url
            
            login_data = {
                "rsa": rsa,
                "ul": ul,
                "pl": pl,
                "lt": lt,
                "execution": execution or "e1s1",
                "_eventId": "submit",
            }
            
            post_headers = {
                "Content-Type": "application/x-www-form-urlencoded",
                "Origin": f"https://{WEBVPN_HOST}",
                "Referer": cas_page_url,
            }
            
            resp = self.session.post(
                login_url,
                data=login_data,
                headers=post_headers,
                timeout=15,
                allow_redirects=True,
            )
            
            # ── Step 6: 检查登录结果 ──
            if self._check_login_success(resp):
                self.is_logged_in = True
                
                # ── Step 7: 触发教务系统 CAS SSO ──
                self._establish_edu_session()
                
                self._fetch_user_info()
                logger.info(f"登录成功：{self.student_name or self.student_id}")
                return {
                    "success": True,
                    "message": "登录成功",
                    "name": self.student_name,
                    "class_name": self.class_name,
                }
            else:
                error_msg = self._extract_error_message(resp)
                logger.warning(f"登录失败：{error_msg}")
                return {"success": False, "message": error_msg}
        
        except requests.Timeout:
            return {"success": False, "message": "连接超时，请稍后重试"}
        except requests.ConnectionError:
            return {"success": False, "message": "网络连接失败"}
        except Exception as e:
            logger.exception("登录过程中发生异常")
            return {"success": False, "message": f"登录异常: {str(e)}"}
    
    @staticmethod
    def _get_input_value(soup: BeautifulSoup, name: str) -> str:
        """从页面中获取指定 name 的 input value"""
        inp = soup.find("input", {"name": name})
        if inp:
            return inp.get("value", "")
        return ""
    
    def _check_login_success(self, resp: requests.Response) -> bool:
        """检查登录是否成功"""
        cookies = self.session.cookies.get_dict()
        
        # 1. 检查是否有 VPN ticket cookie
        has_vpn_ticket = any(
            "vpn_ticket" in k or "wengine" in k
            for k in cookies
        )
        
        # 2. 检查是否还在 CAS 登录页
        is_at_cas_login = "/cas/login" in resp.url or (
            "/login" in resp.url and "ticket" not in resp.url
        )
        
        # 3. 检查页面中的失败标志
        text = resp.text[:5000]
        failure_markers = [
            "密码错误", "用户名或密码", "认证失败", "登录失败",
            "验证码错误", "账号不存在", "The credentials you provided",
        ]
        if any(m in text for m in failure_markers):
            return False
        
        # 4. 检查响应中是否有 CAS loginForm（仍在登录页）
        if 'id="loginForm"' in text and "lt" in text and "execution" in text:
            # 仍在登录页，说明登录失败
            return False
        
        # 5. VPN ticket 存在即成功；或不在登录页即成功
        if has_vpn_ticket:
            return True
        
        return not is_at_cas_login
    
    def _extract_error_message(self, resp: requests.Response) -> str:
        """从响应中提取错误信息"""
        soup = BeautifulSoup(resp.text, "lxml")
        
        # BNU CAS 错误通常在 <span id="errorMsg"> 或 <div id="msg">
        for selector in [
            {"id": "msg"},
            {"id": "errorMsg"},
            {"class_": "error"},
            {"class_": "alert"},
            {"class_": "login-error"},
        ]:
            el = soup.find(**selector)
            if el and el.get_text(strip=True):
                return el.get_text(strip=True)
        
        # 搜索包含错误关键词的 span/div
        for tag in soup.find_all(["span", "div", "p"]):
            text = tag.get_text(strip=True)
            if any(k in text for k in ["错误", "失败", "不正确", "无效", "不存在"]):
                return text
        
        return "登录失败，请检查学号和密码"
    
    def _establish_edu_session(self):
        """触发教务系统 CAS SSO，建立 JSESSIONID"""
        try:
            edu_root = vpn_url("")
            logger.info(f"正在触发教务系统 SSO: {edu_root}")
            resp = self.session.get(edu_root, timeout=15, allow_redirects=True)
            logger.info(f"教务系统 SSO 完成, final URL: {resp.url[:80]}, length: {len(resp.text)}")
        except Exception as e:
            logger.warning(f"教务系统 SSO 失败: {e}")
    
    def _fetch_user_info(self):
        """登录成功后从课表数据页面获取用户信息"""
        try:
            import base64
            # 使用当前学年的课表数据页来获取学生姓名和班级
            # 尝试几个可能的学年
            from datetime import datetime
            now = datetime.now()
            year = now.year if now.month >= 9 else now.year - 1
            
            for y in [year, year - 1]:
                for sem in [0, 1]:
                    params_raw = f"xn={y}&xq={sem}"
                    params_b64 = base64.b64encode(params_raw.encode()).decode()
                    url = vpn_url(f"{SCHEDULE_DATA_PATH}?params={params_b64}")
                    referer = vpn_url("frame/homes.html")
                    resp = self.session.get(url, timeout=15, 
                                           headers={"Referer": referer})
                    resp.encoding = "gbk"
                    
                    if resp.status_code == 200 and len(resp.text) > 3000:
                        # 匹配姓名
                        m = re.search(r'姓名[：:]\s*([^\s<,，]+)', resp.text)
                        if m:
                            self.student_name = m.group(1)
                        # 匹配班级
                        m = re.search(r'所在班级[：:]\s*(.+?)(?:\s*</)', resp.text, re.DOTALL)
                        if m:
                            self.class_name = m.group(1)
                        
                        if self.student_name:
                            logger.info(f"用户信息：{self.student_name}, {self.class_name}")
                            return
            
            logger.warning("未能获取用户信息")
        except Exception as e:
            logger.warning(f"获取用户信息失败: {e}")
    
    def get_session(self) -> Optional[requests.Session]:
        """获取已登录的 session"""
        if self.is_logged_in and self.session:
            return self.session
        return None
    
    def ensure_logged_in(self) -> bool:
        """检查 session 是否仍有效"""
        if not self.session or not self.is_logged_in:
            return False
        
        try:
            home_url = vpn_url(HOME_PATH)
            resp = self.session.get(home_url, timeout=10, allow_redirects=False)
            
            if resp.status_code == 302:
                location = resp.headers.get("Location", "")
                if "login" in location.lower() or "cas" in location.lower():
                    self.is_logged_in = False
                    return False
            
            # 如果返回的是 CAS 登录页，也判定为失效
            if resp.status_code == 200 and "统一身份认证" in resp.text[:1000]:
                self.is_logged_in = False
                return False
            
            return resp.status_code == 200
        except Exception:
            self.is_logged_in = False
            return False

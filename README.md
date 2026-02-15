# 北师老鸦 (BNU Old Raven)

北京师范大学教务系统非官方移动客户端，支持课表查看、成绩查询、考试安排等功能。

通过 WebVPN 代理访问校内教务系统，无需校园网即可使用。

## 功能

- **课表查看**  周视图网格布局，支持学期/周次切换，课程按颜色区分
- **成绩查询**  GPA 概览统计，按学期分组展示，支持筛选
- **考试安排**  考试时间、地点、座位号，区分即将到来/已结束
- **学期信息**  自动检测当前学期和周次
- **本地缓存**  首次加载后离线可用，减少重复请求
- **暗色模式**  跟随系统自动切换

## 技术架构

```
北师老鸦
 app/          # Flutter 前端（Android）
 backend/      # Python FastAPI 后端
```

### 前端

- **框架**: Flutter 3 + Dart
- **状态管理**: Provider
- **本地存储**: Hive（缓存）+ Secure Storage（Token）
- **HTTP**: Dio，Bearer Token 自动注入
- **设计**: Material 3

### 后端

- **框架**: FastAPI + Uvicorn
- **认证流程**: WebVPN  CAS 统一认证  教务系统
- **数据解析**: BeautifulSoup + lxml
- **鉴权**: JWT（HS256，24h 过期）
- **会话管理**: 内存缓存 WebVPN Session，30 分钟超时，5 分钟内免验

## API 接口

| 端点 | 方法 | 认证 | 说明 |
|------|------|------|------|
| `/api/auth/login` | POST | 否 | 学号密码登录，返回 JWT Token |
| `/api/auth/logout` | POST | 是 | 注销登录 |
| `/api/schedule` | GET | 是 | 获取课表（参数：year, semester） |
| `/api/grades` | GET | 是 | 获取成绩（参数：year, year_end, semester） |
| `/api/exams` | GET | 是 | 获取考试安排（参数：year, semester） |
| `/api/semester-info` | GET | 否 | 获取学期信息（当前周次等） |
| `/health` | GET | 否 | 健康检查 |

## 部署

### 后端

```bash
# 安装依赖
cd backend
pip install -r requirements.txt

# 启动服务（开发）
python main.py

# 启动服务（生产）
nohup python -m uvicorn main:app --host 0.0.0.0 --port 8000 > server.log 2>&1 &
```

### 前端（Android APK）

```bash
cd app
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

修改服务器地址：编辑 `app/lib/config/api_config.dart` 中的 `baseUrl`。

## 依赖

### 后端

| 包 | 用途 |
|----|------|
| fastapi | Web 框架 |
| uvicorn | ASGI 服务器 |
| requests | HTTP 请求（WebVPN 代理） |
| beautifulsoup4 + lxml | HTML 解析 |
| pydantic | 数据模型验证 |
| python-jose | JWT 生成与验证 |
| pycryptodome | CAS 登录密码加密 |

### 前端

| 包 | 用途 |
|----|------|
| dio | HTTP 客户端 |
| provider | 状态管理 |
| hive + hive_flutter | 本地缓存 |
| intl | 日期格式化 |

## 安全说明

- 用户密码仅用于建立 WebVPN 会话，不在后端持久化存储
- JWT Token 24 小时过期
- WebVPN Session 30 分钟空闲超时自动清除

## 许可

本项目仅供学习交流使用。

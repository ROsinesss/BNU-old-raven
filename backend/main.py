"""
北师大教务课表成绩 App - FastAPI 后端入口
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import auth, schedule, grades, exams, semester

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    logging.info("🚀 BNU Schedule API 启动")
    yield
    logging.info("🛑 BNU Schedule API 关闭")


app = FastAPI(
    title="BNU Schedule API",
    description="北京师范大学教务课表成绩查询 API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS 配置（开发环境允许所有来源）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(auth.router)
app.include_router(schedule.router)
app.include_router(grades.router)
app.include_router(exams.router)
app.include_router(semester.router)


@app.get("/")
async def root():
    return {
        "name": "BNU Schedule API",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True,
                reload_excludes=["test_*.py", "debug_*.py", "*.html", "*.js"])

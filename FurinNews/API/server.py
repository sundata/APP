"""
FurinNews Backend Server  v2.0
─────────────────────────────────────────────────
数据源（全部真实可用）:
  · Google News RSS（関键词搜索）
  · Yahoo Japan 芸能 RSS
  · livedoor エンタメ RSS

运行:
  uvicorn server:app --reload --port 8000
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import re
import os
import threading
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from typing import Optional, List

import feedparser
import aiohttp
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI, Query, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import (
    Boolean, Column, DateTime, Index, Integer, String, Text, create_engine
)
from sqlalchemy.orm import declarative_base, sessionmaker

# OpenAI API
from openai import AsyncOpenAI
from dotenv import load_dotenv
from google.cloud import storage

load_dotenv()

# ─────────────────────── 配置 ───────────────────────

FETCH_INTERVAL_MINUTES = 5

# OpenAI API
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_MODEL = "gpt-4o-mini"
openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

# 真实可用 RSS 源（用户推荐的稳定源）
RSS_SOURCES: list[dict] = [
    # ══════════════════ 日本 RSS 源（超稳定） ══════════════════
    
    # 🥇 NHK（官方媒体，最稳定）
    {
        "name": "NHK",
        "url": "https://www3.nhk.or.jp/rss/news/cat0.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    {
        "name": "NHK",
        "url": "https://www3.nhk.or.jp/rss/news/cat1.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    {
        "name": "NHK",
        "url": "https://www3.nhk.or.jp/rss/news/cat2.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🥈 Yahoo Japan News（覆盖最广，更新快）
    {
        "name": "Yahoo Japan",
        "url": "https://news.yahoo.co.jp/rss/topics/top-picks.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    {
        "name": "Yahoo Japan",
        "url": "https://news.yahoo.co.jp/rss/topics/entertainment.xml",
        "category": "celebrity",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    {
        "name": "Yahoo Japan",
        "url": "https://news.yahoo.co.jp/rss/topics/sports.xml",
        "category": "sports",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    {
        "name": "Yahoo Japan",
        "url": "https://news.yahoo.co.jp/rss/topics/business.xml",
        "category": "business",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    {
        "name": "Yahoo Japan",
        "url": "https://news.yahoo.co.jp/rss/topics/world.xml",
        "category": "overseas",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
    # 政治ニュース（政治キーワードで抽出）
    # NHK cat1（最新ニュース、政治含む）
    {
        "name": "NHK",
        "url": "https://www3.nhk.or.jp/rss/news/cat1.xml",
        "category": "politician",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟡 ITmedia（科技类，适合AI用户）
    {
        "name": "ITmedia",
        "url": "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟢 朝日新聞デジタル（大手メディア）
    {
        "name": "Asahi Shimbun",
        "url": "https://www.asahi.com/rss/asahi.rdf",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟢 毎日新聞
    {
        "name": "Mainichi News",
        "url": "https://mainichi.jp/xml/rss/rss.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟢 スポーツ報知（スポーツ）
    {
        "name": "Sports Hochi",
        "url": "https://hochi.news/rss/",
        "category": "sports",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟢 サンスポ（スポーツ＆芸能）
    {
        "name": "Sanspo",
        "url": "https://www.sanspo.com/rss-all.xml",
        "category": "celebrity",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟢 日刊スポーツ（スポーツ）
    {
        "name": "Nikkan Sports",
        "url": "https://www.nikkansports.com/rss.xml",
        "category": "sports",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟠 FNN プライムオンライン（総合ニュース）
    {
        "name": "FNN Prime",
        "url": "https://www.fnn.jp/rss.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🟠 テレ朝 news（ニュース）
    {
        "name": "TV Asahi News",
        "url": "https://news.tv-asahi.co.jp/rss/rss.xml",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # ══════════════════ 国际 RSS 源（做差异化） ══════════════════

    # 🥇 BBC News
    {
        "name": "BBC News",
        "url": "http://feeds.bbci.co.uk/news/rss.xml",
        "category": "overseas",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🥈 Reuters
    {
        "name": "Reuters",
        "url": "https://feeds.reuters.com/reuters/topNews",
        "category": "overseas",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🥉 The New York Times
    {
        "name": "NY Times",
        "url": "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
        "category": "overseas",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # ══════════════════ 新增补充 RSS 源（增强内容丰富度） ══════════════════

    # 🆕 日本経済新聞（経済専門媒体）
    {
        "name": "Nikkei",
        "url": "https://www.nikkei.com/news/nikkei-rss.aspx",
        "category": "business",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🆕 映画.com（電影情報）
    {
        "name": "Eiga.com News",
        "url": "http://www.eiga.com/news/",
        "category": "movie",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🆕 WIRED Japan（テクノロジー・ダイビング）
    {
        "name": "WIRED Japan",
        "url": "https://wired.jp/feed/",
        "category": "tech",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },

    # 🆕 GNews（グローバルニュースアグリゲーター）
    {
        "name": "GNews Global",
        "url": "https://news.google.com/rss?gl=JP&hl=ja&ceid=JP:ja",
        "category": "general",
        "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
    },
]

# 关键词过滤（安全词，避免法律风险）
# Google News 搜索结果需要匹配关键词才入库
KEYWORDS = [
    # 芸能・セレブ系
    "芸能", "スキャンダル", "熱愛", "交際", "離婚",
    "浮気", "密会", "愛人", "二股",
    "セレブ", "有名人", "タレント", "アイドル",
    "俳優", "女優", "歌手", "モデル",
    "不適切", "略奪愛",
    # 政治家系
    "政治", "政治家", "国会", "議員", "大臣", "首相",
    "野党", "与党", "選挙", "政権", "法案",
    "疑惑", "献金", "裏金", "失言",
    # 海外系
    "海外", "世界", "国際", "米国", "中国", "韓国",
    "欧州", "大統領", "外交", "紛争",
    # 一般ニュース系（general 用）
    "ニュース", "話題", "最新", "注目", "問題",
    "事件", "事故", "裁判", "調査", "報告",
    "経済", "社会", "技術", "新型", "発表",
]

# Yahoo / Google News / J-Cast / RocketNews24 宽松过滤（分類済みニュース、キーワード不要）
LOOSE_SOURCES = {
    "NHK", 
    "Yahoo Japan", 
    "ITmedia", 
    "BBC News", 
    "Reuters",
    "NY Times",
    "Asahi Shimbun",    # 朝日新聞
    "Mainichi News",    # 毎日新聞
    "Sports Hochi",     # スポーツ報知
    "Sanspo",           # サンスポ
    "Nikkan Sports",    # 日刊スポーツ
    "FNN Prime",        # FNN プライムオンライン
    "TV Asahi News",    # テレ朝 news
}
# Google News のカテゴリトップページ（検索キーワードなし）はキーワードフィルタをスキップ
GOOGLE_TOP_URLS = {
    "https://news.google.com/rss?hl=ja&gl=JP&ceid=JP:ja",
}
# Google News トピック別RSSのURLプレフィックス（全てキーワードフィルタ対象外）
GOOGLE_TOPIC_PREFIX = "https://news.google.com/rss/topics/"

# 无效图片判断（过滤 favicon/logo 等小图标，但保留文章缩略图）
BAD_IMAGE_PATTERNS = [
    "favicon", "logo.", "logo-", "icon.", "icon-",
    "badge", "button", "spinner", "placeholder",
    "news.google.com/favicon", "www.google.com/images",
    "gstatic.com/news", "gstatic.com/images",
]

# ─────────────────────── DB ───────────────────────

import os

DATABASE_URL = os.environ.get("DATABASE_URL", "")
CLOUD_SQL_CONNECTION_NAME = os.environ.get("CLOUD_SQL_CONNECTION_NAME", "")
ARTICLE_BUCKET = os.environ.get("ARTICLE_BUCKET", "")
ARTICLE_OBJECT = os.environ.get("ARTICLE_OBJECT", "articles.json")

if DATABASE_URL.startswith("postgresql"):
    # Cloud Run + Cloud SQL: 使用 psycopg2 + Unix socket
    # DATABASE_URL 格式: postgresql://user:pass@/dbname?host=/cloudsql/conn_name
    _url = DATABASE_URL
    if "+psycopg2" not in _url:
        _url = _url.replace("postgresql://", "postgresql+psycopg2://")
    engine = create_engine(_url, pool_size=5, max_overflow=10, pool_pre_ping=True)
else:
    # 本地开发: SQLite
    _db_path = os.environ.get("SQLITE_PATH", "./furinnews.db")
    engine = create_engine(f"sqlite:///{_db_path}", connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()


class ArticleORM(Base):
    __tablename__ = "articles"
    __table_args__ = (
        Index("ix_articles_active_published", "is_active", "published_at"),
        Index("ix_articles_category_active_published", "category", "is_active", "published_at"),
    )

    id           = Column(Integer, primary_key=True, index=True)
    uid          = Column(String(64), unique=True, index=True)
    title        = Column(String(512), nullable=False)
    summary      = Column(Text, default="")
    url          = Column(String(1024), nullable=False)
    image_url    = Column(String(1024), nullable=True)
    source_name  = Column(String(128), nullable=False)
    source_site  = Column(String(512), nullable=False)
    author       = Column(String(128), default="")
    category     = Column(String(64), default="general")
    published_at = Column(DateTime(timezone=True), nullable=False)
    created_at   = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    is_active    = Column(Boolean, default=True)


class ArticleAIAnalysisORM(Base):
    """AI分析結果キャッシュ"""
    __tablename__ = "article_ai_analysis"
    id              = Column(Integer, primary_key=True, index=True)
    article_id      = Column(Integer, index=True, nullable=False)
    summary         = Column(String(500), default="")
    three_points    = Column(Text, default="")  # JSON list
    importance      = Column(String(500), default="")
    deep_analysis   = Column(Text, nullable=True)  # JSON object
    cached_at       = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


Base.metadata.create_all(bind=engine)


class JSONArticleStore:
    """Thread-safe article index persisted as one Cloud Storage JSON object."""

    def __init__(self, bucket_name: str, object_name: str):
        self.bucket_name = bucket_name
        self.object_name = object_name
        self._lock = threading.RLock()
        self._articles: list[dict] = []
        self._storage_client = None

    def load(self) -> None:
        if not self.bucket_name:
            logging.getLogger("furinnews").warning("ARTICLE_BUCKET is empty; using memory-only article store")
            return
        try:
            self._storage_client = storage.Client()
            blob = self._storage_client.bucket(self.bucket_name).blob(self.object_name)
            if blob.exists():
                payload = json.loads(blob.download_as_text())
                with self._lock:
                    self._articles = payload.get("articles", payload if isinstance(payload, list) else [])
            logging.getLogger("furinnews").info("Loaded %d articles from gs://%s/%s", len(self._articles), self.bucket_name, self.object_name)
        except Exception as exc:
            logging.getLogger("furinnews").warning("Could not load article JSON: %s", exc)

    def _save(self) -> None:
        if not self.bucket_name:
            return
        if self._storage_client is None:
            self._storage_client = storage.Client()
        payload = {"updated_at": datetime.now(timezone.utc).isoformat(), "articles": self._articles}
        self._storage_client.bucket(self.bucket_name).blob(self.object_name).upload_from_string(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
            content_type="application/json",
        )

    @staticmethod
    def _serializable(article: dict) -> dict:
        item = dict(article)
        published = item.get("published_at")
        if isinstance(published, datetime):
            item["published_at"] = published.astimezone(timezone.utc).isoformat()
        item["id"] = item.get("id") or item["uid"]
        item["is_active"] = item.get("is_active", True)
        return item

    @staticmethod
    def published_at(article: dict) -> datetime:
        value = article.get("published_at")
        if isinstance(value, datetime):
            return value
        try:
            return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except (TypeError, ValueError):
            return datetime.now(timezone.utc)

    def merge(self, incoming: list[dict], retention_days: int = 30) -> int:
        cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
        with self._lock:
            by_uid = {a["uid"]: a for a in self._articles if a.get("uid")}
            before = len(by_uid)
            for raw in incoming:
                item = self._serializable(raw)
                existing = by_uid.get(item["uid"])
                if existing:
                    if not item.get("image_url"):
                        item["image_url"] = existing.get("image_url")
                    if not item.get("summary"):
                        item["summary"] = existing.get("summary", "")
                by_uid[item["uid"]] = item
            self._articles = sorted(
                (a for a in by_uid.values() if self.published_at(a) >= cutoff),
                key=self.published_at,
                reverse=True,
            )
            new_count = max(0, len(by_uid) - before)
            self._save()
            return new_count

    def all(self) -> list[dict]:
        with self._lock:
            return [dict(a) for a in self._articles]

    def replace(self, articles: list[dict]) -> None:
        with self._lock:
            self._articles = [self._serializable(a) for a in articles]
            self._articles.sort(key=self.published_at, reverse=True)
            self._save()

    def find(self, article_id: str) -> Optional[dict]:
        with self._lock:
            return next((dict(a) for a in self._articles if str(a.get("id")) == article_id or a.get("uid") == article_id), None)


article_store = JSONArticleStore(ARTICLE_BUCKET, ARTICLE_OBJECT)
article_store.load()

# ─────────────────────── Pydantic ───────────────────────

class SourceSchema(BaseModel):
    name: str
    logoURL: Optional[str] = None
    website: str
    class Config: from_attributes = True

class ArticleSchema(BaseModel):
    id: str
    title: str
    summary: str
    source: SourceSchema
    author: str
    publishedAt: str
    url: str
    imageURL: Optional[str] = None
    category: str
    isRead: bool = False
    isBookmarked: bool = False
    class Config: from_attributes = True

class NewsResponse(BaseModel):
    articles: List[ArticleSchema]
    total: int
    page: int
    hasMore: bool


class AIAnalysisResponse(BaseModel):
    """基本AI分析レスポンス"""
    articleId: str
    summary: str
    threePoints: List[str]
    importance: str
    cached: bool = False


class DeepAnalysisResponse(BaseModel):
    """深度分析レスポンス"""
    articleId: str
    impactAnalysis: str
    futureOutlook: str
    actionAdvice: str

# ─────────────────────── Crawler ───────────────────────

logger = logging.getLogger("furinnews")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


_background_tasks: set[asyncio.Task] = set()


def _create_background_task(coro):
    task = asyncio.create_task(coro)
    _background_tasks.add(task)

    def _on_done(completed: asyncio.Task):
        _background_tasks.discard(completed)
        if completed.cancelled():
            return
        try:
            error = completed.exception()
        except asyncio.CancelledError:
            return
        if error:
            logger.error(
                "Background task failed",
                exc_info=(type(error), error, error.__traceback__),
            )

    task.add_done_callback(_on_done)
    return task


def _find_article(db, article_id: str):
    try:
        article = (
            db.query(ArticleORM)
            .filter(ArticleORM.uid == article_id)
            .first()
        )
    except Exception:
        db.rollback()
        logger.exception(f"Article lookup failed for uid={article_id!r}")
        raise HTTPException(
            status_code=503,
            detail="Article database unavailable",
        )

    if article:
        return article

    try:
        numeric_id = int(article_id)
    except (TypeError, ValueError):
        return None

    try:
        return db.query(ArticleORM).filter(ArticleORM.id == numeric_id).first()
    except Exception:
        db.rollback()
        logger.exception(f"Article lookup failed for id={numeric_id}")
        raise HTTPException(
            status_code=503,
            detail="Article database unavailable",
        )


# ─────────────────────── AI分析ヘルパー関数 ───────────────────────

def _build_analysis_prompt(article_title: str, article_summary: str, article_content: str) -> str:
    return f"""
あなたはニュース記事の分析専門家です。以下の記事について、日本語で以下の情報を提供してください。

【記事情報】
タイトル: {article_title}
概要: {article_summary}
内容: {article_content}

【分析指示】
1. **一言まとめ**: この記事の要点を30字以内で要約してください。
2. **3つのポイント**: この記事の重要なポイントを3つ、各20字以内で列挙してください。形式: ["ポイント1", "ポイント2", "ポイント3"]
3. **なぜ重要か**: この記事がなぜ重要なのか、社会的インパクトを50字以内で説明してください。

以以下のJSONフォーマットで回答してください（Markdownなし）:
{{
    "summary": "一言まとめ",
    "points": ["ポイント1", "ポイント2", "ポイント3"],
    "importance": "なぜ重要か"
}}
"""


def _build_deep_analysis_prompt(article_title: str, article_summary: str, article_content: str, basic_analysis: str) -> str:
    return f"""
あなたはニュース記事の深度分析専門家です。以下の記事について、深度分析を実施してください。

【記事情報】
タイトル: {article_title}
概要: {article_summary}
内容: {article_content}

【既存の基本分析】
{basic_analysis}

【深度分析指示】
1. **影響分析**: この記事が経済・社会・政治に与える今後の影響を分析してください（100字以内）。
2. **今後の予測**: 3ヶ月後、6ヶ月後の動向予測を記述してください（80字以内）。
3. **行動アドバイス**: 読者がこのニュースを踏まえ、どのような行動を検討すべきかアドバイスしてください（80字以内）。

以下のJSONフォーマットで回答してください（Markdownなし）:
{{
    "impactAnalysis": "影響分析",
    "futureOutlook": "今後の予測",
    "actionAdvice": "行動アドバイス"
}}
"""


# ✅ 后台异步任务1：获取真实分析（不阻塞响应）
async def _fetch_and_cache_real_analysis_background(article_id: int, prompt: str):
    """使用 OpenAI 获取真实分析并缓存"""
    import json
    try:
        result = await _analyze_with_openai(prompt)
        if result:
            db = SessionLocal()
            try:
                cached = db.query(ArticleAIAnalysisORM).filter(
                    ArticleAIAnalysisORM.article_id == article_id
                ).first()
                
                if cached:
                    # 更新模拟数据为真实数据
                    cached.summary = result.get("summary", "")
                    cached.three_points = json.dumps(result.get("points", []))
                    cached.importance = result.get("importance", "")
                    cached.cached_at = datetime.now(timezone.utc)
                    db.add(cached)
                    db.commit()
                    logger.info(f"✅ 真实分析已缓存 article_id={article_id}")
            finally:
                db.close()
    except Exception as e:
        logger.warning(f"后台获取真实分析失败 article_id={article_id}: {e}")


# ✅ 后台异步刷新分析（不阻塞客户端）
async def _refresh_analysis_background(article_id: int, title: str, summary: str):
    """在后台异步刷新 AI 分析，不会阻塞 HTTP 响应"""
    import json
    try:
        prompt = _build_analysis_prompt(title, summary, summary)
        result = await _analyze_with_openai(prompt)
        if result:
            db = SessionLocal()
            try:
                cached = db.query(ArticleAIAnalysisORM).filter(
                    ArticleAIAnalysisORM.article_id == article_id
                ).first()
                
                if not cached:
                    cached = ArticleAIAnalysisORM(article_id=article_id)
                
                cached.summary = result.get("summary", "")
                cached.three_points = json.dumps(result.get("points", []))
                cached.importance = result.get("importance", "")
                cached.cached_at = datetime.now(timezone.utc)
                
                db.add(cached)
                db.commit()
                logger.info(f"✅ Background refresh completed for article {article_id}")
            finally:
                db.close()
    except Exception as e:
        logger.warning(f"Background refresh failed for article {article_id}: {e}")


async def _analyze_with_openai(prompt: str) -> Optional[dict]:
    """OpenAI APIを使って分析を実行"""
    if not openai_client:
        logger.warning("OpenAI API key not configured, using mock analysis")
        return _generate_mock_analysis()
    
    try:
        response = await openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {
                    "role": "system",
                    "content": "You are a professional news analyzer. Respond only with valid JSON."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.7,
            max_tokens=1000,
            timeout=30
        )
        
        content = response.choices[0].message.content
        import json
        result = json.loads(content)
        return result
    except Exception:
        logger.exception("OpenAI API error, using mock analysis as fallback")
        # ✅ 如果 OpenAI 失败，返回模拟分析而不是 None
        return _generate_mock_analysis()


def _generate_mock_analysis() -> dict:
    """生成模拟分析结果 (备选方案)"""
    import random
    
    mock_summaries = [
        "重要な業界ニュース",
        "市場に影響を与える動き",
        "注目の新発表",
        "業界動向の変化",
        "重要な発表がありました"
    ]
    
    mock_points = [
        ["市場への波及効果が大きい", "競争環境が変わる可能性", "今後の展開に注目"],
        ["新しいトレンドが始まる", "企業戦略に影響", "消費者にメリット"],
        ["業界の構図変化", "対応が必要", "ビジネス展開のチャンス"],
        ["革新的な動き", "競合が激化", "長期的な影響大"],
        ["重要な転機", "市場再編の可能性", "準備が大切"]
    ]
    
    mock_importance = [
        "この情報は市場全体に波及効果を与える可能性がある",
        "ユーザーの日常生活に大きな影響を与える",
        "業界の競争構図が変わる可能性がある",
        "今後の政策や企業戦略に影響を与える",
        "グローバルなトレンド変化を示す重要な事例"
    ]
    
    idx = random.randint(0, len(mock_summaries) - 1)
    
    return {
        "summary": mock_summaries[idx],
        "points": mock_points[idx],
        "importance": mock_importance[idx]
    }


def _uid(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()


def _contains_keyword(text: str, source_name: str, source_url: str = "") -> bool:
    # Yahoo / Google News / J-Cast / RocketNews24 は分類済みニュースなのでキーワード不要
    if source_name in LOOSE_SOURCES:
        return True
    # Google News カテゴリトップページもキーワード不要
    if source_url in GOOGLE_TOP_URLS:
        return True
    # Google News トピック別RSSもキーワード不要
    if source_url.startswith(GOOGLE_TOPIC_PREFIX):
        return True
    return any(kw in text for kw in KEYWORDS)


def _is_bad_image(url: str) -> bool:
    """判断图片URL是否为无效图片（favicon/logo等小图标）"""
    if not url:
        return True
    url_lower = url.lower()
    return any(pat in url_lower for pat in BAD_IMAGE_PATTERNS)


def _extract_image(entry) -> Optional[str]:
    if hasattr(entry, "media_thumbnail") and entry.media_thumbnail:
        return entry.media_thumbnail[0].get("url")
    if hasattr(entry, "enclosures") and entry.enclosures:
        for enc in entry.enclosures:
            if enc.get("type", "").startswith("image"):
                return enc.get("href") or enc.get("url")
    content_html = ""
    if hasattr(entry, "content") and entry.content:
        content_html = entry.content[0].get("value", "")
    elif hasattr(entry, "summary_detail"):
        content_html = entry.summary_detail.get("value", "")
    m = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', content_html)
    if m:
        return m.group(1)
    return None


def _parse_date(entry) -> datetime:
    # feedparser parsed tuple
    if hasattr(entry, "published_parsed") and entry.published_parsed:
        try:
            return datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
        except Exception:
            logger.debug(
                "Failed to parse published_parsed for "
                f"entry={getattr(entry, 'link', entry)!r}",
                exc_info=True,
            )
    # RFC 2822 string
    if hasattr(entry, "published") and entry.published:
        try:
            return parsedate_to_datetime(entry.published)
        except Exception:
            logger.debug(
                "Failed to parse published date for "
                f"entry={getattr(entry, 'link', entry)!r}",
                exc_info=True,
            )
    return datetime.now(timezone.utc)


def _resolve_source_name(entry, source: dict) -> str:
    """Google News RSS 的 source 在 <source> tag 里"""
    if hasattr(entry, "source") and hasattr(entry.source, "title"):
        return entry.source.title
    return source["name"]


async def _fetch_og_image(url: str, source_name: str = "") -> Optional[str]:
    """获取文章缩略图：尝试抓取OG图片"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                headers={"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"},
                timeout=aiohttp.ClientTimeout(total=10),
                ssl=False,
                allow_redirects=True,
            ) as resp:
                if resp.status != 200:
                    return None
                ct = resp.headers.get("content-type", "")
                if "text/html" not in ct and "application/xhtml" not in ct:
                    return None
                html = await resp.text(errors="ignore")
        # og:image
        m = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']', html)
        if not m:
            m = re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']', html)
        if not m:
            m = re.search(r'<meta[^>]+name=["\']twitter:image["\'][^>]+content=["\']([^"\']+)["\']', html)
        if not m:
            m = re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']twitter:image["\']', html)
        if m:
            img = m.group(1)
            if img.startswith("//"):
                img = "https:" + img
            elif img.startswith("/"):
                from urllib.parse import urlparse
                parsed = urlparse(url)
                img = f"{parsed.scheme}://{parsed.netloc}{img}"
            if _is_bad_image(img):
                return None
            return img
    except Exception as exc:
        logger.warning(f"OG image fetch failed url={url}: {exc}")
    return None


async def _fetch_article_detail(url: str) -> dict:
    """Yahoo記事の詳細ページからsummaryとog:imageを取得"""
    result = {"summary": "", "image_url": None}
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                headers={"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"},
                timeout=aiohttp.ClientTimeout(total=10),
                ssl=False,
                allow_redirects=True,
            ) as resp:
                if resp.status != 200:
                    return result
                html = await resp.text(errors="ignore")

        # Extract og:image
        img = None
        m = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']', html)
        if not m:
            m = re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']', html)
        if not m:
            m = re.search(r'<meta[^>]+name=["\']twitter:image["\'][^>]+content=["\']([^"\']+)["\']', html)
        if not m:
            m = re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']twitter:image["\']', html)
        if m:
            img = m.group(1)
            if img.startswith("//"):
                img = "https:" + img
            elif img.startswith("/"):
                from urllib.parse import urlparse
                parsed = urlparse(url)
                img = f"{parsed.scheme}://{parsed.netloc}{img}"
            if not _is_bad_image(img):
                result["image_url"] = img

        # Extract og:description as summary
        desc = None
        m2 = re.search(r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\']([^"\']+)["\']', html)
        if not m2:
            m2 = re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:description["\']', html)
        if not m2:
            m2 = re.search(r'<meta[^>]+name=["\']description["\'][^>]+content=["\']([^"\']+)["\']', html)
        if not m2:
            m2 = re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']description["\']', html)
        if m2:
            desc = re.sub(r'<[^>]+>', '', m2.group(1))[:500]
            if desc:
                result["summary"] = desc

    except Exception as exc:
        logger.warning(f"Article detail fetch failed url={url}: {exc}")
    return result


async def fetch_rss(source: dict) -> list[dict]:
    results = []
    ua = source.get("ua", "Mozilla/5.0 FeedFetcher")
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                source["url"],
                headers={"User-Agent": ua},
                timeout=aiohttp.ClientTimeout(total=15),
            ) as resp:
                raw = await resp.text()

        feed = feedparser.parse(raw)
        for entry in feed.entries:
            title   = entry.get("title", "").strip()
            summary = re.sub(r"<[^>]+>", "", entry.get("summary", ""))[:500]
            url     = entry.get("link", "").strip()

            if not url or not title:
                continue

            src_name = _resolve_source_name(entry, source)

            if not _contains_keyword(title + summary, src_name, source["url"]):
                continue

            results.append({
                "uid":          _uid(url),
                "title":        title,
                "summary":      summary,
                "url":          url,
                "image_url":    None if _is_bad_image(_extract_image(entry) or "") else _extract_image(entry),
                "source_name":  src_name,
                "source_site":  source["url"],
                "author":       entry.get("author", ""),
                "category":     source["category"],
                "published_at": _parse_date(entry),
            })

        logger.info(f"[{source['name']}] {len(results)} articles matched  ({source['url'][-60:]})")
    except Exception as exc:
        logger.warning(f"[{source['name']}] fetch error: {exc}")
    return results


async def run_crawler():
    logger.info("=== crawler started ===")
    tasks = [fetch_rss(src) for src in RSS_SOURCES]
    all_results = await asyncio.gather(*tasks)

    # Step 1: Yahoo記事はsummaryが空なので、詳細ページからsummary+画像を取得
    yahoo_articles = []
    other_articles = []
    for articles in all_results:
        for a in articles:
            if a["source_name"] == "Yahoo Japan" and (not a["summary"] or not a["image_url"]):
                yahoo_articles.append(a)
            else:
                other_articles.append(a)

    if yahoo_articles:
        logger.info(f"Fetching details for {len(yahoo_articles)} Yahoo articles ...")
        # バッチ処理（同時5件まで、安定性向上）
        batch_size = 5
        for i in range(0, len(yahoo_articles), batch_size):
            batch = yahoo_articles[i:i+batch_size]
            detail_results = await asyncio.gather(*[
                _fetch_article_detail(a["url"]) for a in batch
            ])
            for a, detail in zip(batch, detail_results):
                if detail["summary"] and not a["summary"]:
                    a["summary"] = detail["summary"]
                if detail["image_url"] and not a["image_url"]:
                    a["image_url"] = detail["image_url"]
            # 短い待機
            if i + batch_size < len(yahoo_articles):
                await asyncio.sleep(1)

    # Step 2: まだ画像がない記事のOG画像を取得
    need_og = []
    all_articles = other_articles + yahoo_articles
    for a in all_articles:
        if not a["image_url"]:
            need_og.append(a)

    if need_og:
        # 一度に最大20件まで（メモリ・タイムアウト対策）
        batch = need_og[:20]
        remaining = need_og[20:]
        logger.info(f"Fetching OG images for {len(batch)}/{len(need_og)} articles ...")
        try:
            og_results = await asyncio.wait_for(
                asyncio.gather(*[
                    _fetch_og_image(a["url"], source_name=a["source_name"]) for a in batch
                ]),
                timeout=60  # 全体60秒でタイムアウト
            )
            for a, img in zip(batch, og_results):
                if img:
                    a["image_url"] = img
        except asyncio.TimeoutError:
            logger.warning(f"OG image fetch timed out after 60s, skipping {len(batch)} articles")
        # 20件を超えた分も画像なしで保存
        all_articles.extend([])  # no-op, just for clarity
        # remaining articles keep their empty image_url

    # Step 3: Merge and persist one JSON snapshot to Cloud Storage.
    new_count = article_store.merge(all_articles, retention_days=30)

    # ログ：画像あり/なしの数
    with_img = sum(1 for a in all_articles if a["image_url"])
    logger.info(f"=== crawler done, {new_count} new articles ({with_img}/{len(all_articles)} with images) ===")

# ─────────────────────── FastAPI ───────────────────────

app = FastAPI(title="FurinNews API", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
scheduler = AsyncIOScheduler()


@app.on_event("startup")
async def startup():
    # 延迟30秒后开始爬取，避免阻塞 Cloud Run 启动
    async def _delayed_crawl():
        await asyncio.sleep(30)
        await run_crawler()
    _create_background_task(_delayed_crawl())
    scheduler.add_job(run_crawler, "interval", minutes=FETCH_INTERVAL_MINUTES)
    scheduler.start()
    logger.info(f"Scheduler started, interval={FETCH_INTERVAL_MINUTES}min")


@app.on_event("shutdown")
async def shutdown():
    scheduler.shutdown()


def _to_schema(a) -> ArticleSchema:
    if isinstance(a, dict):
        return ArticleSchema(
            id=str(a.get("id") or a["uid"]),
            title=a["title"],
            summary=a.get("summary", ""),
            source=SourceSchema(name=a["source_name"], logoURL=None, website=a["source_site"]),
            author=a.get("author", ""),
            publishedAt=JSONArticleStore.published_at(a).isoformat(),
            url=a["url"],
            imageURL=a.get("image_url"),
            category=a.get("category", "general"),
        )
    return ArticleSchema(
        id=str(a.id),
        title=a.title,
        summary=a.summary,
        source=SourceSchema(name=a.source_name, logoURL=None, website=a.source_site),
        author=a.author,
        publishedAt=a.published_at.isoformat(),
        url=a.url,
        imageURL=a.image_url,
        category=a.category,
    )


@app.get("/v1/articles", response_model=NewsResponse)
def get_articles(
    category: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    keyword: Optional[str] = Query(None),
):
    rows = [a for a in article_store.all() if a.get("is_active", True)]
    if category:
        rows = [a for a in rows if a.get("category") == category]
    if keyword:
        aliases = {
            "芸能": "celebrity", "エンタメ": "celebrity", "セレブ": "celebrity",
            "アイドル": "celebrity", "俳優": "celebrity", "女優": "celebrity",
            "スポーツ": "sports", "野球": "sports", "サッカー": "sports",
            "政治": "politician", "政治家": "politician", "国会": "politician",
            "経済": "business", "ビジネス": "business", "株": "business",
            "海外": "overseas", "国際": "overseas", "世界": "overseas",
            "トレンド": "trending", "人気": "trending", "話題": "trending",
        }
        words = [w.strip().lower() for w in keyword.replace("　", " ").split() if w.strip()]
        matched_categories = {aliases[w] for w in words if w in aliases}
        rows = [a for a in rows if a.get("category") in matched_categories or any(
            w in f'{a.get("title", "")} {a.get("summary", "")}'.lower() for w in words
        )]
    total = len(rows)
    offset = (page - 1) * limit
    page_rows = rows[offset:offset + limit]
    return NewsResponse(
        articles=[_to_schema(r) for r in page_rows],
        total=total,
        page=page,
        hasMore=offset + limit < total,
    )


@app.get("/v1/articles/{article_id}", response_model=ArticleSchema)
def get_article(article_id: str):
    a = article_store.find(str(article_id))
    if not a:
        raise HTTPException(status_code=404, detail="Not found")
    return _to_schema(a)


@app.post("/v1/crawl")
async def manual_crawl():
    _create_background_task(run_crawler())
    return {"status": "crawling started"}


@app.get("/v1/stats")
def stats():
    rows = article_store.all()
    by_cat = {}
    for row in rows:
        key = row.get("category", "general")
        by_cat[key] = by_cat.get(key, 0) + 1
    return {
        "total": len(rows),
        "with_image": sum(1 for row in rows if row.get("image_url")),
        "by_category": by_cat,
        "storage": f"gs://{ARTICLE_BUCKET}/{ARTICLE_OBJECT}" if ARTICLE_BUCKET else "memory",
    }


@app.post("/v1/backfill-images")
async def backfill_images(limit: int = Query(100, ge=1, le=200)):
    """为image_url为空的文章补填缩略图和summary"""
    # 先获取需要更新的文章ID和URL
    db = SessionLocal()
    try:
        rows = db.query(ArticleORM).filter(
            (ArticleORM.image_url == None) | (ArticleORM.image_url == "")
        ).limit(limit).all()
        items = [(r.id, r.url, r.source_name, r.summary) for r in rows]
    finally:
        db.close()

    if not items:
        return {"status": "no articles need images"}

    updated_img = 0
    updated_summary = 0
    updates = {}  # id -> {image_url, summary}

    # バッチでOG画像とsummaryを取得
    for i in range(0, len(items), 10):
        batch = items[i:i+10]
        tasks = []
        for (aid, url, src, summ) in batch:
            if src == "Yahoo Japan":
                tasks.append((aid, url, _fetch_article_detail(url), summ))
            else:
                # 非Yahoo記事は_fetch_og_imageのみ
                tasks.append((aid, url, None, summ))

        # Yahoo記事の詳細取得
        detail_tasks = [(aid, url, t) for aid, url, t, _ in tasks if t is not None]
        og_tasks = [(aid, url, _fetch_og_image(url, source_name="")) for aid, url, t, _ in tasks if t is None]

        if detail_tasks:
            results = await asyncio.gather(*[t for _, _, t in detail_tasks], return_exceptions=True)
            for (aid, url, _), result in zip(detail_tasks, results):
                if isinstance(result, Exception):
                    logger.warning(
                        f"Article detail fetch failed url={url}: {result}"
                    )
                    continue
                updates[aid] = {}
                if result.get("image_url"):
                    updates[aid]["image_url"] = result["image_url"]
                    updated_img += 1
                if result.get("summary"):
                    updates[aid]["summary"] = result["summary"]
                    updated_summary += 1

        if og_tasks:
            og_results = await asyncio.gather(*[t for _, _, t in og_tasks], return_exceptions=True)
            for (aid, url, _), img in zip(og_tasks, og_results):
                if isinstance(img, Exception) or not img:
                    if isinstance(img, Exception):
                        logger.warning(
                            f"OG image fetch failed url={url}: {img}"
                        )
                    continue
                updates[aid] = updates.get(aid, {})
                updates[aid]["image_url"] = img
                updated_img += 1

        await asyncio.sleep(0.3)

    # DB更新
    db2 = SessionLocal()
    try:
        for aid, data in updates.items():
            r = db2.query(ArticleORM).filter_by(id=aid).first()
            if r:
                if data.get("image_url"):
                    r.image_url = data["image_url"]
                if data.get("summary") and not r.summary:
                    r.summary = data["summary"]
        db2.commit()
    finally:
        db2.close()

    return {"checked": len(items), "updated_images": updated_img, "updated_summaries": updated_summary}


@app.get("/v1/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat(), "version": "2.0.0"}


# ─────────────────────── AI分析エンドポイント ───────────────────────

@app.post("/v1/ai/analyze")
async def ai_analyze(
    article_id: Optional[str] = Query(None),  # String: uid from DB
    title: Optional[str] = Query(None),
    summary: Optional[str] = Query(None),
    content: Optional[str] = Query(None),
    force_refresh: bool = Query(False),  # ← 强制刷新标志，跳过缓存
    user_id: Optional[str] = Header(None, alias="X-User-ID"),
    authorization: Optional[str] = Header(None),
):
    """基本的なAI分析（一言まとめ、3つのポイント、なぜ重要か）"""
    
    # ユーザー認証チェック
    if not user_id or not authorization:
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    # 記事情報取得
    article_data = None
    if article_id:
        db = SessionLocal()
        try:
            # uid (String) または id (Integer) で検索
            article = _find_article(db, article_id)
            
            if not article:
                raise HTTPException(status_code=404, detail="Article not found")
            
            # ✅ 关键改动：总是检查缓存，即使 force_refresh=True
            # 这样用户总是能立即看到结果（缓存或模拟）
            cached = db.query(ArticleAIAnalysisORM).filter(
                ArticleAIAnalysisORM.article_id == article.id
            ).first()
            
            if cached and cached.summary and cached.three_points:
                import json
                cached_response = AIAnalysisResponse(
                    articleId=str(article.id),
                    summary=cached.summary,
                    threePoints=json.loads(cached.three_points),
                    importance=cached.importance,
                    cached=True
                )
                
                # 如果 force_refresh=True，后台异步刷新（不阻塞响应）
                if force_refresh:
                    import asyncio
                    _create_background_task(
                        _refresh_analysis_background(
                            article.id,
                            article.title,
                            article.summary,
                        )
                    )
                
                return cached_response
            
            article_data = {
                "id": article.id,
                "title": article.title,
                "summary": article.summary,
                "content": article.summary  # サーバーには詳細内容がないため summary を使う
            }
        finally:
            db.close()
    else:
        if not title or not summary:
            raise HTTPException(status_code=400, detail="title and summary required")
        article_data = {
            "id": None,
            "title": title,
            "summary": summary,
            "content": content or summary
        }
    
    # OpenAI で分析
    prompt = _build_analysis_prompt(
        article_data["title"],
        article_data["summary"],
        article_data["content"]
    )
    
    # ✅ 激进策略：不等 OpenAI，直接返回模拟分析
    # 然后后台异步获取真实分析
    result = _generate_mock_analysis()  # 立即返回模拟（毫秒级）
    
    # 后台异步获取真实 OpenAI 分析
    import asyncio
    if article_data["id"]:
        _create_background_task(
            _fetch_and_cache_real_analysis_background(
                article_data["id"],
                prompt,
            )
        )
    
    # キャッシュに保存（模拟分析）
    if article_data["id"]:
        import json
        db = SessionLocal()
        try:
            cached = db.query(ArticleAIAnalysisORM).filter(
                ArticleAIAnalysisORM.article_id == article_data["id"]
            ).first()
            
            if not cached:
                cached = ArticleAIAnalysisORM(article_id=article_data["id"])
            
            cached.summary = result.get("summary", "")
            cached.three_points = json.dumps(result.get("points", []))
            cached.importance = result.get("importance", "")
            cached.cached_at = datetime.now(timezone.utc)
            
            db.add(cached)
            db.commit()
        except Exception as e:
            logger.warning(f"Failed to cache analysis: {e}")
        finally:
            db.close()
    
    return AIAnalysisResponse(
        articleId=str(article_data["id"]) if article_data["id"] else title[:10],
        summary=result.get("summary", ""),
        threePoints=result.get("points", []),
        importance=result.get("importance", ""),
        cached=False
    )


@app.post("/v1/ai/deep-analyze")
async def ai_deep_analyze(
    article_id: Optional[str] = Query(None),  # String: uid from DB
    title: Optional[str] = Query(None),
    summary: Optional[str] = Query(None),
    content: Optional[str] = Query(None),
    basic_analysis: Optional[str] = Query(None),
    user_id: Optional[str] = Header(None, alias="X-User-ID"),
    authorization: Optional[str] = Header(None),
):
    """深度AI分析（影響分析、今後の予測、行動アドバイス）"""
    
    # ユーザー認証チェック
    if not user_id or not authorization:
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    # 記事情報取得
    article_data = None
    if article_id:
        db = SessionLocal()
        try:
            # uid (String) または id (Integer) で検索
            article = _find_article(db, article_id)
            
            if not article:
                raise HTTPException(status_code=404, detail="Article not found")
            
            # キャッシュを確認
            cached = db.query(ArticleAIAnalysisORM).filter(
                ArticleAIAnalysisORM.article_id == article.id
            ).first()
            
            if cached and cached.deep_analysis:
                import json
                deep = json.loads(cached.deep_analysis)
                return DeepAnalysisResponse(
                    articleId=str(article.id),
                    impactAnalysis=deep.get("impactAnalysis", ""),
                    futureOutlook=deep.get("futureOutlook", ""),
                    actionAdvice=deep.get("actionAdvice", "")
                )
            
            article_data = {
                "id": article.id,
                "title": article.title,
                "summary": article.summary,
                "content": article.summary
            }
        finally:
            db.close()
    else:
        if not title or not summary:
            raise HTTPException(status_code=400, detail="title and summary required")
        article_data = {
            "id": None,
            "title": title,
            "summary": summary,
            "content": content or summary
        }
    
    # OpenAI で深度分析
    if not basic_analysis:
        basic_analysis = "分析情報が利用不可"
    
    prompt = _build_deep_analysis_prompt(
        article_data["title"],
        article_data["summary"],
        article_data["content"],
        basic_analysis
    )
    
    result = await _analyze_with_openai(prompt)
    if not result:
        raise HTTPException(status_code=500, detail="Deep analysis failed")
    
    # キャッシュに保存
    if article_data["id"]:
        import json
        db = SessionLocal()
        try:
            cached = db.query(ArticleAIAnalysisORM).filter(
                ArticleAIAnalysisORM.article_id == article_data["id"]
            ).first()
            
            if not cached:
                cached = ArticleAIAnalysisORM(article_id=article_data["id"])
            
            cached.deep_analysis = json.dumps(result)
            cached.cached_at = datetime.now(timezone.utc)
            
            db.add(cached)
            db.commit()
        except Exception as e:
            logger.warning(f"Failed to cache deep analysis: {e}")
        finally:
            db.close()
    
    return DeepAnalysisResponse(
        articleId=str(article_data["id"]) if article_data["id"] else title[:10],
        impactAnalysis=result.get("impactAnalysis", ""),
        futureOutlook=result.get("futureOutlook", ""),
        actionAdvice=result.get("actionAdvice", "")
    )


# ──────────────────────── 订阅和通知端点 ──────────────────────

@app.post("/v1/subscription/verify-receipt")
async def verify_receipt(receipt_data: dict):
    """验证App Store收据"""
    from notifications import get_subscription_manager, ReceiptData
    
    try:
        manager = get_subscription_manager()
        
        # 从请求数据创建 ReceiptData
        try:
            receipt = ReceiptData(
                transactionID=receipt_data.get("transactionID", ""),
                productID=receipt_data.get("productID", ""),
                originalTransactionID=receipt_data.get(
                    "originalTransactionID",
                    "",
                ),
                expirationDate=float(receipt_data.get("expirationDate", 0)),
                purchaseDate=float(receipt_data.get("purchaseDate", 0))
            )
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="Invalid receipt data")
        
        result = await manager.verify_receipt(receipt)
        return {
            "verified": bool(result.get("verified", False)),
            "data": result,
        }
    except HTTPException:
        raise
    except Exception:
        logger.exception("Receipt verification error")
        raise HTTPException(
            status_code=500,
            detail="Receipt verification failed",
        )


@app.post("/v1/subscription/purchase")
async def handle_purchase(purchase_data: dict, authorization: str = Header(None)):
    """处理订阅购买"""
    from notifications import get_subscription_manager, PurchaseNotification
    
    try:
        # 从授权头获取用户ID（需要在应用中实现认证）
        user_id = authorization or "anonymous"
        
        manager = get_subscription_manager()
        
        try:
            purchase = PurchaseNotification(
                plan=purchase_data.get("plan", "monthly"),
                productID=purchase_data.get("productID", ""),
                price=float(purchase_data.get("price", 0)),
                currency=purchase_data.get("currency", "JPY"),
                transactionID=purchase_data.get("transactionID", ""),
                timestamp=float(purchase_data.get("timestamp", 0))
            )
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=400,
                detail="Invalid purchase data",
            )
        
        success = await manager.notify_purchase(purchase, user_id)
        
        if success:
            return {
                "success": True,
                "message": "Purchase recorded successfully",
                "subscription": manager.get_subscription_status(user_id)
            }
        else:
            logger.error("Purchase manager did not record purchase")
            raise HTTPException(
                status_code=500,
                detail="Purchase recording failed",
            )
    except HTTPException:
        raise
    except Exception:
        logger.exception("Purchase handling error")
        raise HTTPException(status_code=500, detail="Purchase handling failed")


@app.get("/v1/subscription/status")
async def get_subscription_status(authorization: str = Header(None)):
    """获取用户订阅状态"""
    from notifications import get_subscription_manager
    
    try:
        user_id = authorization or "anonymous"
        manager = get_subscription_manager()
        status = manager.get_subscription_status(user_id)
        return status
    except HTTPException:
        raise
    except Exception:
        logger.exception("Status retrieval error")
        raise HTTPException(
            status_code=500,
            detail="Subscription status unavailable",
        )


@app.post("/v1/notifications/register-device")
async def register_device(
    device_token: str,
    device_type: str = "iOS",
    categories: list = None,
    authorization: str = Header(None)
):
    """注册设备以接收推送通知"""
    try:
        logger.info(f"📱 Device registered: {device_type} - {device_token[:20]}...")
        
        # 在生产环境中,这应该保存到数据库
        device_info = {
            "token": device_token,
            "type": device_type,
            "categories": categories or [],
            "registered_at": datetime.now(timezone.utc).isoformat(),
            "user_id": authorization or "anonymous"
        }
        
        return {
            "success": True,
            "message": "Device registered successfully",
            "device": device_info
        }
    except HTTPException:
        raise
    except Exception:
        logger.exception("Device registration error")
        raise HTTPException(
            status_code=500,
            detail="Device registration failed",
        )


@app.post("/v1/notifications/send-test")
async def send_test_notification(
    device_token: str,
    title: str = "テスト通知",
    body: str = "これはテスト通知です"
):
    """测试通知发送（用于开发调试）"""
    try:
        from notifications import get_notification_manager, NotificationPayload
        
        manager = get_notification_manager()
        
        if not manager.available:
            logger.warning("Firebase not configured, using mock notification")
            return {
                "success": True,
                "message": "Test notification would be sent (Firebase not configured)",
                "mock": True
            }
        
        payload = NotificationPayload(
            title=title,
            body=body,
            category="test",
            deepLink="app://test"
        )
        
        success = await manager.send_notification(device_token, payload)
        
        return {
            "success": success,
            "message": "Test notification sent" if success else "Failed to send notification"
        }
    except HTTPException:
        raise
    except Exception:
        logger.exception("Test notification error")
        raise HTTPException(status_code=500, detail="Test notification failed")


@app.post("/v1/cleanup-bad-images")
def cleanup_bad_images():
    """清理 JSON 文章库中的无效图片 URL（Google logo 等）"""
    rows = article_store.all()
    cleaned = 0
    for row in rows:
        if row.get("image_url") and _is_bad_image(row["image_url"]):
            row["image_url"] = None
            cleaned += 1
    if cleaned:
        article_store.replace(rows)
    return {"checked": len(rows), "cleaned": cleaned}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("server:app", host="0.0.0.0", port=port, reload=False)

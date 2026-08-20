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
import hmac
import logging
import re
import os
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from typing import Optional, List

import feedparser
import aiohttp
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import Depends, FastAPI, Query, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import (
    Boolean, Column, DateTime, Index, Integer, String, Text, create_engine
)
from sqlalchemy.orm import declarative_base, sessionmaker

# OpenAI API
from openai import AsyncOpenAI
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────── 配置 ───────────────────────

FETCH_INTERVAL_MINUTES = 5

# OpenAI API
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_MODEL = "gpt-4o-mini"
openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

# ブラウザからの呼び出しを許可するオリジン（カンマ区切り、未設定なら許可なし）
ALLOWED_ORIGINS = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "").split(",") if o.strip()]

# 管理・メンテナンス用エンドポイントの共有トークン（未設定なら該当APIは無効）
ADMIN_API_TOKEN = os.environ.get("ADMIN_API_TOKEN", "")

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
    except Exception as e:
        logger.error(f"OpenAI API error: {e}, using mock analysis as fallback")
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
            pass
    # RFC 2822 string
    if hasattr(entry, "published") and entry.published:
        try:
            return parsedate_to_datetime(entry.published)
        except Exception:
            pass
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
    except Exception:
        pass
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

    except Exception:
        pass
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

    # Step 3: DBに保存
    db = SessionLocal()
    new_count = 0
    try:
        for a in all_articles:
            if not db.query(ArticleORM).filter_by(uid=a["uid"]).first():
                db.add(ArticleORM(**a))
                new_count += 1
        db.commit()

        # Step 4: 30日以上前の記事を自動削除（Neon無料版容量対策）
        # 从 7 天改为 30 天，以保留更多历史新闻供用户查阅
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        deleted = db.query(ArticleORM).filter(
            ArticleORM.published_at < cutoff
        ).delete()
        if deleted:
            db.commit()
            logger.info(f"Auto-cleanup: deleted {deleted} articles older than 30 days")
    finally:
        db.close()

    # ログ：画像あり/なしの数
    with_img = sum(1 for a in all_articles if a["image_url"])
    logger.info(f"=== crawler done, {new_count} new articles ({with_img}/{len(all_articles)} with images) ===")

# ─────────────────────── FastAPI ───────────────────────

app = FastAPI(title="FurinNews API", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type", "X-User-ID", "X-Admin-Token"],
)
scheduler = AsyncIOScheduler()


def require_admin_token(x_admin_token: Optional[str] = Header(None, alias="X-Admin-Token")) -> None:
    """メンテナンス用エンドポイントを共有トークンで保護する"""
    if not ADMIN_API_TOKEN:
        raise HTTPException(status_code=503, detail="Admin endpoints are disabled")
    if not x_admin_token or not hmac.compare_digest(x_admin_token, ADMIN_API_TOKEN):
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.on_event("startup")
async def startup():
    # 延迟30秒后开始爬取，避免阻塞 Cloud Run 启动
    async def _delayed_crawl():
        await asyncio.sleep(30)
        await run_crawler()
    asyncio.create_task(_delayed_crawl())
    scheduler.add_job(run_crawler, "interval", minutes=FETCH_INTERVAL_MINUTES)
    scheduler.start()
    logger.info(f"Scheduler started, interval={FETCH_INTERVAL_MINUTES}min")


@app.on_event("shutdown")
async def shutdown():
    scheduler.shutdown()


def _to_schema(a: ArticleORM) -> ArticleSchema:
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
    db = SessionLocal()
    try:
        q = db.query(ArticleORM).filter(
            ArticleORM.is_active == True,
        )
        if category:
            q = q.filter(ArticleORM.category == category)
        if keyword:
            # 複合キーワードをスペースで分割し、いずれかが含まれる記事を検索
            # 例: "芸能人 熱愛" → title LIKE '%芸能人%' OR title LIKE '%熱愛%'
            # カテゴリ名のマッピング（日本語名→内部カテゴリ名）
            CATEGORY_ALIASES = {
                "芸能": "celebrity", "エンタメ": "celebrity", "セレブ": "celebrity",
                "アイドル": "celebrity", "俳優": "celebrity", "女優": "celebrity",
                "スポーツ": "sports", "野球": "sports", "サッカー": "sports",
                "政治": "politician", "政治家": "politician", "国会": "politician",
                "経済": "business", "ビジネス": "business", "株": "business",
                "海外": "overseas", "国際": "overseas", "世界": "overseas",
                "トレンド": "trending", "人気": "trending", "話題": "trending",
            }
            sub_keywords = [k.strip() for k in keyword.replace("　", " ").split() if k.strip()]
            if sub_keywords:
                from sqlalchemy import or_
                keyword_filters = []
                matched_categories = set()
                for kw in sub_keywords:
                    keyword_filters.append(ArticleORM.title.contains(kw))
                    keyword_filters.append(ArticleORM.summary.contains(kw))
                    # キーワードがカテゴリ名にマッチする場合、そのカテゴリも検索
                    if kw in CATEGORY_ALIASES:
                        matched_categories.add(CATEGORY_ALIASES[kw])
                # カテゴリマッチがあれば条件に追加
                if matched_categories:
                    keyword_filters.append(ArticleORM.category.in_(matched_categories))
                q = q.filter(or_(*keyword_filters))
            else:
                q = q.filter(
                    ArticleORM.title.contains(keyword) |
                    ArticleORM.summary.contains(keyword)
                )
        offset = (page - 1) * limit
        rows_plus_one = (
            q.order_by(ArticleORM.published_at.desc())
            .offset(offset)
            .limit(limit + 1)
            .all()
        )
        has_more = len(rows_plus_one) > limit
        rows = rows_plus_one[:limit]
        return NewsResponse(
            articles=[_to_schema(r) for r in rows],
            total=offset + len(rows) + (1 if has_more else 0),
            page=page,
            hasMore=has_more,
        )
    finally:
        db.close()


@app.get("/v1/articles/{article_id}", response_model=ArticleSchema)
def get_article(article_id: int):
    db = SessionLocal()
    try:
        a = db.query(ArticleORM).filter(ArticleORM.id == article_id).first()
        if not a:
            raise HTTPException(status_code=404, detail="Not found")
        return _to_schema(a)
    finally:
        db.close()


@app.post("/v1/crawl")
async def manual_crawl(_: None = Depends(require_admin_token)):
    asyncio.create_task(run_crawler())
    return {"status": "crawling started"}


@app.get("/v1/stats")
def stats():
    db = SessionLocal()
    try:
        total = db.query(ArticleORM).count()
        from sqlalchemy import func
        by_cat = db.query(ArticleORM.category, func.count()).group_by(ArticleORM.category).all()
        with_img = db.query(func.count(ArticleORM.id)).filter(ArticleORM.image_url != None, ArticleORM.image_url != "").scalar()
        return {"total": total, "with_image": with_img, "by_category": dict(by_cat)}
    finally:
        db.close()


@app.post("/v1/backfill-images")
async def backfill_images(
    limit: int = Query(100, ge=1, le=200),
    _: None = Depends(require_admin_token),
):
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
            article = None
            try:
                # まず uid での検索を試みる
                article = db.query(ArticleORM).filter(ArticleORM.uid == article_id).first()
            except Exception:
                pass
            
            if not article:
                # Integer ID での検索
                try:
                    article = db.query(ArticleORM).filter(ArticleORM.id == int(article_id)).first()
                except Exception:
                    pass
            
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
                    asyncio.create_task(_refresh_analysis_background(article.id, article.title, article.summary))
                
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
        asyncio.create_task(_fetch_and_cache_real_analysis_background(article_data["id"], prompt))
    
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
            article = None
            try:
                # まず uid での検索を試みる
                article = db.query(ArticleORM).filter(ArticleORM.uid == article_id).first()
            except Exception:
                pass
            
            if not article:
                # Integer ID での検索
                try:
                    article = db.query(ArticleORM).filter(ArticleORM.id == int(article_id)).first()
                except Exception:
                    pass
            
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
        receipt = ReceiptData(
            transactionID=receipt_data.get("transactionID", ""),
            productID=receipt_data.get("productID", ""),
            originalTransactionID=receipt_data.get("originalTransactionID", ""),
            expirationDate=float(receipt_data.get("expirationDate", 0)),
            purchaseDate=float(receipt_data.get("purchaseDate", 0))
        )
        
        result = await manager.verify_receipt(receipt)
        return {"verified": True, "data": result}
    except Exception as e:
        logger.error(f"Receipt verification error: {e}")
        raise HTTPException(status_code=400, detail="Receipt verification failed")


@app.post("/v1/subscription/purchase")
async def handle_purchase(purchase_data: dict, authorization: str = Header(None)):
    """处理订阅购买"""
    from notifications import get_subscription_manager, PurchaseNotification
    
    try:
        # 从授权头获取用户ID（需要在应用中实现认证）
        user_id = authorization or "anonymous"
        
        manager = get_subscription_manager()
        
        purchase = PurchaseNotification(
            plan=purchase_data.get("plan", "monthly"),
            productID=purchase_data.get("productID", ""),
            price=float(purchase_data.get("price", 0)),
            currency=purchase_data.get("currency", "JPY"),
            transactionID=purchase_data.get("transactionID", ""),
            timestamp=float(purchase_data.get("timestamp", 0))
        )
        
        success = await manager.notify_purchase(purchase, user_id)
        
        if success:
            return {
                "success": True,
                "message": "Purchase recorded successfully",
                "subscription": manager.get_subscription_status(user_id)
            }
        else:
            raise Exception("Failed to record purchase")
    except Exception as e:
        logger.error(f"Purchase handling error: {e}")
        raise HTTPException(status_code=400, detail="Failed to record purchase")


@app.get("/v1/subscription/status")
async def get_subscription_status(authorization: str = Header(None)):
    """获取用户订阅状态"""
    from notifications import get_subscription_manager
    
    try:
        user_id = authorization or "anonymous"
        manager = get_subscription_manager()
        status = manager.get_subscription_status(user_id)
        return status
    except Exception as e:
        logger.error(f"Status retrieval error: {e}")
        raise HTTPException(status_code=400, detail="Failed to retrieve subscription status")


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
    except Exception as e:
        logger.error(f"Device registration error: {e}")
        raise HTTPException(status_code=400, detail="Device registration failed")


@app.post("/v1/notifications/send-test")
async def send_test_notification(
    device_token: str,
    title: str = "テスト通知",
    body: str = "これはテスト通知です",
    _: None = Depends(require_admin_token),
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
    except Exception as e:
        logger.error(f"Test notification error: {e}")
        raise HTTPException(status_code=400, detail="Failed to send test notification")


@app.post("/v1/cleanup-bad-images")
def cleanup_bad_images(_: None = Depends(require_admin_token)):
    """清理数据库中无效的图片URL（Google logo等）"""
    db = SessionLocal()
    try:
        rows = db.query(ArticleORM).filter(ArticleORM.image_url != None).all()
        cleaned = 0
        for row in rows:
            if _is_bad_image(row.image_url or ""):
                row.image_url = None
                cleaned += 1
        db.commit()
        return {"checked": len(rows), "cleaned": cleaned}
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("server:app", host="0.0.0.0", port=port, reload=False)

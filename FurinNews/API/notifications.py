"""
推送通知和订阅管理模块
支持 Firebase Cloud Messaging (FCM) 和 Stripe 支付集成
"""

from datetime import datetime, timedelta, timezone
from typing import Optional, List
import json
import logging
from enum import Enum

# Firebase Admin SDK
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    logging.warning("Firebase Admin SDK not installed. Install with: pip install firebase-admin")

# Stripe (可选)
try:
    import stripe
    STRIPE_AVAILABLE = True
except ImportError:
    STRIPE_AVAILABLE = False

from pydantic import BaseModel

logger = logging.getLogger(__name__)


# ─────────────────────── データモデル ───────────────────────

class SubscriptionPlan(str, Enum):
    FREE = "free"
    MONTHLY = "monthly"
    YEARLY = "yearly"


class ReceiptData(BaseModel):
    transactionID: str
    productID: str
    originalTransactionID: str
    expirationDate: float
    purchaseDate: float


class PurchaseNotification(BaseModel):
    plan: str
    productID: str
    price: float
    currency: str
    transactionID: str
    timestamp: float


class NotificationPayload(BaseModel):
    title: str
    body: str
    category: str
    article_id: Optional[str] = None
    image_url: Optional[str] = None
    deepLink: Optional[str] = None


class FCMRegistration(BaseModel):
    user_id: str
    device_token: str
    device_type: str  # "iOS", "Android", "Web"
    subscribed_categories: List[str] = []


# ─────────────────────── Firebase 初期化 ───────────────────────

class FirebaseNotificationManager:
    """Firebase Cloud Messaging を使用した通知管理"""
    
    def __init__(self, credentials_path: Optional[str] = None):
        self.available = False
        
        if not FIREBASE_AVAILABLE:
            logger.warning("Firebase Admin SDK is not available")
            return
        
        try:
            # Firebase 認証情報ファイルのパス
            creds_path = credentials_path or "./firebase-credentials.json"
            
            # 既に初期化されていない場合は初期化
            if not firebase_admin._apps:
                cred = credentials.Certificate(creds_path)
                firebase_admin.initialize_app(cred)
            
            self.available = True
            logger.info("✅ Firebase initialized successfully")
        except Exception as e:
            logger.error(f"❌ Firebase initialization error: {e}")
            self.available = False
    
    async def send_notification(
        self,
        device_token: str,
        payload: NotificationPayload,
        data: Optional[dict] = None
    ) -> bool:
        """デバイスに通知を送信"""
        if not self.available:
            logger.warning("Firebase is not available, skipping notification")
            return False
        
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=payload.title,
                    body=payload.body,
                    image=payload.image_url
                ),
                data={
                    "category": payload.category,
                    "article_id": payload.article_id or "",
                    "deepLink": payload.deepLink or "",
                    **(data or {})
                },
                token=device_token,
            )
            
            response = messaging.send(message)
            logger.info(f"✅ Notification sent: {response}")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to send notification: {e}")
            return False
    
    async def send_multicast(
        self,
        device_tokens: List[str],
        payload: NotificationPayload,
        data: Optional[dict] = None
    ) -> dict:
        """複数デバイスに通知を送信"""
        if not self.available:
            logger.warning("Firebase is not available")
            return {"success": 0, "failure": len(device_tokens)}
        
        try:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=payload.title,
                    body=payload.body,
                    image=payload.image_url
                ),
                data={
                    "category": payload.category,
                    "article_id": payload.article_id or "",
                    **(data or {})
                },
                tokens=device_tokens,
            )
            
            response = messaging.send_multicast(message)
            logger.info(f"✅ Multicast sent: {response.success} success, {response.failure} failure")
            
            return {
                "success": response.success,
                "failure": response.failure,
                "responses": response.responses
            }
        except Exception as e:
            logger.error(f"❌ Multicast error: {e}")
            return {"success": 0, "failure": len(device_tokens)}
    
    async def subscribe_to_topic(self, device_tokens: List[str], topic: str) -> bool:
        """デバイスをトピックに購読させる"""
        if not self.available:
            return False
        
        try:
            response = messaging.make_topic_management_message(
                "subscribeToTopic",
                device_tokens,
                topic
            )
            logger.info(f"✅ Subscribed to topic '{topic}': {len(device_tokens)} devices")
            return True
        except Exception as e:
            logger.error(f"❌ Topic subscription error: {e}")
            return False


# ─────────────────────── 購読管理 ───────────────────────

class SubscriptionManager:
    """App Store 購入の検証と購読ステータスの管理"""
    
    # App Store Server API の URL
    SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt"
    PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt"
    
    def __init__(self, shared_secret: Optional[str] = None):
        self.shared_secret = shared_secret or os.environ.get("APP_STORE_SHARED_SECRET", "")
        self.subscriptions = {}  # In-memory store (本番環境では DB を使用)
    
    async def verify_receipt(self, receipt_data: ReceiptData) -> dict:
        """
        App Store のレシートを検証
        
        Args:
            receipt_data: クライアントから送信されたレシート情報
        
        Returns:
            検証結果
        """
        try:
            # トランザクション ID から購読ステータスを確認
            # 本番環境では App Store Server API を呼び出す
            
            expiration_date = datetime.fromtimestamp(
                receipt_data.expirationDate / 1000,  # ミリ秒から秒に変換
                tz=timezone.utc
            )
            
            is_active = expiration_date > datetime.now(timezone.utc)
            
            subscription_info = {
                "transactionID": receipt_data.transactionID,
                "productID": receipt_data.productID,
                "expirationDate": expiration_date.isoformat(),
                "isActive": is_active,
                "verificationTime": datetime.now(timezone.utc).isoformat()
            }
            
            logger.info(f"✅ Receipt verified: {subscription_info}")
            return subscription_info
        except Exception as e:
            logger.error(f"❌ Receipt verification error: {e}")
            return {"error": str(e), "verified": False}
    
    async def notify_purchase(self, purchase_info: PurchaseNotification, user_id: str) -> bool:
        """
        購入を記録し、ユーザーをアップグレード
        
        Args:
            purchase_info: 購入情報
            user_id: ユーザー ID
        
        Returns:
            成功/失敗
        """
        try:
            plan = SubscriptionPlan.MONTHLY if purchase_info.plan == "monthly" \
                   else SubscriptionPlan.YEARLY
            
            # 購読情報を保存（本番環境では DB）
            self.subscriptions[user_id] = {
                "plan": plan,
                "productID": purchase_info.productID,
                "price": purchase_info.price,
                "currency": purchase_info.currency,
                "transactionID": purchase_info.transactionID,
                "purchaseDate": datetime.fromtimestamp(purchase_info.timestamp),
                "expirationDate": self._calculate_expiration(purchase_info.plan)
            }
            
            logger.info(f"✅ Purchase recorded for user {user_id}: {plan}")
            return True
        except Exception as e:
            logger.error(f"❌ Purchase notification error: {e}")
            return False
    
    def _calculate_expiration(self, plan: str) -> datetime:
        """購読の有効期限を計算"""
        now = datetime.now(timezone.utc)
        if plan == "monthly":
            return now + timedelta(days=30)
        else:  # yearly
            return now + timedelta(days=365)
    
    def get_subscription_status(self, user_id: str) -> dict:
        """ユーザーの購読ステータスを取得"""
        if user_id not in self.subscriptions:
            return {"plan": "free", "isActive": False}
        
        subscription = self.subscriptions[user_id]
        is_active = subscription["expirationDate"] > datetime.now(timezone.utc)
        
        return {
            "plan": subscription["plan"],
            "isActive": is_active,
            "expirationDate": subscription["expirationDate"].isoformat()
        }


# ─────────────────────── 初期化 ───────────────────────

def get_notification_manager(
    firebase_creds_path: Optional[str] = None
) -> FirebaseNotificationManager:
    """通知マネージャーを取得または作成"""
    return FirebaseNotificationManager(firebase_creds_path)


def get_subscription_manager() -> SubscriptionManager:
    """購読マネージャーを取得または作成"""
    return SubscriptionManager()


# ─────────────────────── ユーティリティ ───────────────────────

def create_news_notification(
    title: str,
    summary: str,
    category: str,
    article_id: str,
    image_url: Optional[str] = None
) -> NotificationPayload:
    """ニュース通知ペイロードを作成"""
    return NotificationPayload(
        title=title,
        body=summary,
        category=category,
        article_id=article_id,
        image_url=image_url,
        deepLink=f"app://article/{article_id}"
    )


def create_subscription_notification(
    action: str,
    message: str
) -> NotificationPayload:
    """購読関連の通知ペイロードを作成"""
    return NotificationPayload(
        title="購読情報",
        body=message,
        category="subscription",
        deepLink="app://subscription"
    )

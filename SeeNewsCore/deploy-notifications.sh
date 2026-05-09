#!/bin/bash

# 🚀 SeeNews IAP 和推送通知快速部署脚本
# 用法: bash deploy-notifications.sh

set -e  # 遇到错误立即退出

echo "════════════════════════════════════════════════"
echo "   🔔 SeeNews 推送通知和 IAP 部署脚本"
echo "════════════════════════════════════════════════"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# MARK: - 检查先决条件
echo -e "${YELLOW}📋 检查先决条件...${NC}"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python3 已安装${NC}"

# 检查 gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✅ gcloud 已安装${NC}"

# 检查 Xcode
if ! xcode-select -p &> /dev/null; then
    echo -e "${RED}❌ Xcode Command Line Tools 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Xcode 已安装${NC}"

echo ""

# MARK: - 安装后端依赖
echo -e "${YELLOW}📦 安装后端依赖...${NC}"
cd API

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --quiet
    echo -e "${GREEN}✅ 后端依赖已安装${NC}"
else
    echo -e "${RED}❌ 找不到 requirements.txt${NC}"
    exit 1
fi

cd ..

echo ""

# MARK: - Firebase 配置检查
echo -e "${YELLOW}🔥 检查 Firebase 配置...${NC}"

if [ -f "API/firebase-credentials.json" ]; then
    echo -e "${GREEN}✅ Firebase 证书文件已存在${NC}"
else
    echo -e "${YELLOW}⚠️  未找到 firebase-credentials.json${NC}"
    echo "   请从 Firebase Console 下载服务账户密钥"
    echo "   路径: 项目设置 > 服务账户 > 生成私密秘钥 (JSON)"
    echo "   保存到: API/firebase-credentials.json"
    echo ""
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

# MARK: - 后端部署
echo -e "${YELLOW}🚀 部署后端...${NC}"

PROJECT_ID="seenews-backend"

# 检查当前项目
CURRENT_PROJECT=$(gcloud config get-value project)
echo "当前 GCP 项目: $CURRENT_PROJECT"

if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo "切换到项目: $PROJECT_ID"
    gcloud config set project $PROJECT_ID
fi

# 部署
echo "开始部署到 Cloud Run..."
cd API

gcloud run deploy newsnow-backend \
  --source . \
  --region asia-northeast1 \
  --platform managed \
  --allow-unauthenticated \
  --memory 512Mi \
  --min-instances 1 \
  --set-env-vars "FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json" \
  --quiet

SERVICE_URL=$(gcloud run services describe newsnow-backend \
  --region asia-northeast1 \
  --format 'value(status.url)')

cd ..

echo -e "${GREEN}✅ 后端已部署${NC}"
echo "   URL: $SERVICE_URL"

echo ""

# MARK: - iOS 配置
echo -e "${YELLOW}📱 iOS 配置检查...${NC}"

# 检查 Bundle ID
BUNDLE_ID="com.3secnews.app"
echo "应用 Bundle ID: $BUNDLE_ID"

echo ""
echo -e "${YELLOW}⚠️  需要手动配置的项目:${NC}"
echo ""
echo "1️⃣  App Store Connect 配置:"
echo "   ├─ Bundle ID: $BUNDLE_ID"
echo "   ├─ 推送通知: 启用"
echo "   ├─ APNs 证书: 上传 .p8 密钥"
echo "   └─ In-App Purchase:"
echo "      ├─ com.3secnews.pro.monthly (¥680)"
echo "      └─ com.3secnews.pro.yearly (¥6,800)"
echo ""
echo "2️⃣  Xcode 配置:"
echo "   ├─ 目标 > Signing & Capabilities"
echo "   ├─ [✓] Push Notifications"
echo "   └─ [✓] Background Modes"
echo ""
echo "3️⃣  后端通知端点:"
echo "   ├─ POST $SERVICE_URL/v1/notifications/register-device"
echo "   ├─ POST $SERVICE_URL/v1/notifications/send-test"
echo "   ├─ POST $SERVICE_URL/v1/subscription/verify-receipt"
echo "   └─ POST $SERVICE_URL/v1/subscription/purchase"
echo ""

# MARK: - 测试
echo -e "${YELLOW}🧪 快速测试${NC}"

echo "1. 测试健康检查:"
HEALTH_CHECK=$(curl -s "$SERVICE_URL/v1/health")
if echo "$HEALTH_CHECK" | grep -q "status"; then
    echo -e "${GREEN}✅ 后端响应正常${NC}"
else
    echo -e "${RED}❌ 后端无响应${NC}"
fi

echo ""
echo "2. 测试通知端点:"
echo "   curl -X POST \"$SERVICE_URL/v1/notifications/send-test\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"device_token\": \"your-token\", \"title\": \"テスト\"}'"
echo ""

# MARK: - 完成
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ 部署完成!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "📚 下一步:"
echo "   1. 查看: IAP_NOTIFICATIONS_GUIDE.md"
echo "   2. 在 App Store Connect 配置 In-App Purchase"
echo "   3. 上传 Firebase 凭证文件"
echo "   4. 在 Xcode 中构建和测试"
echo ""
echo "🔗 有用链接:"
echo "   • Firebase Console: https://console.firebase.google.com"
echo "   • App Store Connect: https://appstoreconnect.apple.com"
echo "   • Cloud Run Dashboard: https://console.cloud.google.com/run"
echo ""

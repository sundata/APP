#!/bin/bash

# 🛍️ IAP 诊断脚本 - 检查 In-App Purchase 配置
# 使用: bash check-iap-config.sh

echo "════════════════════════════════════════════════"
echo "   🛍️ IAP 配置诊断检查"
echo "════════════════════════════════════════════════"
echo ""

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# MARK: 检查项目配置
echo -e "${BLUE}📋 检查项目配置${NC}"
echo ""

# 检查 Bundle ID
BUNDLE_ID="com.3secnews.app"
echo "✓ 预期 Bundle ID: $BUNDLE_ID"

# 检查产品 ID
MONTHLY_ID="com.3secnews.pro.monthly"
YEARLY_ID="com.3secnews.pro.yearly"

echo "✓ 月度产品 ID: $MONTHLY_ID"
echo "✓ 年度产品 ID: $YEARLY_ID"

echo ""

# MARK: 检查 PurchaseManager 代码
echo -e "${BLUE}📂 检查源代码配置${NC}"
echo ""

PURCHASE_FILE="Services/PurchaseManager.swift"

if [ ! -f "$PURCHASE_FILE" ]; then
    echo -e "${RED}❌ 找不到文件: $PURCHASE_FILE${NC}"
    exit 1
fi

# 检查产品标识符
if grep -q "com.3secnews.pro.monthly" "$PURCHASE_FILE" && \
   grep -q "com.3secnews.pro.yearly" "$PURCHASE_FILE"; then
    echo -e "${GREEN}✅ 产品 ID 在代码中正确配置${NC}"
else
    echo -e "${RED}❌ 产品 ID 在代码中配置错误${NC}"
fi

echo ""

# MARK: 检查 App Store Connect 要求
echo -e "${BLUE}☁️ App Store Connect 需求清单${NC}"
echo ""

echo "按照以下顺序完成:"
echo ""
echo "1️⃣  创建订阅组"
echo "    名称: com.3secnews.pro"
echo ""
echo "2️⃣  创建月度订阅"
echo "    产品 ID: $MONTHLY_ID"
echo "    价格: ¥680"
echo "    状态: 可供出售"
echo ""
echo "3️⃣  创建年度订阅"
echo "    产品 ID: $YEARLY_ID"
echo "    价格: ¥6,800"
echo "    状态: 可供出售"
echo ""
echo "4️⃣  配置 APNs 证书"
echo "    类型: Apple Push Notifications"
echo "    状态: 已激活"
echo ""

# MARK: 当前日志输出
echo -e "${BLUE}🧪 当前日志输出${NC}"
echo ""
echo "应用启动时应该看到:"
echo ""
echo -e "${YELLOW}📦 Requesting products for IDs: $MONTHLY_ID, $YEARLY_ID${NC}"
echo ""
echo "如果看到的是:"
echo -e "${RED}⚠️ Received 0 products${NC}"
echo ""
echo "原因: App Store Connect 中未配置这些产品"
echo ""

# MARK: 快速链接
echo -e "${BLUE}🔗 快速链接${NC}"
echo ""
echo "1. App Store Connect:"
echo "   https://appstoreconnect.apple.com"
echo ""
echo "2. 应用内购买配置:"
echo "   App Store Connect > 应用 > 功能 > In-App Purchases"
echo ""
echo "3. Apple 文档:"
echo "   https://help.apple.com/app-store-connect/#/dev3a5f4da7"
echo ""

# MARK: 沙箱测试账户
echo -e "${BLUE}🧪 沙箱测试账户设置${NC}"
echo ""
echo "创建测试账户:"
echo "  1. App Store Connect > 用户和访问权限"
echo "  2. 沙箱用户 > +"
echo "  3. 填写详细信息"
echo ""
echo "在设备上测试:"
echo "  设置 > App Store > 注销"
echo "  使用沙箱账户登录"
echo "  在应用中尝试购买"
echo ""

# MARK: 预期完成后的输出
echo -e "${BLUE}✅ 完成后预期的日志输出${NC}"
echo ""
echo -e "${GREEN}📦 Requesting products for IDs: $MONTHLY_ID, $YEARLY_ID${NC}"
echo -e "${GREEN}✅ Received 2 products${NC}"
echo -e "${GREEN}💾 Stored 2 products${NC}"
echo -e "${GREEN}  - $MONTHLY_ID: ¥680${NC}"
echo -e "${GREEN}  - $YEARLY_ID: ¥6,800${NC}"
echo ""

echo "════════════════════════════════════════════════"
echo -e "${GREEN}✅ 诊断完成${NC}"
echo "════════════════════════════════════════════════"

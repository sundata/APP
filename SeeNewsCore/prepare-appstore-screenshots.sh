#!/bin/bash

# 📱 App Store 审查截图快速检查表
# 用法: bash prepare-appstore-screenshots.sh

echo \"🎬 App Store 审查截图准备指南\"
echo \"=================================\"
echo \"\"

# 颜色代码
GREEN='\\033[0;32m'
RED='\\033[0;31m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

echo \"${BLUE}步骤 1: 编译应用到 iPhone 模拟器${NC}\"
echo \"=================================\"
echo \"\"
echo \"在 Xcode 中操作：\"
echo \"  1. 打开: /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore/SeeNews.xcworkspace\"
echo \"  2. 选择目标设备: iPhone 14 Pro 或 iPhone 13 Pro\"
echo \"  3. 点击 ▶️ Run 按钮编译\"
echo \"\"
echo \"--> 继续按 Enter 以获取截图...\"
read -p \"已编译完成? (y/n): \" compiled

if [ \"$compiled\" != \"y\" ]; then
    echo \"${RED}✗ 请先在 Xcode 中编译应用${NC}\"
    exit 1
fi

echo \"\"
echo \"${BLUE}步骤 2: 获取截图${NC}\"
echo \"=================================\"
echo \"\"

echo \"${YELLOW}截图 1: AI 分析功能演示（必须）${NC}\"
echo \"  操作流程：\"
echo \"    1. 打开应用主页\"
echo \"    2. 点击任一新闻文章\"
echo \"    3. 点击 '3秒で理解' 按钮\"
echo \"    4. 等待 AI 分析内容显示\"
echo \"    5. 按 Cmd + S 拍摄截图\"
echo \"    6. 保存文件名: screenshot_1_ai_analysis.png\"
echo \"\"
read -p \"已获取截图 1? (y/n): \" ss1
if [ \"$ss1\" != \"y\" ]; then
    echo \"${RED}✗ 请获取截图 1${NC}\"
else
    echo \"${GREEN}✓ 截图 1 完成${NC}\"
fi

echo \"\"
echo \"${YELLOW}截图 2: Pro 功能 - 无广告体验${NC}\"
echo \"  操作流程：\"
echo \"    1. 返回主页\"
echo \"    2. 滚动查看主日期信息流\"
echo \"    3. 确保已隐藏广告横幅（Pro 用户体验）\"
echo \"    4. 按 Cmd + S 拍摄截图\"
echo \"    5. 保存文件名: screenshot_2_no_ads.png\"
echo \"\"
read -p \"已获取截图 2? (y/n): \" ss2
if [ \"$ss2\" != \"y\" ]; then
    echo \"${YELLOW}⚠️  截图 2 可选，但建议包含${NC}\"
else
    echo \"${GREEN}✓ 截图 2 完成${NC}\"
fi

echo \"\"
echo \"${YELLOW}截图 3: 订阅价格页面（可选）${NC}\"
echo \"  操作流程：\"
echo \"    1. 点击设置 (⚙️)\"
echo \"    2. 滚动找到 Pro 订阅部分\"
echo \"    3. 显示价格信息: ¥680/月，¥6,800/年\"
echo \"    4. 按 Cmd + S 拍摄截图\"
echo \"    5. 保存文件名: screenshot_3_pricing.png\"
echo \"\"
read -p \"已获取截图 3? (y/n): \" ss3
if [ \"$ss3\" != \"y\" ]; then
    echo \"${YELLOW}⚠️  截图 3 可选${NC}\"
else
    echo \"${GREEN}✓ 截图 3 完成${NC}\"
fi

echo \"\"
echo \"${BLUE}步骤 3: 查找并整理截图文件${NC}\"
echo \"=================================\"
echo \"\"

SCREENSHOT_DIR=\"$HOME/Library/Developer/Simulator/Devices/\"

if [ -d \"$SCREENSHOT_DIR\" ]; then
    echo \"${GREEN}✓ 找到模拟器截图目录${NC}\"
    echo \"  位置: $SCREENSHOT_DIR\"
    echo \"\"
    echo \"模拟器中保存的截图：\"
    find \"$SCREENSHOT_DIR\" -name \"*.png\" -type f -newer /tmp 2>/dev/null | head -20 | while read file; do
        echo \"  - $(basename \"$file\")\"
    done
else
    echo \"${YELLOW}⚠️  模拟器截图目录不存在${NC}\"
    echo \"  可能原因: 模拟器中可能没有保存文件\"
fi

echo \"\"
echo \"${BLUE}步骤 4: 在桌面创建截图文件夹${NC}\"
echo \"=================================\"
echo \"\"

DESKTOP_SCREENSHOTS=\"$HOME/Desktop/AppStore_Screenshots\"
mkdir -p \"$DESKTOP_SCREENSHOTS\"

echo \"✓ 已创建文件夹: $DESKTOP_SCREENSHOTS\"
echo \"\"
echo \"请将以下文件复制到这个目录：\"
echo \"  - screenshot_1_ai_analysis.png (必须) ← AI 分析功能演示\"
echo \"  - screenshot_2_no_ads.png (推荐) ← Pro 无广告体验\"
echo \"  - screenshot_3_pricing.png (可选) ← 订阅价格\"
echo \"\"

echo \"${BLUE}步骤 5: 上传到 App Store Connect${NC}\"
echo \"=================================\"
echo \"\"
echo \"完成以下操作：\"
echo \"  1. 访问: https://appstoreconnect.apple.com\"
echo \"  2. 登录 Apple ID\"
echo \"  3. 选择应用 → 3秒ニュース\"
echo \"  4. 点击 \"アプリ内購入\" (In-App Purchases)\"
echo \"  5. 选择 \"Pro Monthly\" (com.3secnews.pro.monthly)\"
echo \"  6. 滚动找到 \"スクリーンショット\" (Screenshots) 部分\"
echo \"  7. 点击 \"+\" 按钮\"
echo \"  8. 上传 1-5 张截图\"
echo \"  9. 点击 \"保存\" (Save)\"
echo \"\"

echo \"${BLUE}步骤 6: 完成元数据验证${NC}\"
echo \"=================================\"
echo \"\"

# 检查清单
echo \"验证以下信息已正确填写：\"
echo \"\"

checkboxes=(
    \"✓ 产品 ID: com.3secnews.pro.monthly\"
    \"✓ 参考名称: Pro Monthly\"
    \"✓ 表示名: Proプラン\"
    \"✓ 説明: AI分析無制限・深度解読・広告なし\"
    \"✓ 定価: ¥680/月\"
    \"✓ 上传最少 1 张截图\"
    \"✓ ステータス: メタデータが不足 → 準備完了\"
)

for cb in \"${checkboxes[@]}\"; do
    echo \"  $cb\"
done

echo \"\"
echo \"${BLUE}步骤 7: 提交审查${NC}\"
echo \"=================================\"
echo \"\"
echo \"准备工作：\"
echo \"  1. 确保 iOS 应用版本已更新 (v1.1+)\"
echo \"  2. 二进制文件已上传到新版本\"
echo \"  3. 选择此订阅为该版本的 In-App Purchase\"
echo \"\"
echo \"然后：\"
echo \"  1. 点击 \"提出準備中\" (Ready to Submit)\"
echo \"  2. 添加审查备注：\"
echo \"     \"This subscription provides unlimited AI news analysis, deep\"
echo \"     insights, and an ad-free experience. Users can preview Pro\"
echo \"     features before subscribing.\"\"
echo \"  3. 点击 \"提出\" (Submit for Review)\"
echo \"\"

echo \"${GREEN}=================================\"
echo \"🎉 截图准备完成！${NC}\"
echo \"=================================${NC}\"
echo \"\"
echo \"下一步: 等待 Apple 审查（通常 1-24 小时）\"
echo \"\"
echo \"💡 如果审查被拒，常见原因：\"
echo \"  - 截图不清晰或不展示 Pro 功能\"
echo \"  - 缺少审查备注说明\"
echo \"  - App 版本问题\"
echo \"\"
echo \"📖 更多信息请看: APPSTORE_SCREENSHOTS_GUIDE.md\"
echo \"\"

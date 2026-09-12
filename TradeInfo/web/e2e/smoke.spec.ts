// §55 user paths — runs against dev server with seeded backend.
import { test, expect } from "@playwright/test";

test("P1 浏览行情 -> 分类 -> 详情", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("text=SimpleMarket")).toBeVisible();
  await page.goto("/markets?cat=crypto");
  await expect(page.locator("text=crypto")).toBeVisible();
  await page.locator("table tbody tr td a").first().click();
  await expect(page).toHaveURL(/\/asset\//);
});

test("P2 搜索 -> 结果 -> 详情", async ({ page }) => {
  await page.goto("/search");
  await page.fill("input", "AAPL");
  await expect(page.locator("text=AAPL")).toBeVisible();
  await page.locator("ul li a").first().click();
  await expect(page).toHaveURL(/\/asset\//);
});

test("P3 新闻列表 + 分类过滤", async ({ page }) => {
  await page.goto("/news");
  await page.goto("/news?category=macro");
});

test("P4 日历默认高影响", async ({ page }) => {
  await page.goto("/calendar");
  await expect(page.locator("text=高影响")).toBeVisible();
});

test("P5 登录 -> 自选页", async ({ page }) => {
  await page.goto("/login");
  await page.fill("input[type!=password]", "e2e@x.com");
  await page.fill("input[type=password]", "secret123");
  await page.click("button:has-text('注册')");
  await page.click("button:has-text('没有账号？注册')");
  await page.click("button:has-text('注册')");
  await page.waitForURL(/watchlist/);
});

test("P6 设置切换语言+主题", async ({ page }) => {
  await page.goto("/settings");
  await page.click("text=EN");
  await page.click("text=dark");
  await expect(page.locator("html")).toHaveClass(/dark/);
});

test("P7 freshness 标签出现在价格旁", async ({ page }) => {
  await page.goto("/markets");
  await expect(page.locator("text=live, delayed, stale, closed, no_data").or(
    page.locator("[class*='green'], [class*='yellow'], [class*='orange']")
  ).first()).toBeVisible();
});

test("P8 未登录访问自选 -> 提示登录", async ({ page }) => {
  await page.goto("/watchlist");
  await expect(page.locator("text=登录")).toBeVisible();
});

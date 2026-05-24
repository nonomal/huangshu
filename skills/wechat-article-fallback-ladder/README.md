# wechat-article-fallback-ladder

公众号文章抓取失败时的证据兜底 Skill。

它不会在 `mp.weixin.qq.com` 返回验证码、环境异常、空正文时直接放弃，而是先自动尝试本地 Playwright 和代理抓取，再把失败产物、可读正文、错误信息和证据等级保存下来，方便继续做浏览器 DOM、群聊上下文、镜像搜索或 OCR 兜底。

## 一键安装

推荐复制这一行到终端执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Backtthefuture/huangshu/main/skills/wechat-article-fallback-ladder/bootstrap.sh)
```

脚本会自动：

1. 把 skill 安装到 `~/.claude/skills/wechat-article-fallback-ladder/`
2. 检查 `python3`、`curl`、`fetch_weixin_robust.sh`
3. 如果检测到 `~/.codex/`，同步注册到 `~/.codex/skills/wechat-article-fallback-ladder`
4. 检查本机是否已有 `qiaomu-markdown-proxy`，没有也能跑代理兜底，但本地 Playwright 抓取能力会弱一些

## 标准安装

如果只想用 huangshu 统一的 skill 安装方式：

```bash
npx skills add Backtthefuture/huangshu --skill wechat-article-fallback-ladder -a claude-code -g -y
bash ~/.claude/skills/wechat-article-fallback-ladder/install.sh
```

装完后完全退出 Claude Code 再重新打开。

## 手动安装

```bash
git clone https://github.com/Backtthefuture/huangshu.git
bash huangshu/skills/wechat-article-fallback-ladder/install.sh
```

## 使用方式

在 Claude Code 或 Codex 中直接说：

```text
读这篇公众号：https://mp.weixin.qq.com/s/...
抓一下这个微信链接，抓不到全文就找镜像和群聊上下文：https://mp.weixin.qq.com/s/...
```

也可以在终端直接跑自动抓取脚本：

```bash
URL="https://mp.weixin.qq.com/s/..."
OUT="$HOME/Downloads/wechat_article_fallback/$(date +%Y%m%d_%H%M%S)"
bash ~/.claude/skills/wechat-article-fallback-ladder/scripts/fetch_weixin_robust.sh "$URL" "$OUT"
```

脚本会输出 JSON，并在 `$OUT` 下保存：

- `original_url.txt`
- `article.md`
- `proxy.md`
- `jina.md`
- `defuddle.md`
- `*.err`
- `README.md`
- `report.json`

## 证据等级

- `全文已读`：原文正文已提取。
- `proxy可读正文`：代理返回了可读正文。
- `浏览器可见文本`：浏览器 DOM 可见文本。
- `镜像来源`：镜像或转载源提供正文。
- `标题摘要级`：只有标题、摘要、卡片或搜索片段。
- `群聊上下文`：来自本地微信聊天记录的分享和讨论。
- `截图OCR`：来自截图识别。
- `不可访问`：没有拿到可用证据。

## 可选增强

这个 skill 会自动寻找本机的 `qiaomu-markdown-proxy`：

```text
~/.claude/skills/qiaomu-markdown-proxy
~/.codex/skills/qiaomu-markdown-proxy
~/.Codex/skills/qiaomu-markdown-proxy
~/.agents/skills/qiaomu-markdown-proxy
```

如果找到了，会优先调用它的 `scripts/fetch_weixin.py` 和 `scripts/fetch.sh`。如果没找到，仍会用 `r.jina.ai` 和 `defuddle.md` 做诊断和代理兜底。

`fetch_weixin.py` 的完整能力通常需要：

```bash
python3 -m pip install --user playwright beautifulsoup4 lxml
python3 -m playwright install chromium
```

## 输出原则

这个 skill 的核心约束是：不能把验证码页、环境异常页、标题摘要或群聊讨论当成已读全文。最终回答必须明确说明当前证据边界。

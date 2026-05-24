---
name: wechat-article-fallback-ladder
description: |
  Evidence-preserving fallback workflow for fetching WeChat public-account articles from mp.weixin.qq.com when normal markdown extraction fails, returns captcha/环境异常/Access Denied/empty #js_content, or only produces title/snippet output. Use for reading, saving, summarizing, researching, or tracing WeChat articles; first run the bundled robust fetch wrapper, then escalate to browser DOM extraction, local WeChat context, mirror/source search, OCR, and bounded reporting without overstating evidence.
---

# WeChat Article Fallback Ladder

## Core Rule

Never stop at the first failed fetch unless the user explicitly asks to try only once. Never claim "全文已读" unless the original article body or a reliable full-text mirror was actually obtained.

Always preserve artifacts and state the evidence boundary:

- `全文已读`: original article body was extracted.
- `proxy可读正文`: a proxy returned substantive article text.
- `浏览器可见文本`: visible browser DOM text was extracted.
- `镜像来源`: a separate source or repost supplied the text.
- `标题摘要级`: only title, preview, snippet, or card metadata is available.
- `群聊上下文`: local chat records discuss or share the article.
- `截图OCR`: text came from image OCR.
- `不可访问`: no usable article evidence was found.

## Quick Start

Resolve `SKILL_DIR` to the directory that contains this `SKILL.md`, then run the bundled wrapper:

```bash
URL="https://mp.weixin.qq.com/s/..."
OUT="$HOME/Downloads/wechat_article_fallback/$(date +%Y%m%d_%H%M%S)"
bash "$SKILL_DIR/scripts/fetch_weixin_robust.sh" "$URL" "$OUT"
```

The script saves artifacts under `$OUT`, writes `$OUT/README.md` and `$OUT/report.json`, and prints the JSON report to stdout.

Interpret the report before continuing:

- `status=full_text`: proceed with normal reading, saving, or analysis.
- `status=partial`: use the extracted text, but disclose the proxy/source boundary.
- `status=blocked`: continue the manual ladder below.

## Manual Ladder

Use these steps only after the wrapper fails or returns weak evidence.

### 1. Browser DOM

Open the URL in a browser. If text is visible, extract and save it as `$OUT/browser_dom.md`:

```javascript
({
  title: document.querySelector('#activity-name')?.innerText,
  author: document.querySelector('#js_author_name')?.innerText,
  time: document.querySelector('#publish_time')?.innerText,
  content: document.querySelector('#js_content')?.innerText || document.body.innerText
})
```

Mark this as `浏览器可见文本`, not automatically `全文已读`, unless the full article body is present.

### 2. Local WeChat Context

Use local WeChat search tools when available. Search in this order:

1. exact article URL or article id
2. exact title
3. distinctive title keywords
4. account name plus title keywords

Collect the sharer, chat name, timestamp, card title/summary, and nearby discussion. Save notes as `$OUT/wechat_context.md`. Mark as `群聊上下文/标题摘要级`, not `全文已读`.

If using the decrypted local database directly, refresh or state staleness before relying on it:

```bash
cd /Users/superhuang/Documents/wechat-decrypt
python3 main.py decrypt
```

### 3. Mirror and Source Search

Search for full-text mirrors and primary sources:

```text
"exact article title"
"公众号名" "文章标题关键词"
"distinctive quote from snippet"
site:mp.weixin.qq.com/s "文章标题关键词"
site:sohu.com "文章标题关键词"
site:toutiao.com "文章标题关键词"
site:qq.com "文章标题关键词"
```

Prefer evidence in this order:

1. original author/source page
2. official repost / authorized mirror
3. major platform mirror with full text
4. search snippet/title only
5. social/chat discussion only

Save sources under `$OUT/sources/` and list URL plus evidence level.

### 4. Screenshot or OCR

If the article or key claim is embedded as screenshot:

- extract image URL when possible
- run vision/OCR
- mark OCR as `截图级证据`
- do not treat OCR as official source unless the screenshot itself is verifiably official

## Output Shape

Final responses must separate confirmed facts from unavailable or inferred claims:

```markdown
已处理：`URL`
保存目录：`$OUT`

## 抓取结果

- 原文全文：成功/失败
- 可用证据：全文 / proxy / 浏览器DOM / 镜像 / 群聊上下文 / 截图OCR / 搜索摘要 / 不可访问
- 证据边界：{一句话说清楚不能过度声称的内容}

## 文章核心内容 / 可确认信息

{只写当前证据支持的内容}

## 仍未确认

- {无法从当前证据确认的点}

## 对黄叔的可用价值

- 选题价值：...
- 表达结构：...
- 可沉淀金句/素材：...
```

## qiaomu-markdown-proxy Patch Pattern

When adapting this upstream, add `scripts/fetch_weixin_robust.sh` with these responsibilities:

1. call local Playwright `fetch_weixin.py`
2. validate content against captcha/error/short-page false positives
3. call qiaomu proxy cascade and direct proxies
4. save stdout, stderr, original URL, README, and JSON report
5. leave browser DOM, local WeChat context, mirror search, and OCR as explicit next steps

```json
{
  "url": "...",
  "status": "full_text|partial|blocked",
  "evidence_level": "全文已读|proxy可读正文|jina可读正文|defuddle可读正文|不可访问",
  "output_dir": "...",
  "files": ["original_url.txt", "article.md", "fetch_weixin.err", "README.md", "report.json"],
  "warnings": ["original page returned 环境异常 via r.jina.ai"]
}
```

## Common Pitfalls

- Treating `r.jina.ai` environment-error pages as successful markdown.
- Saying "读完了" when only title/summary was available.
- Ignoring local WeChat context; for 黄叔, the discussion around an article is often more valuable than the article.
- Deleting failure artifacts; failed outputs are useful evidence for why fallback was needed.
- Spending too long fighting captcha. Do not solve captcha; switch to bounded evidence workflow.

## Verification Checklist

- [ ] At least two fetch methods tried before declaring failure.
- [ ] Error/captcha pages detected and not summarized as article content.
- [ ] All artifacts saved to a folder.
- [ ] Evidence level stated explicitly.
- [ ] If local WeChat data is used, refresh status or timestamp boundary is stated.
- [ ] Final answer separates confirmed facts from unavailable/unverified claims.

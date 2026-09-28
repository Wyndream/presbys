# AGENTS.md

- 纯 `bash` + `curl` + `jq` + `awk`，零第三方依赖；不得引入包管理器、运行时或构建步骤。
- 输出一律进 `out/`（gitignored）。`docs/` 是 Pages 发布产物，**只经 Actions `publish` workflow 刷新**（Actions 页手动触发：云端复跑脚本 → 有变化才提交 main → Pages 自动部署）；本地可 `./presbys.sh --out docs` 验证，但不得直接提交 `docs/`（`snapshot_*.json` 不进 git）。
- 数据源只认 openctp dict API（`types=futures`）；返回天然只含在市合约，不要自行加退市过滤。
- 统计口径见 README「口径」节，是铁律；改口径必须同步改 README、HTML 模板 footer 与本节。
- HTML 结构改 `template.html`，表格行/卡片生成逻辑在 `presbys.sh` 的 jq 段，占位符为 `<!--ROWS-->` / `<!--CARDS-->` / `@AS_OF@`。产物对（快照，as-of）必须确定——不得引入墙钟时间戳之类的不确定源，publish 的「无变化跳过」靠 diff 判空。
- 中文行文一律全角标点；代码、路径、命令内保持半角。

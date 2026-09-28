# AGENTS.md

- 纯 `bash` + `curl` + `jq` + `awk`，零第三方依赖；不得引入包管理器、运行时或构建步骤。
- 输出一律进 `out/`（gitignored）。`docs/` 是随仓库发布的样例，用 `./presbys.sh --out docs` 刷新后再提交（`snapshot_*.json` 不进 git）。
- 数据源只认 openctp dict API（`types=futures`）；返回天然只含在市合约，不要自行加退市过滤。
- 统计口径见 README「口径」节，是铁律；改口径必须同步改 README、HTML 模板 footer 与本节。
- HTML 结构改 `template.html`，表格行/卡片生成逻辑在 `presbys.sh` 的 jq 段，占位符为 `<!--ROWS-->` / `<!--CARDS-->` / `@AS_OF@` / `@GENERATED@`。
- 中文行文一律全角标点；代码、路径、命令内保持半角。

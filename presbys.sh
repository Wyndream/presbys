#!/usr/bin/env bash
# πρέσβυς (presbys) — 找出每个期货品种最年长的在市合约，量它已伫立多少自然日
# 数据源: openctp 合约信息接口 (http://dict.openctp.cn/instruments?types=futures)
# 依赖: bash, curl, jq, awk
set -euo pipefail

API="http://dict.openctp.cn/instruments?types=futures"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AS_OF="$(date +%F)"
OUT="out"
INPUT=""

usage() {
  cat <<'EOF'
用法: ./presbys.sh [--as-of YYYY-MM-DD] [--out DIR] [--input FILE]

  --as-of   天数计算终点，默认今天
  --out     输出目录，默认 ./out
  --input   复用已有快照 JSON（离线模式，不再拉取）

产物: index.html, presbys_products.csv, presbys_contracts.csv, snapshot_<as-of>.json
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --as-of) AS_OF="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for dep in curl jq awk; do
  command -v "$dep" >/dev/null 2>&1 || { echo "缺少依赖: $dep" >&2; exit 127; }
done

mkdir -p "$OUT"

if [ -n "$INPUT" ]; then
  SNAPSHOT="$INPUT"
else
  SNAPSHOT="$OUT/snapshot_$AS_OF.json"
  echo "拉取快照: $API"
  curl -sf --max-time 120 "$API" -o "$SNAPSHOT"
fi

read -r -d '' JQ_DEFS <<'JQ' || true
def tier($d):
  if $d >= 1825 then "≥5y"
  elif $d >= 1095 then "≥3y"
  elif $d >= 730 then "≥2y"
  elif $d >= 365 then "≥1y"
  else "<1y" end;
def tierclass: { "≥5y": "t5", "≥3y": "t3", "≥2y": "t2", "≥1y": "t1", "<1y": "t0" }[.];
def summary($asof):
  .data
  | map(select(.OpenDate != null))
  | group_by(.ProductID)
  | map(
      (sort_by([.OpenDate, .ExpireDate])) as $s
      | ($s[0]) as $e
      | ($e.OpenDate | strptime("%Y-%m-%d") | mktime) as $o
      | ($asof | strptime("%Y-%m-%d") | mktime) as $t
      | { product: $e.ProductID, exchange: $e.ExchangeID, count: length,
          contract: $e.InstrumentID, open: $e.OpenDate,
          days: ((($t - $o) / 86400) | floor) }
      | . + { tier: tier(.days) }
    )
  | sort_by(-.days);
JQ

# 品种级汇总 CSV
{
  echo 'product,exchange,listed_contracts,earliest_contract,open_date,days_listed,coverage_tier'
  jq -r --arg asof "$AS_OF" "$JQ_DEFS"'
    summary($asof) | .[] | [.product, .exchange, .count, .contract, .open, .days, .tier] | @csv' "$SNAPSHOT"
} > "$OUT/presbys_products.csv"

# 全量在市合约清单 CSV
{
  echo 'exchange,product,instrument,name,open_date,expire_date,volume_multiple'
  jq -r '.data | sort_by([.ExchangeID, .ProductID, .OpenDate]) | .[]
         | [.ExchangeID, .ProductID, .InstrumentID, .InstrumentName, .OpenDate, .ExpireDate, .VolumeMultiple] | @csv' "$SNAPSHOT"
} > "$OUT/presbys_contracts.csv"

# HTML 表格行
ROWS="$(mktemp)"
jq -r --arg asof "$AS_OF" "$JQ_DEFS"'
  summary($asof) | to_entries[] | . as $r |
  "<tr><td class=\"rank\">\($r.key + 1)</td>" +
  "<td class=\"prod\">\($r.value.product)</td>" +
  "<td>\($r.value.exchange)</td>" +
  "<td class=\"num\">\($r.value.count)</td>" +
  "<td class=\"mono\">\($r.value.contract)</td>" +
  "<td class=\"mono\">\($r.value.open)</td>" +
  "<td class=\"num\">\($r.value.days)</td>" +
  "<td><span class=\"tier \($r.value.tier | tierclass)\">\($r.value.tier)</span></td></tr>"' "$SNAPSHOT" > "$ROWS"

# HTML 概览卡片
CARDS="$(mktemp)"
jq -r --arg asof "$AS_OF" "$JQ_DEFS"'
  summary($asof) as $s |
  def cnt($t): [$s[] | select(.tier == $t)] | length;
  [ { label: "品种总数", value: ($s | length | tostring), sub: "六家交易所 · 在市期货" },
    { label: "最年长者", value: "\($s[0].product) · \($s[0].days) 天", sub: "\($s[0].contract) 上市于 \($s[0].open)" },
    { label: "覆盖 ≥ 2 年", value: (cnt("≥5y") + cnt("≥3y") + cnt("≥2y") | tostring), sub: "个品种" },
    { label: "覆盖 ≥ 1 年", value: (cnt("≥5y") + cnt("≥3y") + cnt("≥2y") + cnt("≥1y") | tostring), sub: "个品种" },
    { label: "不足 1 年", value: (cnt("<1y") | tostring), sub: "个品种" } ]
  | .[]
  | "<div class=\"card\"><div class=\"card-value\">\(.value)</div><div class=\"card-label\">\(.label)</div><div class=\"card-sub\">\(.sub)</div></div>"' "$SNAPSHOT" > "$CARDS"

# 装配 HTML
GEN="$(date '+%F %T %z')"
awk -v asof="$AS_OF" -v gen="$GEN" -v rows="$ROWS" -v cards="$CARDS" '
  /<!--ROWS-->/  { while ((getline l < rows)  > 0) print l; next }
  /<!--CARDS-->/ { while ((getline l < cards) > 0) print l; next }
  { gsub(/@AS_OF@/, asof); gsub(/@GENERATED@/, gen); print }
' "$DIR/template.html" > "$OUT/index.html"
rm -f "$ROWS" "$CARDS"

echo "完成: $OUT/index.html, $OUT/presbys_products.csv, $OUT/presbys_contracts.csv"

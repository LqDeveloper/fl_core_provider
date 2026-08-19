#!/usr/bin/env bash
# =============================================================
#  fl_core_provider — pub.dev 发布脚本
# =============================================================
# 用法:
#   bash scripts/publish.sh          # 发布到 pub.dev（需确认）
#   bash scripts/publish.sh --dry    # 仅验证，不实际发布
#   bash scripts/publish.sh --force  # 跳过确认直接发布
# =============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  fl_core_provider  — 发布准备${NC}"
echo -e "${CYAN}============================================${NC}"

# ---- 检查未提交的修改 ----
if [ -n "$(git status --porcelain)" ]; then
  echo -e "\n${YELLOW}⚠  有未提交的修改:${NC}"
  git status --short
  echo -e "\n${YELLOW}请先提交或暂存所有修改后再发布。${NC}"
  exit 1
fi

echo -e "${GREEN}✔  工作区干净${NC}"

# ---- 检查 git tag ----
VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //')
echo -e "${GREEN}✔  版本号: ${VERSION}${NC}"

# ---- 检查是否存在对应 tag ----
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo -e "${GREEN}✔  Git tag v${VERSION} 已存在${NC}"
else
  echo -e "${YELLOW}⚠  Git tag v${VERSION} 不存在${NC}"
  echo -e "   建议发布前创建 tag:"
  echo -e "     git tag v${VERSION} && git push origin v${VERSION}"
fi

# ---- 检查 pubspec.yaml 中的仓库地址 ----
REPO=$(grep '^repository: ' pubspec.yaml | sed 's/repository: //')
if [ "$REPO" = "https://github.com/user/fl_core_provider" ]; then
  echo -e "\n${YELLOW}⚠  pubspec.yaml 中的 repository 地址仍为占位值${NC}"
  echo -e "   请先在 pubspec.yaml 中更新为真实仓库地址。"
  exit 1
fi

# ---- 静态分析 ----
echo -e "\n${CYAN}▶  dart analyze ...${NC}"
dart analyze lib/
echo -e "${GREEN}✔  静态分析通过${NC}"

# ---- pub publish dry-run ----
echo -e "\n${CYAN}▶  dart pub publish --dry-run ...${NC}"
dart pub publish --dry-run 2>&1
echo -e "${GREEN}✔  预检通过${NC}"

# ---- 确认发布 ----
MODE="${1:-prompt}"

if [ "$MODE" = "--dry" ]; then
  echo -e "\n${GREEN}✔  预检模式已完成，未实际发布。${NC}"
  exit 0
fi

if [ "$MODE" != "--force" ]; then
  echo -e "\n${YELLOW}════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  即将发布 fl_core_provider v${VERSION} 到 pub.dev${NC}"
  echo -e "${YELLOW}════════════════════════════════════════════${NC}"
  echo -n -e "${CYAN}确认发布? (yes/no): ${NC}"
  read -r CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}已取消${NC}"
    exit 1
  fi
fi

# ---- 发布 ----
echo -e "\n${CYAN}▶  dart pub publish ...${NC}"
dart pub publish
echo -e "\n${GREEN}✔  发布完成!${NC}"
echo -e "${GREEN}   https://pub.dev/packages/fl_core_provider${NC}"

#!/bin/bash
# fl_core_provider 页面/控制器 生成脚本
# Usage: ./generate.sh -n PageName [-t stateless|stateful] [-c simple|events] [-e event1,event2] [-d lib/pages] [-r routeName]
#
# 参数说明:
#   -n  页面名称 (必填, 如 LoginPage → Login)
#   -t  页面类型: stateless (默认) | stateful
#   -c  控制器类型: simple (默认, 无事件) | events (带事件枚举)
#   -e  事件列表, 逗号分隔 (仅 -c events 时需要)
#   -d  输出目录 (默认: lib/pages)
#   -r  路由名称 (可选)
#   -i  pageIndex (仅 -t stateful 时需要)
#   -k  wantKeepAlive (仅 -t stateful 时, 默认 true)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

# 解析参数
NAME=""
PAGE_TYPE="stateless"
CTRL_TYPE="simple"
EVENTS=""
OUT_DIR="lib/pages"
ROUTE=""
PAGE_INDEX=""
KEEP_ALIVE="true"

while getopts "n:t:c:e:d:r:i:k:" opt; do
  case $opt in
    n) NAME="$OPTARG" ;;
    t) PAGE_TYPE="$OPTARG" ;;
    c) CTRL_TYPE="$OPTARG" ;;
    e) EVENTS="$OPTARG" ;;
    d) OUT_DIR="$OPTARG" ;;
    r) ROUTE="$OPTARG" ;;
    i) PAGE_INDEX="$OPTARG" ;;
    k) KEEP_ALIVE="$OPTARG" ;;
    *) echo "Usage: $0 -n Name [-t stateless|stateful] [-c simple|events] [-e event1,event2] [-d dir] [-r route] [-i index] [-k bool]"
       exit 1 ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "错误: 必须指定页面名称 (-n)"
  exit 1
fi

SNAKE_NAME=$(echo "$NAME" | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]')
OUT_DIR="${OUT_DIR%/}"
mkdir -p "$OUT_DIR"

echo "=========================================="
echo "  fl_core_provider 代码生成器"
echo "=========================================="
echo "  页面名称:    $NAME"
echo "  页面类型:    $PAGE_TYPE"
echo "  控制器类型:  $CTRL_TYPE"
echo "  输出目录:    $OUT_DIR"
echo "=========================================="

# ---------- 生成 Controller ----------
if [ "$CTRL_TYPE" = "events" ]; then
  if [ -z "$EVENTS" ]; then
    echo "错误: 使用 events 控制器时必须指定事件列表 (-e)"
    exit 1
  fi
  # 格式化事件列表为枚举值格式
  EVENT_LIST=$(echo "$EVENTS" | sed 's/,/, /g')
  TEMPLATE="$TEMPLATE_DIR/controller_with_events.txt"
  CTRL_FILE="${OUT_DIR}/${SNAKE_NAME}_controller.dart"

  sed -e "s/{{Name}}/$NAME/g" \
      -e "s/{{eventList}}/$EVENT_LIST/g" \
      "$TEMPLATE" > "$CTRL_FILE"
  echo "  控制器:     $CTRL_FILE"
else
  TEMPLATE="$TEMPLATE_DIR/controller_simple.txt"
  CTRL_FILE="${OUT_DIR}/${SNAKE_NAME}_controller.dart"

  sed -e "s/{{Name}}/$NAME/g" \
      "$TEMPLATE" > "$CTRL_FILE"
  echo "  控制器:     $CTRL_FILE"
fi

# ---------- 生成 Page ----------
PAGE_TITLE=$(echo "$NAME" | sed 's/\([A-Z]\)/ \1/g' | sed 's/^ //')

if [ "$PAGE_TYPE" = "stateful" ]; then
  TEMPLATE="$TEMPLATE_DIR/page_stateful.txt"
  PAGE_FILE="${OUT_DIR}/${SNAKE_NAME}_page.dart"

  if [ -n "$PAGE_INDEX" ]; then
    PAGE_INDEX_LINE="  @override\n  int get pageIndex => $PAGE_INDEX;"
  else
    PAGE_INDEX_LINE="  // @override\n  // int get pageIndex => -1;"
  fi

  # 处理 keepAlive
  if [ "$KEEP_ALIVE" = "true" ]; then
    KEEP_ALIVE_LINE="  @override\n  bool get wantKeepAlive => true;"
  else
    KEEP_ALIVE_LINE="  // @override\n  // bool get wantKeepAlive => false;"
  fi

  IMPORT_CONTROLLER="import '${SNAKE_NAME}_controller.dart';"

  cat "$TEMPLATE" | sed -e "s|{{Name}}|$NAME|g" \
      -e "s|{{Title}}|$PAGE_TITLE|g" \
      -e "s|{{importController}}|$IMPORT_CONTROLLER|g" \
      -e "s|{{pageIndex}}|$PAGE_INDEX_LINE|g" \
      -e "s|{{keepAlive}}|$KEEP_ALIVE_LINE|g" \
      > "$PAGE_FILE"
  echo "  页面:       $PAGE_FILE"
else
  TEMPLATE="$TEMPLATE_DIR/page_stateless.txt"
  PAGE_FILE="${OUT_DIR}/${SNAKE_NAME}_page.dart"

  IMPORT_CONTROLLER="import '${SNAKE_NAME}_controller.dart';"

  sed -e "s/{{Name}}/$NAME/g" \
      -e "s/{{Title}}/$PAGE_TITLE/g" \
      -e "s/{{importController}}/$IMPORT_CONTROLLER/g" \
      "$TEMPLATE" > "$PAGE_FILE"
  echo "  页面:       $PAGE_FILE"
fi

# ---------- 路由提示 ----------
if [ -n "$ROUTE" ]; then
  echo "  路由:       /$ROUTE → ${NAME}Page"
  echo ""
  echo "路由配置添加到 MaterialApp.routes:"
  echo "  '/$ROUTE': (_) => const ${NAME}Page(),"
fi

echo ""
echo "✅ 生成完成!"

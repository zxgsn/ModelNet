#!/bin/bash

# Dify Workflow API 演示脚本 - ModelNet (Streaming 模式)

API_BASE="http://10.154.22.10"
API_KEY="app-epp3P11TtwN1MrAtHmXr4kkC"
USER_ID="modelnet-demo-$(date +%s)"
WORKFLOW_ENDPOINT="$API_BASE/v1/workflows/run"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       🔧 Dify Workflow Streaming 演示 - ModelNet 🔧        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}API:${NC} $WORKFLOW_ENDPOINT"
echo -e "${CYAN}User:${NC} $USER_ID"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}发送请求，实时接收流式事件（可能需要较长时间）...${NC}"
echo ""

start_time=$(date +%s)

# 关键: 用 < <(curl) 进程替换，避免子shell缓冲问题
while IFS= read -r line; do

    [[ $line != data:* ]] && continue
    json="${line#data: }"
    [[ -z "$json" || "$json" == " " ]] && continue

    event=$(echo "$json" | jq -r '.event // empty' 2>/dev/null)

    case "$event" in
      "workflow_started")
        run_id=$(echo "$json" | jq -r '.workflow_run_id' 2>/dev/null)
        echo -e "${GREEN}🚀 Workflow 开始${NC}  ID: ${run_id:0:20}..."
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        ;;
      "node_started")
        title=$(echo "$json" | jq -r '.data.title' 2>/dev/null)
        type=$(echo "$json" | jq -r '.data.node_type' 2>/dev/null)
        idx=$(echo "$json" | jq -r '.data.index' 2>/dev/null)
        echo -e "${MAGENTA}  [$idx] ▶ $title${NC} ($type)"
        ;;
      "node_finished")
        title=$(echo "$json" | jq -r '.data.title' 2>/dev/null)
        status=$(echo "$json" | jq -r '.data.status' 2>/dev/null)
        elapsed=$(echo "$json" | jq -r '.data.elapsed_time' 2>/dev/null)
        tokens=$(echo "$json" | jq -r '.data.execution_metadata.total_tokens // 0' 2>/dev/null)
        if [ "$status" = "succeeded" ]; then
          echo -e "    ${GREEN}✓ 完成${NC} (${elapsed}s, ${tokens} tokens)"
        else
          echo -e "    ${RED}✗ $status${NC}"
        fi
        ;;
      "iteration_started")
        title=$(echo "$json" | jq -r '.data.title' 2>/dev/null)
        echo -e "  ${YELLOW}🔁 $title 开始${NC}"
        ;;
      "iteration_next")
        idx=$(echo "$json" | jq -r '.data.index' 2>/dev/null)
        echo -e "    ${CYAN}→ 迭代 #$idx${NC}"
        ;;
      "iteration_finished")
        title=$(echo "$json" | jq -r '.data.title' 2>/dev/null)
        echo -e "  ${GREEN}🔁 $title 完成${NC}"
        ;;
      "text_chunk")
        text=$(echo "$json" | jq -r '.data.text' 2>/dev/null)
        printf "%s" "$text"
        ;;
      "workflow_finished")
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        status=$(echo "$json" | jq -r '.data.status' 2>/dev/null)
        elapsed=$(echo "$json" | jq -r '.data.elapsed_time' 2>/dev/null)
        tokens=$(echo "$json" | jq -r '.data.total_tokens' 2>/dev/null)
        steps=$(echo "$json" | jq -r '.data.total_steps' 2>/dev/null)
        end_time=$(date +%s)
        wall_time=$(( end_time - start_time ))
        echo -e "${GREEN}🏁 Workflow 完成${NC}"
        echo -e "  状态: $status"
        echo -e "  耗时: ${elapsed}s (实际等待: ${wall_time}s)"
        echo -e "  Tokens: $tokens"
        echo -e "  步数: $steps"
        echo ""
        echo -e "${WHITE}📤 输出:${NC}"
        echo "$json" | jq '.data.outputs' 2>/dev/null
        ;;
      "error")
        msg=$(echo "$json" | jq -r '.message' 2>/dev/null)
        echo -e "\n${RED}❌ 错误: $msg${NC}"
        ;;
      "ping")
        ;;
    esac
done < <(curl -sN --max-time 600 -X POST "$WORKFLOW_ENDPOINT" \
  --header "Authorization: Bearer $API_KEY" \
  --header "Content-Type: application/json" \
  --data-raw '{
    "inputs": {},
    "response_mode": "streaming",
    "user": "'"$USER_ID"'"
  }')

echo ""
echo -e "${GREEN}✅ 演示结束${NC}"

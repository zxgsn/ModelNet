#!/bin/bash

# Dify Chat API 测试脚本
# 基于文档: http://10.154.22.10:13000/app/d1af8fff-2755-4f2d-80ad-b005450a9dd7/develop

# 配置信息
API_BASE="http://10.154.22.10:5001"
API_KEY="app-sDiNmUsIoGr23xo6eDV2Lzrj"  # 请替换为实际的API Key
USER_ID="user-$(date +%s)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示分隔线
separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 显示标题
show_header() {
    separator
    echo -e "${GREEN}                    Dify Chat API 测试脚本${NC}"
    separator
    echo -e "${YELLOW}API 地址:${NC} $API_BASE"
    echo -e "${YELLOW}用户 ID:${NC} $USER_ID"
    separator
}

# 错误处理
handle_error() {
    local response=$1
    local status=$2

    if [ "$status" -ne 200 ]; then
        echo -e "${RED}错误:${NC} HTTP 状态码 $status"
        echo -e "${RED}响应:${NC} $response"
        return 1
    fi
    return 0
}

# 发送 blocking 模式的对话消息
send_blocking_message() {
    local query="$1"
    local conversation_id="${2:-}"

    echo -e "\n${BLUE}[Blocking 模式]${NC} 发送消息: ${YELLOW}$query${NC}"
    separator

    local response=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/v1/chat-messages" \
        --header "Authorization: Bearer $API_KEY" \
        --header "Content-Type: application/json" \
        --data-raw '{
            "inputs": {},
            "query": "'"$query"'",
            "response_mode": "blocking",
            "conversation_id": "'"$conversation_id"'",
            "user": "'"$USER_ID"'",
            "auto_generate_name": true
        }')

    local status=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if handle_error "$body" "$status"; then
        echo -e "${GREEN}✓ 请求成功${NC}"
        echo -e "\n${CYAN}响应内容:${NC}"
        echo "$body" | jq -r '.answer // "无回答内容"' 2>/dev/null || echo "$body"
        echo -e "\n${CYAN}会话 ID:${NC} $(echo "$body" | jq -r '.conversation_id // "无"')"
        echo -e "${CYAN}消息 ID:${NC} $(echo "$body" | jq -r '.message_id // "无"')"

        # 返回 conversation_id 用于后续对话
        echo "$body" | jq -r '.conversation_id'
    fi
}

# 发送 streaming 模式的对话消息
send_streaming_message() {
    local query="$1"
    local conversation_id="${2:-}"

    echo -e "\n${BLUE}[Streaming 模式]${NC} 发送消息: ${YELLOW}$query${NC}"
    separator
    echo -e "${CYAN}AI 回复:${NC}"

    local full_answer=""
    local conv_id=""

    # 使用 curl 获取流式响应
    curl -sN -X POST "$API_BASE/v1/chat-messages" \
        --header "Authorization: Bearer $API_KEY" \
        --header "Content-Type: application/json" \
        --data-raw '{
            "inputs": {},
            "query": "'"$query"'",
            "response_mode": "streaming",
            "conversation_id": "'"$conversation_id"'",
            "user": "'"$USER_ID"'",
            "auto_generate_name": true
        }' | while IFS= read -r line; do

        # 解析 SSE 事件
        if [[ $line == data:* ]]; then
            local json="${line#data: }"

            # 提取事件类型
            local event=$(echo "$json" | jq -r '.event // empty' 2>/dev/null)

            case "$event" in
                "message")
                    local answer=$(echo "$json" | jq -r '.answer // empty' 2>/dev/null)
                    if [ -n "$answer" ]; then
                        printf "%s" "$answer"
                    fi
                    ;;
                "message_end")
                    echo ""
                    separator
                    local metadata=$(echo "$json" | jq -r '.metadata // empty' 2>/dev/null)
                    local tokens=$(echo "$json" | jq -r '.metadata.usage.total_tokens // "未知"' 2>/dev/null)
                    local msg_id=$(echo "$json" | jq -r '.message_id // "未知"' 2>/dev/null)
                    conv_id=$(echo "$json" | jq -r '.conversation_id // "未知"' 2>/dev/null)

                    echo -e "${GREEN}✓ 消息完成${NC}"
                    echo -e "${CYAN}会话 ID:${NC} $conv_id"
                    echo -e "${CYAN}消息 ID:${NC} $msg_id"
                    echo -e "${CYAN}Token 用量:${NC} $tokens"
                    ;;
                "workflow_started")
                    echo -e "\n${YELLOW}[工作流开始执行]${NC}"
                    ;;
                "node_started")
                    local node_title=$(echo "$json" | jq -r '.data.title // "未知节点"' 2>/dev/null)
                    echo -e "${CYAN}  ▶ 节点开始:${NC} $node_title"
                    ;;
                "node_finished")
                    local node_title=$(echo "$json" | jq -r '.data.title // "未知节点"' 2>/dev/null)
                    local node_status=$(echo "$json" | jq -r '.data.status // "未知"' 2>/dev/null)
                    if [ "$node_status" = "succeeded" ]; then
                        echo -e "${GREEN}  ✓ 节点完成:${NC} $node_title"
                    else
                        echo -e "${RED}  ✗ 节点失败:${NC} $node_title"
                    fi
                    ;;
                "workflow_finished")
                    local wf_status=$(echo "$json" | jq -r '.data.status // "未知"' 2>/dev/null)
                    local elapsed=$(echo "$json" | jq -r '.data.elapsed_time // "未知"' 2>/dev/null)
                    echo -e "${YELLOW}[工作流完成]${NC} 状态: $wf_status, 耗时: ${elapsed}s"
                    separator
                    ;;
                "error")
                    local error_msg=$(echo "$json" | jq -r '.message // "未知错误"' 2>/dev/null)
                    echo -e "\n${RED}错误:${NC} $error_msg"
                    ;;
                "ping")
                    # 忽略 ping 事件
                    ;;
            esac
        fi
    done
}

# 多轮对话演示
demo_multi_turn() {
    echo -e "\n${BLUE}[多轮对话演示]${NC}"
    separator

    # 第一轮
    local conv_id=$(send_blocking_message "你好，请介绍一下你自己" "")
    sleep 2

    # 第二轮（使用返回的 conversation_id）
    if [ -n "$conv_id" ] && [ "$conv_id" != "null" ]; then
        send_blocking_message "你能帮我做什么？" "$conv_id"
    else
        echo -e "${YELLOW}警告: 无法获取会话ID，跳过后续对话${NC}"
    fi
}

# 交互式对话模式
interactive_mode() {
    echo -e "\n${BLUE}[交互式对话模式]${NC}"
    separator
    echo -e "${YELLOW}输入消息与AI对话，输入 'quit' 或 'exit' 退出${NC}"
    echo -e "${YELLOW}输入 'stream' 切换到流式模式，'block' 切换到阻塞模式${NC}"
    separator

    local conv_id=""
    local mode="streaming"

    while true; do
        echo -ne "\n${GREEN}你:${NC} "
        read -r user_input

        # 检查退出命令
        if [[ "$user_input" == "quit" ]] || [[ "$user_input" == "exit" ]]; then
            echo -e "${YELLOW}退出对话${NC}"
            break
        fi

        # 检查模式切换
        if [[ "$user_input" == "stream" ]]; then
            mode="streaming"
            echo -e "${YELLOW}已切换到流式模式${NC}"
            continue
        fi
        if [[ "$user_input" == "block" ]]; then
            mode="blocking"
            echo -e "${YELLOW}已切换到阻塞模式${NC}"
            continue
        fi

        # 跳过空输入
        if [[ -z "$user_input" ]]; then
            continue
        fi

        # 发送消息
        if [[ "$mode" == "streaming" ]]; then
            send_streaming_message "$user_input" "$conv_id"
        else
            local new_conv_id=$(send_blocking_message "$user_input" "$conv_id")
            if [ -n "$new_conv_id" ] && [ "$new_conv_id" != "null" ]; then
                conv_id="$new_conv_id"
            fi
        fi
    done
}

# 显示菜单
show_menu() {
    echo -e "\n${CYAN}选择测试模式:${NC}"
    echo -e "  ${GREEN}1)${NC} Blocking 模式单次测试"
    echo -e "  ${GREEN}2)${NC} Streaming 模式单次测试"
    echo -e "  ${GREEN}3)${NC} 多轮对话演示"
    echo -e "  ${GREEN}4)${NC} 交互式对话模式"
    echo -e "  ${GREEN}5)${NC} 自定义查询"
    echo -e "  ${GREEN}0)${NC} 退出"
    separator
    echo -ne "${GREEN}请选择 [0-5]:${NC} "
}

# 主程序
main() {
    show_header

    # 检查依赖
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}错误: 需要安装 jq 工具${NC}"
        echo -e "Ubuntu/Debian: sudo apt-get install jq"
        echo -e "CentOS/RHEL: sudo yum install jq"
        exit 1
    fi

    while true; do
        show_menu
        read -r choice

        case $choice in
            1)
                send_blocking_message "请介绍一下Dify平台的主要功能"
                ;;
            2)
                send_streaming_message "请介绍一下Dify平台的主要功能"
                ;;
            3)
                demo_multi_turn
                ;;
            4)
                interactive_mode
                ;;
            5)
                echo -ne "${GREEN}请输入查询内容:${NC} "
                read -r custom_query
                if [[ -n "$custom_query" ]]; then
                    echo -e "\n选择模式: ${GREEN}1)${NC} Blocking  ${GREEN}2)${NC} Streaming"
                    read -r mode_choice
                    if [[ "$mode_choice" == "1" ]]; then
                        send_blocking_message "$custom_query"
                    else
                        send_streaming_message "$custom_query"
                    fi
                fi
                ;;
            0|q|quit|exit)
                echo -e "${YELLOW}退出程序${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重试${NC}"
                ;;
        esac

        echo ""
    done
}

# 运行主程序
main

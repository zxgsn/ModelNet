"""
推理测试脚本：使用 Llama-3.1-8B-Instruct-Q8_0 模型进行推理测试
API端点: http://219.222.20.79:30834/v1
"""

import requests
import json
import time
from typing import Optional


# API配置
API_BASE_URL = "http://219.222.20.79:30834/v1"
COMPLETIONS_URL = f"{API_BASE_URL}/completions"
CHAT_URL = f"{API_BASE_URL}/chat/completions"


def test_completions(
    prompt: str,
    max_tokens: int = 512,
    temperature: float = 0.7,
    top_p: float = 0.9,
    stop: Optional[list] = None,
) -> dict:
    """
    测试 completions API

    Args:
        prompt: 输入的提示文本
        max_tokens: 最大生成token数
        temperature: 温度参数
        top_p: top-p采样参数
        stop: 停止词列表

    Returns:
        API响应的字典
    """
    headers = {
        "Content-Type": "application/json",
    }

    payload = {
        "model": "Llama-3.1-8B-Instruct-Q8_0.gguf",
        "prompt": prompt,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "top_p": top_p,
        "stream": False,
    }

    if stop:
        payload["stop"] = stop

    print(f"\n{'='*60}")
    print(f"发送请求到: {COMPLETIONS_URL}")
    print(f"Prompt: {prompt[:100]}{'...' if len(prompt) > 100 else ''}")
    print(f"{'='*60}")

    start_time = time.time()

    try:
        response = requests.post(
            COMPLETIONS_URL,
            headers=headers,
            json=payload,
            timeout=120
        )
        elapsed = time.time() - start_time

        print(f"状态码: {response.status_code}")
        print(f"响应时间: {elapsed:.2f}s")

        if response.status_code == 200:
            result = response.json()
            print(f"\n生成结果:")
            print(f"-"*40)
            for choice in result.get("choices", []):
                print(choice.get("text", ""))
            print(f"-"*40)

            # 打印usage信息
            usage = result.get("usage", {})
            print(f"\nToken使用情况:")
            print(f"  Prompt tokens: {usage.get('prompt_tokens', 'N/A')}")
            print(f"  Completion tokens: {usage.get('completion_tokens', 'N/A')}")
            print(f"  Total tokens: {usage.get('total_tokens', 'N/A')}")

            return result
        else:
            print(f"错误响应: {response.text}")
            return {"error": response.text, "status_code": response.status_code}

    except requests.exceptions.Timeout:
        print("请求超时")
        return {"error": "timeout"}
    except requests.exceptions.ConnectionError as e:
        print(f"连接错误: {e}")
        return {"error": str(e)}
    except Exception as e:
        print(f"未知错误: {e}")
        return {"error": str(e)}


def test_chat_completions(
    messages: list,
    max_tokens: int = 512,
    temperature: float = 0.7,
    top_p: float = 0.9,
) -> dict:
    """
    测试 chat completions API

    Args:
        messages: 消息列表，格式为 [{"role": "user", "content": "..."}]
        max_tokens: 最大生成token数
        temperature: 温度参数
        top_p: top-p采样参数

    Returns:
        API响应的字典
    """
    headers = {
        "Content-Type": "application/json",
    }

    payload = {
        "model": "Llama-3.1-8B-Instruct-Q8_0.gguf",
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "top_p": top_p,
        "stream": False,
    }

    print(f"\n{'='*60}")
    print(f"发送请求到: {CHAT_URL}")
    print(f"Messages: {json.dumps(messages, ensure_ascii=False, indent=2)[:200]}...")
    print(f"{'='*60}")

    start_time = time.time()

    try:
        response = requests.post(
            CHAT_URL,
            headers=headers,
            json=payload,
            timeout=120
        )
        elapsed = time.time() - start_time

        print(f"状态码: {response.status_code}")
        print(f"响应时间: {elapsed:.2f}s")

        if response.status_code == 200:
            result = response.json()
            print(f"\n生成结果:")
            print(f"-"*40)
            for choice in result.get("choices", []):
                message = choice.get("message", {})
                print(f"Role: {message.get('role', 'N/A')}")
                print(f"Content: {message.get('content', '')}")
            print(f"-"*40)

            # 打印usage信息
            usage = result.get("usage", {})
            print(f"\nToken使用情况:")
            print(f"  Prompt tokens: {usage.get('prompt_tokens', 'N/A')}")
            print(f"  Completion tokens: {usage.get('completion_tokens', 'N/A')}")
            print(f"  Total tokens: {usage.get('total_tokens', 'N/A')}")

            return result
        else:
            print(f"错误响应: {response.text}")
            return {"error": response.text, "status_code": response.status_code}

    except requests.exceptions.Timeout:
        print("请求超时")
        return {"error": "timeout"}
    except requests.exceptions.ConnectionError as e:
        print(f"连接错误: {e}")
        return {"error": str(e)}
    except Exception as e:
        print(f"未知错误: {e}")
        return {"error": str(e)}


def stream_completions(
    prompt: str,
    max_tokens: int = 512,
    temperature: float = 0.7,
):
    """
    测试流式 completions API

    Args:
        prompt: 输入的提示文本
        max_tokens: 最大生成token数
        temperature: 温度参数
    """
    headers = {
        "Content-Type": "application/json",
    }

    payload = {
        "model": "Llama-3.1-8B-Instruct-Q8_0.gguf",
        "prompt": prompt,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": True,
    }

    print(f"\n{'='*60}")
    print(f"流式请求到: {COMPLETIONS_URL}")
    print(f"Prompt: {prompt[:100]}{'...' if len(prompt) > 100 else ''}")
    print(f"{'='*60}")
    print(f"\n流式生成结果:")
    print(f"-"*40)

    start_time = time.time()

    try:
        response = requests.post(
            COMPLETIONS_URL,
            headers=headers,
            json=payload,
            stream=True,
            timeout=120
        )

        if response.status_code == 200:
            full_text = ""
            for line in response.iter_lines():
                if line:
                    line = line.decode("utf-8")
                    if line.startswith("data: "):
                        data = line[6:]
                        if data.strip() == "[DONE]":
                            break
                        try:
                            chunk = json.loads(data)
                            for choice in chunk.get("choices", []):
                                text = choice.get("text", "")
                                print(text, end="", flush=True)
                                full_text += text
                        except json.JSONDecodeError:
                            pass

            elapsed = time.time() - start_time
            print(f"\n" + "-"*40)
            print(f"总响应时间: {elapsed:.2f}s")
            print(f"完整文本长度: {len(full_text)} 字符")
        else:
            print(f"错误: {response.status_code}")
            print(response.text)

    except Exception as e:
        print(f"错误: {e}")


def run_tests():
    """运行一系列推理测试"""

    print("\n" + "="*60)
    print("Llama-3.1-8B-Instruct-Q8_0 推理测试")
    print("="*60)

    # 测试1: 简单的文本补全
    print("\n\n[测试1] 简单文本补全")
    test_completions(
        prompt="人工智能的未来发展趋势是",
        max_tokens=200,
        temperature=0.7,
    )

    # 测试2: 代码生成
    print("\n\n[测试2] 代码生成")
    test_completions(
        prompt="用Python实现一个快速排序算法：\n\ndef quicksort(arr):",
        max_tokens=300,
        temperature=0.3,
    )

    # 测试3: 中文问答
    print("\n\n[测试3] Chat Completions - 中文问答")
    test_chat_completions(
        messages=[
            {"role": "system", "content": "你是一个有帮助的AI助手。"},
            {"role": "user", "content": "请解释什么是大语言模型(LLM)，并给出3个主要应用场景。"}
        ],
        max_tokens=500,
        temperature=0.7,
    )

    # 测试4: 数学推理
    print("\n\n[测试4] 数学推理")
    test_completions(
        prompt="解方程: 2x + 5 = 13\n\n解题步骤:\n1.",
        max_tokens=200,
        temperature=0.1,
    )

    # 测试5: 流式输出
    print("\n\n[测试5] 流式输出")
    stream_completions(
        prompt="写一首关于春天的五言绝句：",
        max_tokens=100,
        temperature=0.8,
    )

    print("\n\n" + "="*60)
    print("所有测试完成!")
    print("="*60)


if __name__ == "__main__":
    # 运行完整测试
    run_tests()

    # 或者单独测试某个功能
    # test_completions(prompt="你好，请介绍一下自己。", max_tokens=200)
    # test_chat_completions(messages=[{"role": "user", "content": "你好"}])

#!/bin/bash
# 脚本功能：通过命令行参数指定当前节点编号 → 远程清理 → 同步 → 强制异步执行远程脚本 → 本地执行
# 核心优化：采用更彻底的异步方式，确保SSH会话立即断开，兼容不同节点环境
# 使用方法：./clean_and_sync.sh [节点编号] （1-7之间的整数）


# 1. 参数校验（保持不变）
current_node="$1"
if [ -z "$current_node" ]; then
    echo -e "\033[31m错误：请指定节点编号（1-7）\033[0m"
    exit 1
fi
if ! [[ "$current_node" =~ ^[1-7]$ ]]; then
    echo -e "\033[31m错误：节点编号必须是1-7之间的整数\033[0m"
    exit 1
fi


# 2. 远程清理（保持不变）
echo -e "\n第一步：清理远程节点旧内容（当前节点 $current_node 已跳过）..."
for node_num in {1..7}; do
    if [ "$node_num" -eq "$current_node" ]; then
        echo -e "\033[33m[跳过] 当前节点 skv-node$node_num\033[0m"
        continue
    fi

    echo -e "\n[处理] 清理 skv-node$node_num ..."
    ssh "skv-node$node_num" "rm -rf /home/kvgroup/louzy/LaCoLSM/*"
    if [ $? -ne 0 ]; then
        echo -e "\033[31m[失败] skv-node$node_num 清理失败\033[0m"
        exit 1
    fi
    echo -e "\033[32m[成功] skv-node$node_num 清理完成\033[0m"
done


# 3. 同步内容（保持不变）
echo -e "\n第二步：执行 sync.sh 同步内容..."
if [ ! -f "./sync.sh" ]; then
    echo -e "\033[31m错误：未找到 sync.sh\033[0m"
    exit 1
fi
./sync.sh "$current_node"
if [ $? -ne 0 ]; then
    echo -e "\033[31m[失败] sync.sh 执行失败\033[0m"
    exit 1
fi
echo -e "\033[32m[成功] 内容同步完成\033[0m"


# 4. 远程脚本处理（核心优化：强制异步，确保SSH立即断开）
echo -e "\n第三步：异步处理远程节点脚本（当前节点 $current_node 已跳过）..."
for node_num in {1..7}; do
    if [ "$node_num" -eq "$current_node" ]; then
        echo -e "\033[33m[跳过] 当前节点 skv-node$node_num\033[0m"
        continue
    fi

    # 设置权限（保持同步执行，确保成功）
    echo -e "\n[处理] 为 skv-node$node_num 设置脚本权限..."
    ssh "skv-node$node_num" "chmod +x /home/kvgroup/louzy/LaCoLSM/script/*.sh"
    if [ $? -ne 0 ]; then
        echo -e "\033[31m[失败] skv-node$node_num 权限设置失败\033[0m"
        exit 1
    fi
    echo -e "\033[32m[成功] skv-node$node_num 权限设置完成\033[0m"

    # 核心优化：使用以下方式强制异步（解决node2卡住问题）
    # 1. setsid 确保进程脱离终端
    # 2. 明确指定bash执行，避免节点默认shell差异
    # 3. 重定向所有输出，避免SSH等待输出缓冲
    # 4. SSH命令后加&，本地立即继续执行
    echo -e "[处理] 异步启动 skv-node$node_num 的 make_db.sh..."
    ssh "skv-node$node_num" "setsid bash -c 'cd /home/kvgroup/louzy/LaCoLSM/script && ./make_db.sh > /dev/null 2>&1 &'" &
    # 短暂延迟，避免SSH连接过于密集导致的节点拒绝
    sleep 0.5
done

# 等待所有远程异步命令的SSH连接发起完成
wait
echo -e "\033[32m[完成] 所有远程节点 make_db.sh 已异步启动\033[0m"


# 5. 本地执行（保持不变）
echo -e "\n第四步：本地执行 make_db.sh..."
if [ ! -f "./make_db.sh" ]; then
    echo -e "\033[31m错误：未找到本地 make_db.sh\033[0m"
    exit 1
fi
chmod +x ./make_db.sh
./make_db.sh
if [ $? -eq 0 ]; then
    echo -e "\033[32m[成功] 本地 make_db.sh 执行完成\033[0m"
else
    echo -e "\033[31m[失败] 本地 make_db.sh 执行失败\033[0m"
    exit 1
fi


echo -e "\n------------------------"
echo -e "\033[32m所有流程已启动（远程节点完全异步执行）\033[0m"

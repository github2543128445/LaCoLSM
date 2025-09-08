#!/bin/bash
# 脚本功能：通过命令行参数指定当前节点编号 → 远程清理其他 skv-node1~7 的指定目录 → 调用 sync.sh 并传递相同参数
# 使用方法：./clean_and_sync.sh [节点编号] （节点编号必须是 1-7 之间的整数）
# 注意事项：
# 1. 需确保当前用户对 skv-node1~7 有 SSH 免密登录权限
# 2. 确认 /home/kvgroup/louzy/LaCoLSM/ 目录无需保留内容（rm -rf 不可逆）
# 3. sync.sh 需支持通过位置参数接收节点编号（即通过 $1 获取参数）


# 1. 从命令行参数获取当前节点编号并校验
current_node="$1"

# 检查是否提供了参数
if [ -z "$current_node" ]; then
    echo -e "\033[31m错误：请在运行时指定节点编号！\033[0m"
    echo "使用方法：$0 [节点编号] （节点编号必须是 1-7 之间的整数）"
    exit 1
fi

# 校验输入有效性：必须是 1-7 的整数
if ! [[ "$current_node" =~ ^[1-7]$ ]]; then
    echo -e "\033[31m错误：无效的节点编号！\033[0m"
    echo "节点编号必须是 1-7 之间的整数"
    exit 1
fi


# 2. 遍历 1-7 节点，跳过当前节点，执行远程清理
echo -e "\n开始处理节点 1-7（当前节点 $current_node 已跳过）..."
for node_num in {1..7}; do
    # 跳过当前节点，不执行清理
    if [ "$node_num" -eq "$current_node" ]; then
        echo -e "\033[33m[跳过] 当前节点 skv-node$node_num，无需清理\033[0m"
        continue
    fi

    # 远程执行删除命令：清理 skv-nodeX 的目标目录
    echo -e "\n[处理] 连接 skv-node$node_num 清理 /home/kvgroup/louzy/LaCoLSM/* ..."
    ssh "skv-node$node_num" "rm -rf /home/kvgroup/louzy/LaCoLSM/*"

    # 检查远程命令执行结果
    if [ $? -eq 0 ]; then
        echo -e "\033[32m[成功] skv-node$node_num 目录清理完成\033[0m"
    else
        echo -e "\033[31m[失败] skv-node$node_num 清理失败（可能 SSH 连接异常/目录不存在）\033[0m"
    fi
done


# 3. 调用 sync.sh 并传递当前节点编号参数
echo -e "\n------------------------"
echo "开始执行 sync.sh 脚本（传递参数：节点编号 $current_node）..."

# 先检查 sync.sh 是否存在
if [ ! -f "./sync.sh" ]; then
    echo -e "\033[31m错误：未找到 sync.sh！请确认脚本在当前目录，或修改脚本中的路径\033[0m"
    exit 1
fi

# 执行 sync.sh 并传递节点编号参数
./sync.sh "$current_node"

# 检查 sync.sh 执行结果
if [ $? -eq 0 ]; then
    echo -e "\033[32msync.sh 执行成功（参数：$current_node）\033[0m"
else
    echo -e "\033[31msync.sh 执行失败（参数：$current_node），请检查 sync.sh 内部逻辑\033[0m"
fi


echo -e "\n------------------------"
echo "所有流程执行完毕（建议核对清理结果和 sync.sh 日志）"

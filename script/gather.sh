#!/bin/bash

# 检查参数数量
if [ $# -ne 2 ]; then
    echo "使用方法: $0 <当前节点编号> <filename>"
    echo "示例: $0 3 test  # 表示当前节点是3，获取所有test*.csv文件"
    exit 1
fi

current_node="$1"
filename="$2"
nodes=(1 2 3 4 5 6 7)  # 所有节点列表

# 创建目标目录（如果不存在）
mkdir -p ../data/data-node{1..7}

# 遍历所有节点
for node in "${nodes[@]}"; do
    if [ "$node" -eq "$current_node" ]; then
        # 当前节点执行cp操作
        echo "处理当前节点 (data-node$node)..."
        cp "../${filename}*.csv" ../data/data-node"$node"/ 2>/dev/null || \
        echo "提示: 当前节点无 ${filename}*.csv 文件"
    else
        # 其他节点执行scp操作
        echo "从 skv-node$node 获取CSV..."
        scp "skv-node$node:~/louzy/TestDLSM/${filename}*.csv" ../data/data-node"$node"/ 2>/dev/null || \
        echo "提示: skv-node$node 无 ${filename}*.csv 文件"
    fi
done

echo "所有操作已完成！"
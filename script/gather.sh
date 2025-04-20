#!/bin/bash

# 复制../build目录下的所有.sh文件到当前目录
echo "复制.sh文件到当前目录..."
cp ../build/*.sh . 2>/dev/null || echo "提示: 未找到.sh文件"

# 创建data-node2目录并复制.csv文件
echo "处理data-node2目录..."
mkdir -p ./data-node2
cp ../build/*.csv ./data-node2/ 2>/dev/null || echo "提示: 未找到.csv文件"

# 从skv-node3复制CSV文件
echo "从skv-node3获取CSV..."
mkdir -p ./data-node3
scp "skv-node3:~/louzy/LaCoLSM/build/"*.csv ./data-node3/ 2>/dev/null || echo "提示: skv-node3无CSV文件"

# 从skv-node4复制CSV文件
echo "从skv-node4获取CSV..."
mkdir -p ./data-node4
scp "skv-node4:~/louzy/LaCoLSM/build/"*.csv ./data-node4/ 2>/dev/null || echo "提示: skv-node4无CSV文件"

echo "所有操作已完成！"
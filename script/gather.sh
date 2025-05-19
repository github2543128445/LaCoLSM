#!/bin/bash

# 检查是否提供了文件名参数
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <filename>"
    echo "示例: $0 test 将获取所有test*.csv文件"
    exit 1
fi

filename="$1"

# 从skv-node1复制CSV文件
echo "从skv-node1获取CSV..."
scp "skv-node1:~/louzy/LaCoLSM/${filename}*.csv" ../data/data-node1/ 2>/dev/null || echo "提示: skv-node1无${filename}*.csv文件"

# 从skv-node2复制CSV文件
echo "从skv-node2获取CSV..."
scp "skv-node2:~/louzy/LaCoLSM/${filename}*.csv" ../data/data-node2/ 2>/dev/null || echo "提示: skv-node2无${filename}*.csv文件"

# 创建data-node3目录并复制.csv文件
echo "处理data-node3目录..."
cp "../${filename}*.csv" ../data/data-node3/ 2>/dev/null || echo "提示: 未找到${filename}*.csv文件"

# 从skv-node4复制CSV文件
echo "从skv-node4获取CSV..."
scp "skv-node4:~/louzy/LaCoLSM/${filename}*.csv" ../data/data-node4/ 2>/dev/null || echo "提示: skv-node4无${filename}*.csv文件"

# 从skv-node5复制CSV文件
echo "从skv-node5获取CSV..."
scp "skv-node5:~/louzy/LaCoLSM/${filename}*.csv" ../data/data-node5/ 2>/dev/null || echo "提示: skv-node5无${filename}*.csv文件"

# 从skv-node6复制CSV文件
echo "从skv-node6获取CSV..."
scp "skv-node6:~/louzy/LaCoLSM/${filename}*.csv" ../data/data-node6/ 2>/dev/null || echo "提示: skv-node6无${filename}*.csv文件"

# 从skv-node7复制CSV文件
echo "从skv-node7获取CSV..."
scp "skv-node7:~/louzy/LaCoLSM/${filename}*.csv" ../data/data-node7/ 2>/dev/null || echo "提示: skv-node7无${filename}*.csv文件"

echo "所有操作已完成！"

#./gather.sh MNuni
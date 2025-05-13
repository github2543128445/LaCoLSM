#!/bin/bash

# 复制../build目录下的所有.sh文件到当前目录
# echo "复制.sh文件到当前目录..."
# cp ../build/*.sh . 2>/dev/null || echo "提示: 未找到.sh文件"
# 从skv-node1复制CSV文件
echo "从skv-node1获取CSV..."
scp "skv-node1:~/louzy/LaCoLSM/"*.csv ../data/data-node1/ 2>/dev/null || echo "提示: skv-node1无CSV文件"

# 创建data-node2目录并复制.csv文件
echo "处理data-node2目录..."
cp ../*.csv ../data/data-node2/ 2>/dev/null || echo "提示: 未找到.csv文件"

# 从skv-node3复制CSV文件
echo "从skv-node3获取CSV..."
scp "skv-node3:~/louzy/LaCoLSM/"*.csv ../data/data-node3/ 2>/dev/null || echo "提示: skv-node3无CSV文件"

# 从skv-node4复制CSV文件
echo "从skv-node4获取CSV..."
scp "skv-node4:~/louzy/LaCoLSM/"*.csv ../data/data-node4/ 2>/dev/null || echo "提示: skv-node4无CSV文件"

# 从skv-node5复制CSV文件
echo "从skv-node5获取CSV..."
scp "skv-node5:~/louzy/LaCoLSM/"*.csv ../data/data-node5/ 2>/dev/null || echo "提示: skv-node5无CSV文件"

# 从skv-node6复制CSV文件
echo "从skv-node6获取CSV..."
scp "skv-node6:~/louzy/LaCoLSM/"*.csv ../data/data-node6/ 2>/dev/null || echo "提示: skv-node6无CSV文件"

# 从skv-node4复制CSV文件
echo "从skv-node7获取CSV..."
scp "skv-node7:~/louzy/LaCoLSM/"*.csv ../data/data-node7/ 2>/dev/null || echo "提示: skv-node7无CSV文件"

echo "所有操作已完成！"
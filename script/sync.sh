#!/bin/bash

# 优化后的同步编译脚本
# 用法：./sync_build.sh [本节点编号]
# 示例：./sync_build.sh 2  # 表示当前节点是skv-node2

if [ $# -ne 1 ]; then
  echo "错误：请提供本节点编号（1-7）"
  echo "示例：$0 2"
  exit 1
fi

current_node=$1
nodes=(1 2 3 4 5 6 7)  # 所有节点编号

# 同步到其他节点（排除自身）
for node in "${nodes[@]}"; do
  if [ "$node" -ne "$current_node" ]; then
    echo "正在同步到 skv-node$node..."
    rsync -av \
      --exclude=build/ \
      --exclude=data-f/ \
      --exclude=data/ \
      --exclude=script/run-MN.sh \
      --exclude=*.csv \
      --exclude=pic/ \
      ~/louzy/LaCoLSM/ \
      skv-node$node:~/louzy/LaCoLSM
  fi
done

# 编译项目
cd ../build
make Server db_bench TimberSaw
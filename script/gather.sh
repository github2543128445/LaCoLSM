#!/bin/bash

# 检查参数数量（至少需要节点ID）
if [ $# -lt 1 ]; then
    echo "使用方法: $(basename "$0") <本节点数字ID> [文件名前缀]"
    echo "示例1: $0 3 test    # 仅收集 test*.csv 文件"
    echo "示例2: $0 3         # 收集所有 *.csv 文件"
    exit 1
fi

node_id="$1"       # 本节点数字ID（如 3）
filename="${2:-}"  # 文件名前缀（可选）
base_path="~/louzy/LaCoLSM"  # 远程文件基础路径

# 动态生成文件匹配模式
if [ -z "$filename" ]; then
    file_pattern="*.csv"    # 无文件名参数时匹配所有CSV
else
    file_pattern="${filename}*.csv"  # 有参数时匹配指定前缀
fi

# 验证节点ID是否为1-7的整数
if ! [[ "$node_id" =~ ^[1-7]$ ]]; then
    echo "错误: 节点ID必须是1-7的整数"
    exit 1
fi

# 主循环：遍历所有节点（1-7）
for node_num in {1..7}; do
    node="skv-node${node_num}"
    local_dir="../data/data-node${node_num}"
    files_exist=0  # 标记是否存在文件

    # ---- 新增逻辑：检查文件是否存在 ----
    if [ "$node_num" -eq "$node_id" ]; then  # 本地节点检查
        # 使用ls检查本地文件（不输出结果）
        if ls "../${file_pattern}" 1>/dev/null 2>&1; then
            files_exist=1
        fi
    else  # 远程节点检查
        # 通过SSH检查远程文件
        if ssh "$node" "ls ${base_path}/${file_pattern} 1>/dev/null 2>&1"; then
            files_exist=1
        fi
    fi

    # ---- 根据文件存在性决定操作 ----
    if [ "$files_exist" -eq 1 ]; then
        mkdir -p "$local_dir"  # 存在文件时才创建目录
        echo "处理节点 ${node}（存在文件）..."
        
        if [ "$node_num" -eq "$node_id" ]; then
            cp "../${file_pattern}" "$local_dir/" 2>/dev/null
        else
            scp "${node}:${base_path}/${file_pattern}" "$local_dir/" 2>/dev/null
        fi
    else
        echo "跳过节点 ${node}（无 ${file_pattern} 文件）"
    fi
done

echo "所有操作已完成！"
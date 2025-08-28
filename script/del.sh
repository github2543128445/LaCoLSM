#!/bin/bash
# 功能：删除 LaCoLSM 一级目录中与本地 data 目录同名的 CSV 文件（含远程节点）
# 用法：./cleanup_target_csv.sh <本节点ID>

# ---- 参数检查 ----
if [ $# -ne 1 ]; then
    echo "错误：必须提供本节点ID（1-7）" >&2
    echo "示例：$0 3" >&2
    exit 1
fi

self_id="$1"
base_dir="/home/kvgroup/louzy/LaCoLSM/data"  # 本地 data 目录（基准目录）
target_local_dir=$(dirname "$base_dir")       # 本地目标目录（LaCoLSM 一级目录）
remote_base="/home/kvgroup/louzy/LaCoLSM"    # 远程节点目标目录

# ---- 节点ID合法性检查 ----
if ! [[ "$self_id" =~ ^[1-7]$ ]]; then
    echo "错误：节点ID必须是1-7的整数" >&2
    exit 1
fi

# ---- 收集本地 data 目录下的所有 CSV 文件名（去重）----
local_files=()
while IFS= read -r -d '' file; do
    local_files+=("$(basename "$file")")
done < <(find "$base_dir" -type f -name "*.csv" -print0)

# 去重本地文件列表
local_files=($(printf "%s\n" "${local_files[@]}" | sort -u))

if [ ${#local_files[@]} -eq 0 ]; then
    echo "本地 data 目录无 CSV 文件，无需清理"
    exit 0
fi

# ---- 遍历所有节点（本地+远程）----
node_dirs=$(find "$base_dir" -maxdepth 1 -type d -name "data-node[1-7]")
for node_dir in $node_dirs; do
    [ ! -d "$node_dir" ] && continue  # 跳过不存在的目录
    node_num=$(basename "$node_dir" | grep -oE '[0-9]+$')
    echo "处理节点 node$node_num："

    # ---- 本地节点处理：删除 LaCoLSM 一级目录中与 data 目录同名的 CSV ----
    if [ "$node_num" -eq "$self_id" ]; then
        for file in "${local_files[@]}"; do
            target_file="${target_local_dir}/${file}"
            if [ -f "$target_file" ]; then
                echo "  删除本地一级目录文件: $target_file"
                rm -f "$target_file"
            fi
        done
    
    # ---- 远程节点处理：逻辑不变（删除远程 LaCoLSM 目录中同名 CSV）----
    else
        for file in "${local_files[@]}"; do
            remote_file="${remote_base}/${file}"
            if ssh -n -o BatchMode=yes -o ConnectTimeout=5 "skv-node${node_num}" "[ -f '$remote_file' ]"; then
                ssh -n -o BatchMode=yes "skv-node${node_num}" "rm -f '$remote_file'"
                echo "  删除远程文件: skv-node${node_num}:$remote_file"
            fi
        done
    fi
done

echo -e "\n清理完成！已删除所有节点中与本地 data 目录同名的 CSV 文件"

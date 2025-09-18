#!/bin/bash
# 功能：删除所有其他节点 LaCoLSM 目录下的所有 CSV 文件
# 用法：./delete_remote_csvs.sh <本节点ID>

# ---- 参数检查 ----
if [ $# -ne 1 ]; then
    echo "错误：必须提供本节点ID（1-7）" >&2
    echo "示例：$0 3" >&2
    exit 1
fi

SELF_ID="$1"
REMOTE_BASE_DIR="/home/kvgroup/louzy/LaCoLSM" # 远程节点目标目录
ALL_NODES=(1 2 3 4 5 6 7) # 所有节点的ID数组

# ---- 节点ID合法性检查 ----
if ! [[ "$SELF_ID" =~ ^[1-7]$ ]]; then
    echo "错误：节点ID必须是1-7的整数" >&2
    exit 1
fi

# ---- 遍历所有节点ID ----
for NODE_ID in "${ALL_NODES[@]}"; do
    # 跳过本节点
    if [ "$NODE_ID" -eq "$SELF_ID" ]; then
        continue
    fi

    NODE_HOST="skv-node${NODE_ID}"
    echo "正在处理节点: $NODE_HOST"

    # 检查远程目录是否存在
    if ! ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$NODE_HOST" "[ -d '$REMOTE_BASE_DIR' ]" &>/dev/null; then
        echo "  跳过: 远程目录 $REMOTE_BASE_DIR 不存在或无法访问。"
        continue
    fi

    # 执行远程删除：删除该节点LaCoLSM目录下所有csv文件
    if ssh -n -o BatchMode=yes "$NODE_HOST" "rm -f $REMOTE_BASE_DIR/*.csv"; then
        echo "  成功: 已删除 $NODE_HOST 上 $REMOTE_BASE_DIR/*.csv"
    fi
    ssh -n -o BatchMode=yes "$NODE_HOST" "rm -f $REMOTE_BASE_DIR/sequence.txt"
done

echo -e "\n操作完成。已尝试清理所有其他节点上的CSV文件。"
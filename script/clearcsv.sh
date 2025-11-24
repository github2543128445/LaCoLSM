#!/bin/bash
# 功能：删除所有节点（包括本地和其他节点）LaCoLSM 目录下的所有 CSV 文件
# 用法：./delete_remote_csvs.sh <本节点ID>

# ---- 参数检查 ----
if [ $# -ne 1 ]; then
    echo "错误：必须提供本节点ID（1-7）" >&2
    echo "示例：$0 3" >&2
    exit 1
fi

SELF_ID="$1"
LOCAL_BASE_DIR="/home/kvgroup/louzy/LaCoLSM"  # 本地节点目标目录
REMOTE_BASE_DIR="/home/kvgroup/louzy/LaCoLSM" # 远程节点目标目录
ALL_NODES=(1 2 3 4 5 6 7) # 所有节点的ID数组

# ---- 节点ID合法性检查 ----
if ! [[ "$SELF_ID" =~ ^[1-7]$ ]]; then
    echo "错误：节点ID必须是1-7的整数" >&2
    exit 1
fi

# ==========================================================
# 新增功能：处理本地节点
# ==========================================================
echo "正在处理本地节点 (ID: $SELF_ID)..."
# 检查本地目录是否存在
if [ -d "$LOCAL_BASE_DIR" ]; then
    # 删除本地目录下的所有CSV文件
    # 使用 if-then 结构来打印成功信息，即使 rm -f 在没有文件时不报错
    if rm -f "$LOCAL_BASE_DIR"/*.csv; then
        echo "  成功: 已删除本地节点上 $LOCAL_BASE_DIR/*.csv"
    fi
    # 同时删除 sequence.txt
    rm -f "$LOCAL_BASE_DIR/sequence.txt"
    echo "  已尝试删除本地节点上的 $LOCAL_BASE_DIR/sequence.txt"
else
    echo "  跳过: 本地目录 $LOCAL_BASE_DIR 不存在。"
fi
echo "" # 输出一个空行，用于分隔本地和远程操作的输出

# ==========================================================
# 原有功能：处理所有其他远程节点
# ==========================================================
echo "开始处理远程节点..."
for NODE_ID in "${ALL_NODES[@]}"; do
    # 跳过本节点，因为已经处理过了
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
    # 同时删除远程节点上的 sequence.txt
    ssh -n -o BatchMode=yes "$NODE_HOST" "rm -f $REMOTE_BASE_DIR/sequence.txt"
    echo "  已尝试删除 $NODE_HOST 上的 $REMOTE_BASE_DIR/sequence.txt"
done

base_dir="/home/kvgroup/louzy/LaCoLSM/data"  # 本地 data 目录（基准目录）
# ---- 删除本节点的data文件夹 ----
local_data_dir="$base_dir"
if [ -d "$local_data_dir" ]; then
    echo -e "\n删除本节点data文件夹: $local_data_dir"
    rm -rf "$local_data_dir"
else
    echo -e "\n本节点data文件夹不存在: $local_data_dir"
fi


echo -e "\n操作完成。已清理本地节点和所有其他远程节点上的CSV文件。"
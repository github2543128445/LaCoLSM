#!/bin/bash
cd ../build
make Server db_bench TimberSaw

# 清理临时文件
if [ -f "temp.txt" ]; then
    rm -f temp.txt
fi

# 新增：处理唯一递增序号
SEQ_FILE="../sequence.txt"
# 如果序号文件不存在则初始化
if [ ! -f "$SEQ_FILE" ]; then
    echo 1 > "$SEQ_FILE"
fi
# 读取当前序号
NO=$(cat "$SEQ_FILE")
# 计算下一个序号
NEXT_NO=$((NO + 1))
# 更新序号文件
echo $NEXT_NO > "$SEQ_FILE"

# 定义信号处理函数
db_bench_pid=""
handle_sigint() {
    if [ -n "$db_bench_pid" ]; then
        echo "正在终止 Server 进程..."
        kill -TERM "$db_bench_pid"
        wait "$db_bench_pid" 2>/dev/null
    fi
}

# 设置信号处理
trap handle_sigint SIGINT

# 运行基准测试
taskset -c 40-41 ./Server 19843 80 0 > temp.txt 2>&1 &
db_bench_pid=$!

# 等待 db_bench 完成
wait $db_bench_pid
db_bench_pid=""

# 提取Compactor值（0/1/2），默认0
compactor=$(grep -oP '///Compactor is \K\d+' temp.txt | head -1)
compactor=${compactor:-0}

# 数据提取函数
extract_value() {
    pattern=$1
    default=$2
    value=$(grep -oP "$pattern" temp.txt | head -1)
    echo "${value:-$default}"
}

detail_compaction_csv="../RemoteCompactionDetail.csv"

# 首次运行时写入表头（列名严格匹配需求）
if [ ! -f "$detail_compaction_csv" ]; then
    echo "NO,compactor,case,stage,avg,P1,P5,P10,P50,P90,P95,P99" > "$detail_compaction_csv"
fi

# 提取temp.txt中"C0 Compaction Cost"相关行，匹配格式：For Case X Stage Y: avg = A,P1 = B,...P99 = Z
while IFS= read -r line; do
    # 正则表达式分组提取关键信息：case、stage、avg、P1-P99
    if [[ "$line" =~ Detail\ Work\ Case\ ([0-9]+)\ Stage\ ([0-9]+):\ avg\ =\ ([0-9]+),P1\ =\ ([0-9]+),P5\ =\ ([0-9]+),P10\ =\ ([0-9]+),P50\ =\ ([0-9]+),P90\ =\ ([0-9]+),P95\ =\ ([0-9]+),P99\ =\ ([0-9]+) ]]; then
        # 解析正则匹配结果（BASH_REMATCH[1]对应case，[2]对应stage，依次类推）
        case_num="${BASH_REMATCH[1]}"
        stage_num="${BASH_REMATCH[2]}"
        avg_val="${BASH_REMATCH[3]}"
        p1_val="${BASH_REMATCH[4]}"
        p5_val="${BASH_REMATCH[5]}"
        p10_val="${BASH_REMATCH[6]}"
        p50_val="${BASH_REMATCH[7]}"
        p90_val="${BASH_REMATCH[8]}"
        p95_val="${BASH_REMATCH[9]}"
        p99_val="${BASH_REMATCH[10]}"

        # 构建CSV行（复用已有变量NO、compactor、thread、ops_per_thread）
        stage_csv_row="$NO,$compactor,$case_num,$stage_num,$avg_val,$p1_val,$p5_val,$p10_val,$p50_val,$p90_val,$p95_val,$p99_val"
        
        # 追加到目标CSV文件
        echo "$stage_csv_row" >> "$detail_compaction_csv"      
    fi
done < <(grep '^Detail Work Case [0-9]\+ Stage [0-9]\+:' temp.txt)
echo "" >> "$detail_compaction_csv"

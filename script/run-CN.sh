#!/bin/bash
cd ../build
make Server db_bench TimberSaw

if [ $# -ne 3 ]; then
    echo "Usage: $0 <node_id> <thread> <ops_per_thread>"
    exit 1
fi
node_id=$1
thread=$2
ops_per_thread=$3

# 清理临时文件
if [ -f "temp.txt" ]; then
    rm -f temp.txt
fi

# 定义信号处理函数
db_bench_pid=""
handle_sigint() {
    if [ -n "$db_bench_pid" ]; then
        echo "正在终止 db_bench 进程..."
        kill -TERM "$db_bench_pid"
        wait "$db_bench_pid" 2>/dev/null
    fi
}

# 设置信号处理
trap handle_sigint SIGINT

# 运行基准测试
./db_bench --benchmarks=fillrandom \
           --threads=$thread \
           --value_size=400 \
           --num=$ops_per_thread \
           --bloom_bits=10 \
           --compute_node_id=$node_id > temp.txt 2>&1 &
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

# 提取各项指标
throughput=$(extract_value 'fillrandom\s+:\s+\d+\.\d+ micros/op;\s+\K\d+(?=\s+ops/sec)' 0)
bandwith=$(extract_value 'fillrandom\s+:\s+.*;\s+\K\d+\.\d+(?= MB/s)' 0)

lat_avg=$(extract_value 'insert latancy:avg = \K\d+' 0)
lat_p50=$(extract_value 'insert latancy:.*P50 = \K\d+' 0)
lat_p90=$(extract_value 'insert latancy:.*P90 = \K\d+' 0)
lat_p99=$(extract_value 'insert latancy:.*P99 = \K\d+' 0)
lat_p999=$(extract_value 'insert latancy:.*P999 = \K\d+' 0)

comp_avg=$(extract_value 'compaction latancy:avg = \K\d+' 0)
comp_p50=$(extract_value 'compaction latancy:.*P50 = \K\d+' 0)
comp_p90=$(extract_value 'compaction latancy:.*P90 = \K\d+' 0)
comp_p99=$(extract_value 'compaction latancy:.*P99 = \K\d+' 0)
comp_p999=$(extract_value 'compaction latancy:.*P999 = \K\d+' 0)

# 构建CSV行（Compactor作为第一列）
csv_row="$compactor,$node_id,$thread,$ops_per_thread,$throughput,$bandwith,$lat_avg,$lat_p50,$lat_p90,$lat_p99,$comp_avg,$comp_p50,$comp_p90"

# 写入CSV文件（更新标题行）
csv_file="../temp.csv"
if [ ! -f "$csv_file" ]; then
    echo "compactor,node_id,thread,ops per thread,throughput,bandwith,insert avg,insert lat P50,insert P90,insert P99,comp avg,comp p50,comp p90" > "$csv_file"
fi
echo "$csv_row" >> "$csv_file"

# 修复正则表达式匹配所有节点数据
while IFS= read -r line; do
    if [[ "$line" =~ \/\/\/([^0-9]+)\ Node\ ([0-9]+)\ uti:\ av\ =\ ([0-9.]+),P50\ =\ ([0-9.]+),P90\ =\ ([0-9.]+),P99\ =\ ([0-9.]+),P999\ =\ ([0-9.]+)\/\/\/ ]]; then
        node_id="${BASH_REMATCH[2]}"
        av="${BASH_REMATCH[3]}"
        p50="${BASH_REMATCH[4]}"
        p90="${BASH_REMATCH[5]}"
        p99="${BASH_REMATCH[6]}"
        p999="${BASH_REMATCH[7]}"
        
        csv_file="../node${node_id}_uti.csv"
        [ ! -f "$csv_file" ] && echo "compactor,node_id,thread,ops per thread,avg,p50,p90,p99,p999" > "$csv_file"
        echo "$compactor,$node_id,$thread,$ops_per_thread,$av,$p50,$p90,$p99,$p999" >> "$csv_file"
    fi
done < "temp.txt"
# 示例
# ./run-CN.sh 0 16 3000000
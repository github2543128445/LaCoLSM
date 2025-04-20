#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <thread> <ops_per_thread>"
    exit 1
fi
thread=$1
ops_per_thread=$2

# 清理临时文件
if [ -f "temp.txt" ]; then
    rm temp.txt
fi

# 运行基准测试
./db_bench --benchmarks=fillrandom \
           --threads=$thread \
           --value_size=400 \
           --num=$ops_per_thread \
           --bloom_bits=10 \
           --compute_node_id=0 > temp.txt 2>&1

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

cn_avg=$(extract_value 'CN uti: av = \K\d+\.\d+' 0)
cn_p50=$(extract_value 'CN uti:.*P50 = \K\d+\.\d+' 0)
cn_p90=$(extract_value 'CN uti:.*P90 = \K\d+\.\d+' 0)
cn_p99=$(extract_value 'CN uti:.*P99 = \K\d+\.\d+' 0)

mn_avg=$(extract_value 'MN uti: av = \K\d+\.\d+' 0)
mn_p50=$(extract_value 'MN uti:.*P50 = \K\d+\.\d+' 0)
mn_p90=$(extract_value 'MN uti:.*P90 = \K\d+\.\d+' 0)
mn_p99=$(extract_value 'MN uti:.*P99 = \K\d+\.\d+' 0)

lat_p50=$(extract_value 'insert latancy:P50 = \K\d+' 0)
lat_p90=$(extract_value 'insert latancy:.*P90 = \K\d+' 0)
lat_p99=$(extract_value 'insert latancy:.*P99 = \K\d+' 0)
lat_p999=$(extract_value 'insert latancy:.*P999 = \K\d+' 0)

# 构建CSV行
csv_row="$thread,$ops_per_thread,$throughput,$bandwith,$cn_avg,$cn_p50,$cn_p90,$cn_p99,$mn_avg,$mn_p50,$mn_p90,$mn_p99,$lat_p50,$lat_p90,$lat_p99,$lat_p999"

# 写入CSV文件
csv_file="3-1fillrandom-zipf-CNcomp.csv"
if [ ! -f "$csv_file" ]; then
    echo "thread,ops per thread,throughput,bandwith,CN util avg,CN P50,CN P90,CN P99,MN util avg,MN P50,MN P90,MN P99,insert lat P50,insert P90,insert P99,insert P999" > "$csv_file"
fi
echo "$csv_row" >> "$csv_file"

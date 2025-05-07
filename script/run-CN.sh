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

# 运行基准测试
./db_bench --benchmarks=fillrandom \
           --threads=$thread \
           --value_size=400 \
           --num=$ops_per_thread \
           --bloom_bits=10 \
           --compute_node_id=$node_id > temp.txt 2>&1

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

# 提取CN利用率指标（取最后一次匹配）
cn_avg=$(grep -oP 'CN uti: av = \K\d+\.\d+' temp.txt | tail -n 1)
cn_avg=${cn_avg:-0}
cn_p50=$(grep -oP 'CN uti:.*P50 = \K\d+\.\d+' temp.txt | tail -n 1)
cn_p50=${cn_p50:-0}
cn_p90=$(grep -oP 'CN uti:.*P90 = \K\d+\.\d+' temp.txt | tail -n 1)
cn_p90=${cn_p90:-0}
cn_p99=$(grep -oP 'CN uti:.*P99 = \K\d+\.\d+' temp.txt | tail -n 1)
cn_p99=${cn_p99:-0}

# 提取MN利用率指标（取最后一次匹配）
mn_avg=$(grep -oP 'MN uti: av = \K\d+\.\d+' temp.txt | tail -n 1)
mn_avg=${mn_avg:-0}
mn_p50=$(grep -oP 'MN uti:.*P50 = \K\d+\.\d+' temp.txt | tail -n 1)
mn_p50=${mn_p50:-0}
mn_p90=$(grep -oP 'MN uti:.*P90 = \K\d+\.\d+' temp.txt | tail -n 1)
mn_p90=${mn_p90:-0}
mn_p99=$(grep -oP 'MN uti:.*P99 = \K\d+\.\d+' temp.txt | tail -n 1)
mn_p99=${mn_p99:-0}

lat_p50=$(extract_value 'insert latancy:P50 = \K\d+' 0)
lat_p90=$(extract_value 'insert latancy:.*P90 = \K\d+' 0)
lat_p99=$(extract_value 'insert latancy:.*P99 = \K\d+' 0)
lat_p999=$(extract_value 'insert latancy:.*P999 = \K\d+' 0)

# 构建CSV行（Compactor作为第一列）
csv_row="$compactor,$node_id,$thread,$ops_per_thread,$throughput,$bandwith,$cn_avg,$cn_p50,$cn_p90,$cn_p99,$mn_avg,$mn_p50,$mn_p90,$mn_p99,$lat_p50,$lat_p90,$lat_p99,$lat_p999"

# 写入CSV文件（更新标题行）
csv_file="CNcp2-1.csv"
if [ ! -f "$csv_file" ]; then
    echo "compactor,node_id,thread,ops per thread,throughput,bandwith,CN util avg,CN P50,CN P90,CN P99,MN util avg,MN P50,MN P90,MN P99,insert lat P50,insert P90,insert P99,insert P999" > "$csv_file"
fi
echo "$csv_row" >> "$csv_file"

# 示例
# ./run.sh 0 16 10000000
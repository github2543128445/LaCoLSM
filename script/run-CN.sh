#!/bin/bash
cd ../build
make Server db_bench TimberSaw

if [ $# -ne 4 ]; then
    echo "Usage: $0 <node_id> <thread> <ops_per_thread> <duration>"
    exit 1
fi
node_id=$1
thread=$2
ops_per_thread=$3  
duration=$4
  

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
        echo "正在终止 db_bench 进程..."
        kill -TERM "$db_bench_pid"
        wait "$db_bench_pid" 2>/dev/null
    fi
}

# 设置信号处理
trap handle_sigint SIGINT

# 运行基准测试
taskset -c 40-71 ./db_bench --benchmarks=fillrandom \
           --threads=$thread \
           --value_size=400 \
           --num=$ops_per_thread \
           --duration=$duration \
           --bloom_bits=10 \
           --compute_node_id=$node_id > temp.txt 2>&1 &
db_bench_pid=$!

# 新增：将 PID 打印到屏幕
echo "db_bench 程序已启动，PID 为: $db_bench_pid"

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
comp_speed_1=$(extract_value 'compaction speed case1:avg = \K\d+' 0)
comp_speed_2=$(extract_value 'compaction speed case2:avg = \K\d+' 0)
comp_speed_3=$(extract_value 'compaction speed case3:avg = \K\d+' 0)
comp_speed_4=$(extract_value 'compaction speed case4:avg = \K\d+' 0)
dis_cost=$(extract_value 'Distribute cost:avg = \K\d+' 0)
# 构建CSV行（新增NO作为第一列）
csv_row="$NO,$compactor,$node_id,$thread,$ops_per_thread,$throughput,$bandwith,$lat_avg,$lat_p50,$lat_p90,$lat_p99,$dis_cost,$comp_avg,$comp_p50,$comp_p90,$comp_p99,$comp_speed_1,$comp_speed_2,$comp_speed_3,$comp_speed_4"

# 写入主CSV文件
csv_file="../temp.csv"
if [ ! -f "$csv_file" ]; then
    echo "NO,compactor,node_id,thread,ops per thread,throughput,bandwith,insert avg,insert lat P50,insert P90,insert P99,dis cost,comp avg,comp p50,comp p90,comp p99,comp speed1,comp speed2,comp speed3,comp speed4" > "$csv_file"
fi
echo "$csv_row" >> "$csv_file"

# 处理节点利用率数据（添加NO列）
while IFS= read -r line; do
    if [[ "$line" =~ \/\/\/([^0-9]+)\ Node\ ([0-9]+)\ uti:\ av\ =\ ([0-9.]+),P50\ =\ ([0-9.]+),P90\ =\ ([0-9.]+),P99\ =\ ([0-9.]+),P999\ =\ ([0-9.]+)\/\/\/ ]]; then
        node_id="${BASH_REMATCH[2]}"
        av="${BASH_REMATCH[3]}"
        p50="${BASH_REMATCH[4]}"
        p90="${BASH_REMATCH[5]}"
        p99="${BASH_REMATCH[6]}"
        p999="${BASH_REMATCH[7]}"
        
        csv_file="../node${node_id}_uti.csv"
        [ ! -f "$csv_file" ] && echo "NO,compactor,node_id,thread,ops per thread,avg,p50,p90,p99,p999" > "$csv_file"
        echo "$NO,$compactor,$node_id,$thread,$ops_per_thread,$av,$p50,$p90,$p99,$p999" >> "$csv_file"
    fi
done < "temp.txt"

# 处理Compaction Time数据（添加NO列）
compaction_csv="../compaction_time.csv"
if [ ! -f "$compaction_csv" ]; then
    echo "NO,compactor,current_node_id,thread,ops_per_thread,type,time" > "$compaction_csv"
fi

# 提取Local Compaction Time
local_time=$(grep -oP 'Compaction Time: Local = \K\d+' temp.txt | head -1)
if [ -n "$local_time" ]; then
    echo "$NO,$compactor,$node_id,$thread,$ops_per_thread,local,$local_time" >> "$compaction_csv"  
fi
# 提取MN节点的Compaction Time
while IFS= read -r line; do
    if [[ "$line" =~ MN\ Compaction\ Time:\ Node\ ([0-9]+)\ =\ ([0-9]+) ]]; then
        mn_node="${BASH_REMATCH[1]}"
        mn_time="${BASH_REMATCH[2]}"
        echo "$NO,$compactor,$node_id,$thread,$ops_per_thread,node $mn_node,$mn_time" >> "$compaction_csv"
    fi
done < <(grep 'MN Compaction Time: Node' temp.txt)
# 提取CN节点的Compaction Time
while IFS= read -r line; do
    if [[ "$line" =~ CN\ Compaction\ Time:\ Node\ ([0-9]+)\ =\ ([0-9]+) ]]; then
        cn_node="${BASH_REMATCH[1]}"
        cn_time="${BASH_REMATCH[2]}"
        echo "$NO,$compactor,$node_id,$thread,$ops_per_thread,node $cn_node,$cn_time" >> "$compaction_csv"
    fi
done < <(grep 'CN Compaction Time: Node' temp.txt)
echo "" >> "$compaction_csv"
##############################################################################
# 新增：处理C0 Compaction Stage Cost数据，输出到CompactionStageCost.csv
##############################################################################
# 定义目标CSV文件路径
compaction_stage_csv="../CompactionStageCost.csv"

# 首次运行时写入表头（列名严格匹配需求）
if [ ! -f "$compaction_stage_csv" ]; then
    echo "NO,compactor,thread,ops per thread,case,stage,avg,P1,P5,P10,P50,P90,P95,P99" > "$compaction_stage_csv"
fi

# 提取temp.txt中"C0 Compaction Cost"相关行，匹配格式：For Case X Stage Y: avg = A,P1 = B,...P99 = Z
while IFS= read -r line; do
    # 正则表达式分组提取关键信息：case、stage、avg、P1-P99
    if [[ "$line" =~ For\ Case\ ([0-9]+)\ Stage\ ([0-9]+):\ avg\ =\ ([0-9]+),P1\ =\ ([0-9]+),P5\ =\ ([0-9]+),P10\ =\ ([0-9]+),P50\ =\ ([0-9]+),P90\ =\ ([0-9]+),P95\ =\ ([0-9]+),P99\ =\ ([0-9]+) ]]; then
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
        stage_csv_row="$NO,$compactor,$thread,$ops_per_thread,$case_num,$stage_num,$avg_val,$p1_val,$p5_val,$p10_val,$p50_val,$p90_val,$p95_val,$p99_val"
        
        # 追加到目标CSV文件
        echo "$stage_csv_row" >> "$compaction_stage_csv"      
    fi
done < <(grep '^For Case [0-9]\+ Stage [0-9]\+:' temp.txt)
echo "" >> "$compaction_stage_csv"

detail_compaction_csv="../RemoteCompactionDetail.csv"

# 首次运行时写入表头（列名严格匹配需求）
if [ ! -f "$detail_compaction_csv" ]; then
    echo "NO,compactor,thread,ops per thread,case,stage,avg,P1,P5,P10,P50,P90,P95,P99" > "$detail_compaction_csv"
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
        stage_csv_row="$NO,$compactor,$thread,$ops_per_thread,$case_num,$stage_num,$avg_val,$p1_val,$p5_val,$p10_val,$p50_val,$p90_val,$p95_val,$p99_val"
        
        # 追加到目标CSV文件
        echo "$stage_csv_row" >> "$detail_compaction_csv"      
    fi
done < <(grep '^Detail Work Case [0-9]\+ Stage [0-9]\+:' temp.txt)
echo "" >> "$detail_compaction_csv"

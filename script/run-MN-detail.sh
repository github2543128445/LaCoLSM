#!/bin/bash

# 新增：处理线程数参数
THREAD_COUNT=16  # 默认线程数
if [ $# -gt 0 ]; then
    if [[ $1 =~ ^[0-9]+$ ]] && [ $1 -gt 0 ] && [ $1 -le 40 ]; then
        THREAD_COUNT=$1
    else
        echo "错误：线程数必须为1-40之间的整数"
        exit 1
    fi
fi

# 计算CPU核心范围
START_CORE=40
END_CORE=$((START_CORE + THREAD_COUNT - 1))

echo "使用线程数: $THREAD_COUNT, CPU核心范围: $START_CORE-$END_CORE"

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

# 定义信号处理函数和全局变量
db_bench_pid=""
monitor_pid=""
THREAD_MONITOR_FILE="thread_monitor_$$.tmp"  # 使用PID作为临时文件后缀，避免冲突
SCRIPT_EXIT_CODE=0
monitor_running=true  # 监控循环控制标志

# 增强的信号处理函数
handle_termination() {
    echo -e "\n接收到终止信号，正在优雅退出..."
    # 防止在清理过程中再次被中断
    trap '' SIGINT SIGTERM
    
    # 设置监控循环退出标志
    monitor_running=false
    
    # 1. 先终止Server主进程
    if [ -n "$db_bench_pid" ] && kill -0 "$db_bench_pid" 2>/dev/null; then
        echo "正在终止Server进程 (PID: $db_bench_pid)..."
        kill -TERM "$db_bench_pid" 2>/dev/null
        # 等待最多3秒让进程自然退出
        local count=0
        while [ $count -lt 3 ] && kill -0 "$db_bench_pid" 2>/dev/null; do
            sleep 1
            ((count++))
        done
        # 如果进程仍未退出，强制杀死
        if kill -0 "$db_bench_pid" 2>/dev/null; then
            echo "强制终止Server进程..."
            kill -KILL "$db_bench_pid" 2>/dev/null
        fi
        wait "$db_bench_pid" 2>/dev/null
        db_bench_pid=""
    fi
    
    # 2. 等待监控进程结束（给予短暂时间完成最后的文件写入）
    if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
        echo "等待监控进程结束..."
        # 给监控进程发送TERM信号
        kill -TERM "$monitor_pid" 2>/dev/null
        # 等待最多2秒
        local count=0
        while [ $count -lt 2 ] && kill -0 "$monitor_pid" 2>/dev/null; do
            sleep 1
            ((count++))
        done
        # 如果监控进程仍然存活，强制结束
        if kill -0 "$monitor_pid" 2>/dev/null; then
            kill -KILL "$monitor_pid" 2>/dev/null
        fi
        wait "$monitor_pid" 2>/dev/null
        monitor_pid=""
    fi
    
    # 3. 输出最大线程数结果
    output_max_threads
    
    # 4. 清理临时文件
    cleanup_temp_files
    
    exit $SCRIPT_EXIT_CODE
}

# 输出最大线程数函数
output_max_threads() {
    if [ -f "$THREAD_MONITOR_FILE" ]; then
        max_threads=$(cat "$THREAD_MONITOR_FILE")
        echo "=========================================="
        echo "程序运行期间的最大线程数: $max_threads"
        echo "=========================================="
    else
        echo "警告：未能获取线程监控数据，临时文件不存在。"
    fi
}

# 清理临时文件函数
cleanup_temp_files() {
    if [ -f "$THREAD_MONITOR_FILE" ]; then
        rm -f "$THREAD_MONITOR_FILE"
    fi
}

# 设置信号捕获
trap handle_termination SIGINT SIGTERM

# 修改：使用动态CPU核心范围运行基准测试
taskset -c $START_CORE-$END_CORE ./Server 19843 80 0 > temp.txt 2>&1 &
db_bench_pid=$!

# 新增：将PID打印到屏幕
echo "Server程序已启动，PID为: $db_bench_pid"
echo "CPU亲和性设置为: cores $START_CORE-$END_CORE"

# 线程监控函数
monitor_threads() {
    local pid=$1
    local monitor_file=$2
    local max_threads=0
    local current_threads=0
    
    echo "开始监控进程 $pid 的线程数..."
    echo "0" > "$monitor_file"  # 初始化文件
    
    # 监控循环
    while $monitor_running && kill -0 "$pid" 2>/dev/null; do
        # 检查进程状态文件是否存在
        if [ -f "/proc/$pid/status" ]; then
            # 从/proc文件系统获取线程数
            current_threads=$(grep -E '^Threads:' "/proc/$pid/status" | awk '{print $2}')
            
            if [ -n "$current_threads" ] && [ "$current_threads" -gt "$max_threads" ]; then
                max_threads=$current_threads
                # 实时更新最大线程数到文件
                echo "$max_threads" > "$monitor_file"
                echo "当前线程数: $current_threads, 最大线程数: $max_threads"
            fi
        else
            # 如果进程状态文件不存在，说明进程可能已经结束
            break
        fi
        sleep 1  # 每秒检查一次
    done
    
    # 最终写入一次确保数据最新
    echo "$max_threads" > "$monitor_file"
    echo "线程监控结束，最终最大线程数: $max_threads"
}

# 启动线程监控（后台运行）
monitor_threads "$db_bench_pid" "$THREAD_MONITOR_FILE" &
monitor_pid=$!
echo "线程监控已启动，监控进程PID: $monitor_pid"

# 等待Server主进程结束
wait $db_bench_pid 2>/dev/null
db_bench_exit_code=$?
db_bench_pid=""
SCRIPT_EXIT_CODE=$db_bench_exit_code

# 主进程自然退出后，停止监控进程
monitor_running=false
if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
    kill -TERM "$monitor_pid" 2>/dev/null
    wait "$monitor_pid" 2>/dev/null
    monitor_pid=""
fi

# 输出最大线程数
output_max_threads

# 清理临时文件
cleanup_temp_files

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

        # 构建CSV行
        stage_csv_row="$NO,$compactor,$case_num,$stage_num,$avg_val,$p1_val,$p5_val,$p10_val,$p50_val,$p90_val,$p95_val,$p99_val"
        
        # 追加到目标CSV文件
        echo "$stage_csv_row" >> "$detail_compaction_csv"      
    fi
done < <(grep '^Detail Work Case [0-9]\+ Stage [0-9]\+:' temp.txt)
echo "" >> "$detail_compaction_csv"

# 输出最终状态
echo "脚本执行完成，Server退出码: $db_bench_exit_code"
echo "使用的CPU核心: $START_CORE-$END_CORE, 线程数: $THREAD_COUNT"
exit $db_bench_exit_code
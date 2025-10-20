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

taskset -c 40-55 ./Server 19843 80 0
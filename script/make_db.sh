#!/bin/bash

# 检查build文件夹是否存在
if [ ! -d "../build" ]; then
    echo "build文件夹不存在，正在创建并配置..."
    mkdir -p ../build
    cd ../build
    # 执行cmake配置
    cmake -DWITH_GFLAGS=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=1 ../Code
else
    echo "build文件夹已存在，直接进入..."
    cd ../build
fi

# 执行make命令构建目标
echo "开始构建目标..."
make Server db_bench TimberSaw

# 检查构建是否成功
if [ $? -eq 0 ]; then
    echo "构建成功完成"
else
    echo "构建过程中出现错误"
    exit 1
fi
    
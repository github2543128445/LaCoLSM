#!/usr/bin/env python3
import csv
import os
import statistics

def process_csv(input_file, output_file):
    # 读取CSV文件
    with open(input_file, 'r') as f:
        reader = csv.reader(f)
        header = next(reader)  # 获取表头
        rows = list(reader)    # 读取所有数据行
    
    # 性能指标列索引
    performance_indices = [4, 5, 6, 7, 8, 9, 10, 11, 12]  # throughput, bandwith, insert avg, ...
    
    # 按(compactor, thread)分组
    groups = {}
    for row in rows:
        key = (row[0], row[2])  # compactor, thread
        if key not in groups:
            groups[key] = []
        groups[key].append(row)
    
    # 计算每组的平均值
    avg_rows = []
    for key, group_rows in groups.items():
        # 创建新行，初始化为第一行的值
        avg_row = group_rows[0].copy()
        
        # 计算性能指标的平均值
        for idx in performance_indices:
            values = [float(row[idx]) for row in group_rows]
            avg = statistics.mean(values)
            # 仅对性能指标取整数
            avg_row[idx] = str(int(avg))
        
        avg_rows.append(avg_row)
    
    # 按compactor和thread排序
    avg_rows.sort(key=lambda x: (int(x[0]), int(x[2])))
    
    # 写入结果到新文件
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(avg_rows)

def main():
    # 处理每个文件
    input_files = [
        "/home/kvgroup/louzy/LaCoLSM/data-f/data-write-2/data-node6/temp.csv",
        "/home/kvgroup/louzy/LaCoLSM/data-f/data-write-2/data-node5/temp.csv",
        "/home/kvgroup/louzy/LaCoLSM/data-f/data-write-01/data-node6/temp.csv",
        "/home/kvgroup/louzy/LaCoLSM/data-f/data-write-01/data-node5/temp.csv"
    ]
    
    for input_file in input_files:
        # 生成输出文件路径
        dir_path = os.path.dirname(input_file)
        output_file = os.path.join(dir_path, "temp-avg.csv")
        
        # 处理CSV文件
        process_csv(input_file, output_file)
        print(f"已处理: {input_file} -> {output_file}")

if __name__ == "__main__":
    main()
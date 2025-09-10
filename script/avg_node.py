#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import csv
import pandas as pd
import numpy as np

def process_csv_files(base_node):
    # 定义数据目录路径
    data_dir = '/home/kvgroup/louzy/LaCoLSM/data'
    
    # 基准node文件夹路径
    base_node_dir = os.path.join(data_dir, f'data-node{base_node}')
    base_csv_path = os.path.join(base_node_dir, 'temp.csv')
    
    # 检查基准文件是否存在
    if not os.path.exists(base_csv_path):
        print(f"错误：基准文件 {base_csv_path} 不存在")
        return
    
    # 读取基准CSV文件
    base_df = pd.read_csv(base_csv_path)
    
    # 创建分组映射，基于(compactor,node_id,thread)分组
    group_keys = ['compactor', 'node_id', 'thread']
    base_groups = {}
    for idx, row in base_df.iterrows():
        no = row['NO']
        group_key = (row['compactor'], row['node_id'], row['thread'])
        base_groups[no] = group_key
    
    # 获取所有node文件夹
    node_dirs = [d for d in os.listdir(data_dir) if d.startswith('data-node')]
    
    # 处理每个node文件夹
    for node_dir in node_dirs:
        node_path = os.path.join(data_dir, node_dir)
        csv_path = os.path.join(node_path, 'temp.csv')
        output_path = os.path.join(node_path, 'temp-avg.csv')
        
        # 检查CSV文件是否存在
        if not os.path.exists(csv_path):
            print(f"警告：{csv_path} 不存在，跳过处理")
            continue
        
        # 读取当前node的CSV文件
        df = pd.read_csv(csv_path)
        
        # 创建分组
        groups = {}
        for idx, row in df.iterrows():
            no = row['NO']
            if no in base_groups:
                group_key = base_groups[no]
                if group_key not in groups:
                    groups[group_key] = []
                groups[group_key].append(row.to_dict())
        
        # 处理每个分组，计算平均值
        result_rows = []
        for group_key, rows in groups.items():
            # 提取分组信息（仅用于分组，不用于结果）
            base_compactor, base_node_id, base_thread = group_key
            
            # 使用原始文件中的compactor, node_id, thread值
            # 而不是基准文件中的值
            first_row = rows[0]
            result_row = {
                'compactor': first_row['compactor'],
                'node_id': first_row['node_id'],
                'thread': first_row['thread']
            }
            
            # 获取所有列名
            all_columns = df.columns.tolist()
            
            # 对每一列进行平均值计算（除了NO, compactor, node_id, thread）
            for col in all_columns:
                if col not in ['NO', 'compactor', 'node_id', 'thread']:
                    # 提取非零值
                    values = [row[col] for row in rows if row[col] != 0]
                    if values:
                        # 计算平均值并保留两位小数
                        avg_value = round(sum(values) / len(values), 2)
                        result_row[col] = avg_value
                    else:
                        result_row[col] = 0.0
            
            result_rows.append(result_row)
        
        # 创建结果DataFrame
        result_df = pd.DataFrame(result_rows)
        
        # 按照原始列顺序排序
        ordered_columns = [col for col in all_columns if col != 'NO']
        result_df = result_df[ordered_columns]
        
        # 保存结果到CSV文件
        result_df.to_csv(output_path, index=False)
        print(f"已生成 {output_path}")

def main():
    if len(sys.argv) != 2:
        print("用法: python avg_node.py <基准node号>")
        sys.exit(1)
    
    try:
        base_node = int(sys.argv[1])
        process_csv_files(base_node)
    except ValueError:
        print("错误：基准node号必须是整数")
        sys.exit(1)

if __name__ == "__main__":
    main()


#用法：python3 avg_node.py <基准node号>
#作用，以/data/data-node<基准node号>/temp.csv为分组基准，计算其他node的temp.csv的平均值，结果保存到temp-avg.csv
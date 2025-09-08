#!/usr/bin/env python3
import pandas as pd
import sys
import os

def process_csv_files(output_path, input_files):
    """
    处理多个CSV文件，以(compactor,thread,ops per thread)为分组依据，计算其他列的平均值（忽略0值）
    结果保留两位小数
    
    Args:
        output_path: 输出文件路径
        input_files: 输入文件路径列表
    """
    # 存储所有数据框的列表
    all_dfs = []
    
    # 读取所有输入文件
    for file_path in input_files:
        try:
            df = pd.read_csv(file_path)
            # 忽略node_id列
            if 'node_id' in df.columns:
                df = df.drop('node_id', axis=1)
            all_dfs.append(df)
        except Exception as e:
            print(f"Error reading file {file_path}: {e}")
            continue
    
    if not all_dfs:
        print("No valid input files found.")
        return
    
    # 合并所有数据框
    combined_df = pd.concat(all_dfs, ignore_index=True)
    
    # 以(compactor,thread,ops per thread)为分组依据
    group_columns = ['compactor', 'thread', 'ops per thread']
    
    # 检查分组列是否存在
    missing_columns = [col for col in group_columns if col not in combined_df.columns]
    if missing_columns:
        print(f"Error: Missing required columns: {missing_columns}")
        return
    
    # 获取需要计算平均值的列（排除分组列）
    value_columns = [col for col in combined_df.columns if col not in group_columns]
    
    # 分组并计算平均值（忽略0值）
    # 对每个值列单独计算平均值，避免列名冲突
    result_df = combined_df.groupby(group_columns).agg(
        {col: lambda x: x[x != 0].mean() for col in value_columns}
    ).reset_index()
    
    # 对数值列保留两位小数
    numeric_columns = result_df.select_dtypes(include=['float64', 'int64']).columns
    # 排除分组列，只对数值结果列进行处理
    columns_to_round = [col for col in numeric_columns if col not in group_columns]
    result_df[columns_to_round] = result_df[columns_to_round].round(2)
    
    # 创建输出目录（如果不存在）
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # 保存结果到输出文件
    result_df.to_csv(output_path, index=False)
    print(f"Successfully generated {output_path} with values rounded to 2 decimal places")

def main():
    # 检查命令行参数
    if len(sys.argv) < 3:
        print("Usage: python avg_multi.py <output_path> <input_file1> [input_file2] ...")
        sys.exit(1)
    
    output_path = sys.argv[1]
    input_files = sys.argv[2:]
    
    process_csv_files(output_path, input_files)

if __name__ == "__main__":
    main()

#多文件输入，按（compactor,thread,ops per thread）分组，忽略节点，然后得到平均后的结果
#用法 python3 /home/kvgroup/louzy/LaCoLSM/script/avg_multi.py <输出文件路径/输出文件名> <输入文件1> [输入文件2] ...
#快速用法 python3 /home/kvgroup/louzy/LaCoLSM/script/avg_multi.py /home/kvgroup/louzy/LaCoLSM/data/uni-avg.csv /home/kvgroup/louzy/LaCoLSM/data/data-node5/temp-avg.csv /home/kvgroup/louzy/LaCoLSM/data/data-node6/temp-avg.csv /home/kvgroup/louzy/LaCoLSM/data/data-node7/temp-avg.csv
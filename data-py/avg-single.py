import pandas as pd
import os
import sys

def process_csv(file_path):
    # 读取CSV文件
    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        print(f"读取文件失败: {e}")
        return
    
    # 定义分组列和需要计算平均值的列
    group_columns = ['compactor', 'node_id', 'thread', 'ops per thread']
    # 自动识别非分组列作为需要计算平均值的列
    value_columns = [col for col in df.columns if col not in group_columns]
    
    # 按分组列进行分组，并计算每组的平均值
    grouped = df.groupby(group_columns, as_index=False)[value_columns].mean()
    
    # 将平均值转换为整数
    for col in value_columns:
        grouped[col] = grouped[col].round().astype(int)
    
    # 生成输出文件路径
    dir_name, file_name = os.path.split(file_path)
    base_name, ext = os.path.splitext(file_name)
    output_file = os.path.join(dir_name, f"{base_name}-avg{ext}")
    
    # 保存结果到新的CSV文件
    try:
        grouped.to_csv(output_file, index=False)
        print(f"处理完成，结果已保存至: {output_file}")
    except Exception as e:
        print(f"保存文件失败: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("使用方法: python csv_group_averager.py <文件路径>")
        print("文件路径可以是绝对路径或相对路径")
        sys.exit(1)
    
    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"错误: 文件 '{file_path}' 不存在")
        sys.exit(1)
    
    if not os.path.isfile(file_path):
        print(f"错误: '{file_path}' 不是一个文件")
        sys.exit(1)
    
    process_csv(file_path)

#用以处理单个文件的平均
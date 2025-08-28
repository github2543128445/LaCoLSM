import csv
import os
import glob
import argparse

def process_files(prefix):
    # 获取数据目录路径
    data_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 确保输出目录存在
    output_dir = os.path.join(data_dir, 'data-avg')
    os.makedirs(output_dir, exist_ok=True)
    
    # 收集所有匹配的文件
    all_files = []
    for node_dir in glob.glob(os.path.join(data_dir, 'data-node*')):
        # 使用glob匹配所有以prefix开头的csv文件
        pattern = os.path.join(node_dir, f'{prefix}*.csv')
        matching_files = glob.glob(pattern)
        all_files.extend(matching_files)
    
    if not all_files:
        print(f"未找到匹配的文件: {prefix}*.csv")
        return
        
    # 读取所有数据
    header = None
    all_data = []
    for file_path in all_files:
        with open(file_path, 'r') as f:
            reader = csv.reader(f)
            if header is None:
                header = next(reader)
            else:
                next(reader)  # 跳过标题行
            all_data.extend(list(reader))
    
    # 按 thread 和 ops per thread 分组
    groups = {}
    for row in all_data:
        key = (row[2], row[3])  # thread 和 ops per thread
        if key not in groups:
            groups[key] = []
        groups[key].append(row)
    
    # 处理每个分组并计算平均值
    result_rows = []
    for rows in groups.values():
        if not rows:
            continue
            
        # 保持 compactor
        new_row = [rows[0][0]]
        # 添加 thread 和 ops per thread
        new_row.extend(rows[0][2:4])
        
        # 计算其他列的平均值（跳过 node_id 列）
        for col in range(4, len(header)):
            values = [float(row[col]) for row in rows]
            avg = sum(values) / len(values)
            # 保持原有的小数位数
            if '.' in rows[0][col]:
                decimal_places = len(rows[0][col].split('.')[1])
                new_row.append(f"{avg:.{decimal_places}f}")
            else:
                new_row.append(str(int(round(avg))))
        
        result_rows.append(new_row)
    
    # 准备新的标题行（移除 node_id 列）
    new_header = [header[0]] + header[2:]
    
    # 写入结果，使用prefix作为输出文件名
    output_file = os.path.join(output_dir, f'{prefix}.csv')
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(new_header)
        # 按 thread 和 ops per thread 排序
        writer.writerows(sorted(result_rows, key=lambda x: (int(x[1]), int(x[2]))))
    
    print(f"生成结果文件: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='处理CSV文件并计算平均值')
    parser.add_argument('prefix', help='要处理的CSV文件名前缀')
    args = parser.parse_args()
    
    process_files(args.prefix)

if __name__ == "__main__":
    main()

#python3 avg.py CNuni3-1
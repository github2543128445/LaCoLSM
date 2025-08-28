import csv
import os
import glob
import argparse

def process_single_file(input_file):
    # 获取输出文件名
    base_name = os.path.basename(input_file)
    output_file = os.path.join(os.path.dirname(input_file), base_name.replace('.csv', '-avg.csv'))
    
    # 读取数据
    with open(input_file, 'r') as f:
        reader = csv.reader(f)
        header = next(reader)  # 读取标题行
        data = list(reader)
    
    # 按 thread 和 ops per thread 分组
    groups = {}
    for row in data:
        key = (row[2], row[3])  # thread 和 ops per thread
        if key not in groups:
            groups[key] = []
        groups[key].append(row)
    
    # 处理每个分组并计算平均值
    result_rows = []
    for rows in groups.values():
        if not rows:
            continue
            
        # 保持 compactor 和 node_id
        new_row = rows[0][:2]
        # 添加 thread 和 ops per thread
        new_row.extend(rows[0][2:4])
        
        # 计算其他列的平均值
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
    
    # 写入结果
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(sorted(result_rows, key=lambda x: (int(x[2]), int(x[3]))))  # 按 thread 和 ops 排序
    
    # 删除原始文件
    os.remove(input_file)
    print(f"Removed original file: {input_file}")

def main():
    # 添加命令行参数解析
    parser = argparse.ArgumentParser(description='处理CSV文件并计算平均值')
    parser.add_argument('filename', help='要处理的CSV文件名（不包含路径）')
    args = parser.parse_args()
    
    # 获取所有 data-node* 目录下的指定CSV文件
    data_dir = os.path.dirname(os.path.abspath(__file__))
    for node_dir in glob.glob(os.path.join(data_dir, 'data-node*')):
        target_file = os.path.join(node_dir, args.filename + '.csv')
        if os.path.exists(target_file) and not target_file.endswith('-avg.csv'):
            print(f"Processing {target_file}...")
            process_single_file(target_file)
            print(f"Generated {target_file.replace('.csv', '-avg.csv')}")

if __name__ == "__main__":
    main()
# python3 uni_avg.py CNuni3-1
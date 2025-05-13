import csv
import os
import glob
import argparse

def process_files(ref_node, file_prefix):
    # 获取参考文件路径
    data_dir = os.path.dirname(os.path.abspath(__file__))
    ref_file = os.path.join(data_dir, f'data-{ref_node}', f'{file_prefix}.csv')
    
    if not os.path.exists(ref_file):
        print(f"参考文件 {ref_file} 不存在")
        return
    
    # 读取参考文件的分组信息
    ref_groups = {}
    with open(ref_file, 'r') as f:
        reader = csv.reader(f)
        header = next(reader)  # 读取标题行
        for row_idx, row in enumerate(reader):
            key = (row[2], row[3])  # thread 和 ops per thread
            if key not in ref_groups:
                ref_groups[key] = []
            ref_groups[key].append(row_idx)
    
    # 处理所有节点的文件
    for node_dir in glob.glob(os.path.join(data_dir, 'data-node*')):
        target_file = os.path.join(node_dir, f'{file_prefix}.csv')
        if not os.path.exists(target_file) or target_file.endswith('-avg.csv'):
            continue
            
        print(f"处理文件 {target_file}...")
        
        # 读取数据
        with open(target_file, 'r') as f:
            reader = csv.reader(f)
            header = next(reader)
            data = list(reader)
        
        # 按参考文件的分组处理数据
        result_rows = []
        for group_key, row_indices in ref_groups.items():
            group_rows = []
            for idx in row_indices:
                if idx < len(data):
                    group_rows.append(data[idx])
            
            if not group_rows:
                continue
                
            # 保持 compactor 和 node_id
            new_row = group_rows[0][:2]
            # 添加 thread 和 ops per thread
            new_row.extend(group_rows[0][2:4])
            
            # 计算其他列的平均值
            for col in range(4, len(header)):
                values = [float(row[col]) for row in group_rows]
                avg = sum(values) / len(values)
                # 保持原有的小数位数
                if '.' in group_rows[0][col]:
                    decimal_places = len(group_rows[0][col].split('.')[1])
                    new_row.append(f"{avg:.{decimal_places}f}")
                else:
                    new_row.append(str(int(round(avg))))
            
            result_rows.append(new_row)
        
        # 写入结果
        output_file = target_file.replace('.csv', '-avg.csv')
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(header)
            # 按 thread 和 ops 排序
            writer.writerows(sorted(result_rows, key=lambda x: (int(x[2]), int(x[3]))))
        
        print(f"生成结果文件 {output_file}")
        
        # 删除原始文件
        os.remove(target_file)
        print(f"删除原始文件 {target_file}")

def main():
    parser = argparse.ArgumentParser(description='根据参考节点计算CSV文件平均值')
    parser.add_argument('ref_node', help='参考节点名称 (例如: node5)')
    parser.add_argument('file_prefix', help='要处理的CSV文件名前缀 (例如: CNzf3-1)')
    args = parser.parse_args()
    
    process_files(args.ref_node, args.file_prefix)

if __name__ == "__main__":
    main()

#python3 zf_avg.py node5 CNzf3-1
#指定参考分组节点, 指定文件前缀
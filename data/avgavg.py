import csv
import os
import argparse
from collections import defaultdict

def process_single_file(input_path, output_dir):
    """处理单个CSV文件并生成结果文件"""
    # 自动生成输出文件名
    filename = os.path.basename(input_path)
    base_name, ext = os.path.splitext(filename)
    output_path = os.path.join(output_dir, f"{base_name}-result{ext}")

    # 读取数据并解析
    with open(input_path, 'r') as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    # 确定数值列索引（排除前两列）
    numeric_cols = headers[2:]
    numeric_indices = list(range(2, len(headers)))

    # 分析数值列格式
    decimal_places = []
    for idx in numeric_indices:
        samples = [row[idx] for row in rows]
        dps = set()
        for s in samples:
            if '.' in s:
                dps.add(len(s.split('.')[1]))
            else:
                dps.add(0)
        if len(dps) > 1:
            raise ValueError(f"列 {headers[idx]} 中存在不一致的数字格式")
        decimal_places.append(dps.pop())

    # 按(thread, ops)分组数据
    groups = defaultdict(list)
    for row in rows:
        key = (row[0], row[1])  # (thread, ops)
        num_values = [float(row[idx]) for idx in numeric_indices]
        groups[key].append(num_values)

    # 计算平均值并格式化
    output_rows = []
    for key in sorted(groups.keys(), key=lambda x: (int(x[0]), int(x[1]))):
        values_list = groups[key]
        avg_values = []
        for col_idx in range(len(numeric_indices)):
            total = sum(v[col_idx] for v in values_list)
            avg = total / len(values_list)
            dp = decimal_places[col_idx]
            
            # 保持原始格式
            if dp == 0:
                formatted = f"{int(round(avg))}"
            else:
                formatted = f"{avg:.{dp}f}"
            avg_values.append(formatted)

        output_rows.append([key[0], key[1]] + avg_values)

    # 写入结果文件
    os.makedirs(output_dir, exist_ok=True)
    with open(output_path, 'w', newline='') as fout:
        writer = csv.writer(fout)
        writer.writerow(headers)
        writer.writerows(output_rows)
    
    return output_path

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='合并相同thread和ops的CSV数据')
    parser.add_argument('--input', required=True, help='输入文件路径')
    parser.add_argument('--output', required=True, help='输出目录路径')
    
    args = parser.parse_args()
    
    result_path = process_single_file(args.input, args.output)
    print(f"处理完成，结果已保存至 {result_path}")


# # 基本用法
# python script.py --input ./data-avg/3-1fillrandom-uni-MNcomp.csv --output ./data-avg

# # 处理其他文件
# python script.py --input ./reports/experiment2.csv --output ./final-results
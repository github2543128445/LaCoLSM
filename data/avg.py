import csv
import os

def process_files(input_files, output_file):
    # 读取标题行并验证一致性
    headers = []
    for file in input_files:
        with open(file, 'r') as f:
            reader = csv.reader(f)
            header = next(reader)
            headers.append(header)
    
    for h in headers[1:]:
        if h != headers[0]:
            raise ValueError("CSV headers do not match across input files")
    
    # 读取所有数据行
    all_data = []
    for file in input_files:
        with open(file, 'r') as f:
            reader = csv.reader(f)
            next(reader)  # Skip header
            rows = list(reader)
            all_data.append(rows)
    
    # 验证行数一致性
    num_rows = len(all_data[0])
    for data in all_data[1:]:
        if len(data) != num_rows:
            raise ValueError("Input files have different numbers of data rows")
    
    # 确定数值列索引
    non_numeric = {0, 1}  # thread, ops per thread
    numeric_indices = [i for i in range(len(headers[0])) if i not in non_numeric]
    
    # 分析列格式（基于第一个数据行）
    decimal_places = {}
    for idx in numeric_indices:
        samples = [data[0][idx] for data in all_data]
        dps = set()
        for s in samples:
            if '.' in s:
                dps.add(len(s.split('.')[1]))
            else:
                dps.add(0)
        if len(dps) > 1:
            raise ValueError(f"Decimal format mismatch in column {headers[0][idx]}")
        decimal_places[idx] = dps.pop()
    
    # 创建输出目录
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # 处理并写入数据
    with open(output_file, 'w', newline='') as fout:
        writer = csv.writer(fout)
        writer.writerow(headers[0])
        
        for row_idx in range(num_rows):
            rows = [data[row_idx] for data in all_data]
            
            # # 验证标识列一致性
            # threads = {row[0] for row in rows}
            # ops = {row[1] for row in rows}
            # if len(threads) != 1 or len(ops) != 1:
            #     raise ValueError(f"Identifier mismatch at row {row_idx+1}")
            
            new_row = [rows[0][0], rows[0][1]]  # 保持原始标识值
            
            # 计算数值列平均值
            for idx in numeric_indices:
                values = []
                for row in rows:
                    try:
                        values.append(float(row[idx]))
                    except ValueError:
                        raise ValueError(f"Invalid number format at row {row_idx+1}, column {headers[0][idx]}")
                
                avg = sum(values) / 3
                dp = decimal_places[idx]
                
                if dp == 0:
                    formatted = f"{int(round(avg))}"
                else:
                    formatted = f"{avg:.{dp}f}"
                
                new_row.append(formatted)
            
            writer.writerow(new_row)

if __name__ == "__main__":
    # 只需修改这个基础文件名即可
    base_name = "3-1fillrandom-zipf-MNcomp.csv"  # <--- 唯一需要修改的地方
    
    input_files = [
        f'./data-node2/{base_name}',
        f'./data-node3/{base_name}',
        f'./data-node4/{base_name}'
    ]
    output_file = f'./data-avg/{base_name}'
    
    process_files(input_files, output_file)
    print(f"处理完成，结果已保存至 {output_file}")
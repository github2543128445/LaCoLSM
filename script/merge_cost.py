import re
import csv

# 定义输入文件路径和输出文件路径
input_file = "../build/temp.txt"
output_csv = "../merge_cost.csv"
normalized_csv = "../merge_cost_normalized.csv"

# 正则表达式模式，用于匹配目标行并提取5个数据
pattern = (
    r"num_of_KV (\d+), "
    r"num_of_OutPutSST (\d+), "
    r"input_next_us\(read sst\) (\d+), "
    r"finish_block_us\(write sst\) (\d+), "
    r"other calculate us (\d+)"
)

# 存储提取到的原始数据
raw_data = []

# --- 修改点：使用 'Latin-1' 编码并忽略错误 ---
# 'Latin-1' (也叫 ISO-8859-1) 编码会将每个字节直接映射为一个字符，
# 不会产生解码错误。配合 errors='ignore'，可以直接跳过无法处理的字节。
with open(input_file, "r", encoding="Latin-1", errors="ignore") as f:
    for line in f:
        line = line.strip()
        # 查找匹配的行
        match = re.search(pattern, line)
        if match:
            try:
                # 提取5个数据并转换为整数
                num_of_KV = int(match.group(1))
                num_of_OutPutSST = int(match.group(2))
                input_next_us = int(match.group(3))
                finish_block_us = int(match.group(4))
                other_calculate_us = int(match.group(5))
                # 添加到原始数据列表
                raw_data.append([
                    num_of_KV,
                    num_of_OutPutSST,
                    input_next_us,
                    finish_block_us,
                    other_calculate_us
                ])
            except ValueError as e:
                # 如果提取的数字有问题（虽然可能性很小），打印警告并跳过
                print(f"警告：提取数据失败，跳过此行 '{line}'。错误: {e}")

# 如果没有提取到数据，提示并退出
if not raw_data:
    print("未找到匹配的DBImpl::DoCompactionWork行。")
    exit()

# 写入原始数据到merge_cost.csv
with open(output_csv, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    # 写入表头
    writer.writerow([
        "num_of_KV",
        "num_of_OutPutSST",
        "input_next_us",
        "finish_block_us",
        "other_calculate_us"
    ])
    # 写入原始数据
    writer.writerows(raw_data)

# 生成归一化数据（前两列不变，后三列以最后一列为基准归一化）
normalized_data = []
for row in raw_data:
    last_val = row[-1]  # 取最后一列的值
    if last_val == 0:
        print(f"警告：跳过最后一列值为0的行 {row}")
        continue
    # 前两列保持不变，后三列进行归一化处理
    normalized_row = [
        row[0],  # num_of_KV 不变
        row[1],  # num_of_OutPutSST 不变
        round(row[2] / last_val, 6),  # input_next_us 归一化
        round(row[3] / last_val, 6),  # finish_block_us 归一化
        1.0  # other_calculate_us 设为1
    ]
    normalized_data.append(normalized_row)

# 写入归一化数据到merge_cost_normalized.csv
with open(normalized_csv, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    # 写入表头
    writer.writerow([
        "num_of_KV",
        "num_of_OutPutSST",
        "input_next_us_norm",
        "finish_block_us_norm",
        "other_calculate_us_norm"
    ])
    # 写入归一化数据
    writer.writerows(normalized_data)

print(f"处理完成！")
print(f"原始数据已保存到：{output_csv}")
print(f"归一化数据已保存到：{normalized_csv}")
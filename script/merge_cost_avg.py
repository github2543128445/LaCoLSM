import csv

# 定义输入文件路径
input_file = "../merge_cost_normalized.csv"

# 初始化存储数据的列表
# 第三列 (input_next_us_norm)，分界值 0.1
col3_below_01 = []
col3_above_eq_01 = []

# 第四列 (finish_block_us_norm)，分界值 0.05
col4_below_005 = []
col4_above_eq_005 = []

# 读取CSV文件
with open(input_file, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    next(reader)  # 跳过表头
    
    for row in reader:
        # 确保行有足够的列数，避免索引错误
        if len(row) < 4:
            continue
            
        # --- 处理第三列 ---
        try:
            col3_value = float(row[2])  # 第三列的索引是 2
            if col3_value < 0.1:
                col3_below_01.append(col3_value)
            else:
                col3_above_eq_01.append(col3_value)
        except ValueError:
            # 如果数据无法转换为浮点数，跳过
            pass
            
        # --- 处理第四列 ---
        try:
            col4_value = float(row[3])  # 第四列的索引是 3
            if col4_value < 0.05:
                col4_below_005.append(col4_value)
            else:
                col4_above_eq_005.append(col4_value)
        except ValueError:
            # 如果数据无法转换为浮点数，跳过
            pass

# 计算并输出平均值的函数
def calculate_average(data_list, description):
    if not data_list:
        print(f"{description}：无数据")
        return
    average = sum(data_list) / len(data_list)
    print(f"{description}：{average:.6f}（共{len(data_list)}个数据）")

# --- 输出结果 ---
print("--- 第三列 (input_next_us_norm) 统计 ---")
calculate_average(col3_below_01, "小于 0.1 的平均值")
calculate_average(col3_above_eq_01, "大于等于 0.1 的平均值")

print("\n--- 第四列 (finish_block_us_norm) 统计 ---")
calculate_average(col4_below_005, "小于 0.05 的平均值")
calculate_average(col4_above_eq_005, "大于等于 0.05 的平均值")
import sys
import os
import csv
import numpy as np
import matplotlib.pyplot as plt

def generate_plot(csv_file_path):
    # 提取文件名（去除路径和后缀）
    base_name = os.path.basename(csv_file_path)
    file_name = os.path.splitext(base_name)[0]
    
    # 创建图片保存目录
    pic_dir = "../pic"
    os.makedirs(pic_dir, exist_ok=True)
    output_path = os.path.join(pic_dir, f"CDF_{file_name}.png")
    
    # 读取CSV数据
    data = []
    with open(csv_file_path, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            try:
                value = float(row[0])
                data.append(value)
            except (ValueError, IndexError):
                continue  # 跳过无效数据
    
    if not data:
        raise ValueError("CSV file contains no valid data")
    
    # 计算前缀和及百分比
    data_array = np.array(data)
    prefix_sums = np.cumsum(data_array)
    total = prefix_sums[-1]
    
    if total == 0:
        raise ValueError("Total sum of data is zero, cannot calculate percentages")
    
    percentages = (prefix_sums / total) * 100
    
    # 创建图形
    plt.figure(figsize=(10, 6))
    ax = plt.gca()  # 获取当前坐标轴对象
    
    # 绘制主折线
    ax.plot(data_array, percentages, linewidth=0.8, marker='')
    
    # 强制X轴和Y轴从0开始
    ax.set_xlim(left=0)  # X轴起点为0
    ax.set_ylim(bottom=0)  # Y轴起点为0
    
    # 找到50%处的点
    p50_idx = np.argmax(percentages >= 50)
    x_50 = data_array[p50_idx]
    y_50 = percentages[p50_idx]
    
    # 标记50%点并添加数值标注
    ax.scatter(x_50, y_50, color='red', s=15)
    ax.text(x_50 * 1.05, y_50 + 1,  # 文本位置（右偏+上偏，避免遮挡）
            f"P50: x={x_50:.0f}, y={y_50:.0f}%", 
            fontsize=8, color='black')
    
    # 水平虚线：从X=0（Y轴）延伸到50%点
    ax.plot([0, x_50], [y_50, y_50], 'k--', linewidth=0.6)
    # 垂直虚线：从Y=0（X轴）延伸到50%点
    ax.plot([x_50, x_50], [0, y_50], 'k--', linewidth=0.6)
    
    # 90%点处理
    p90_idx = np.argmax(percentages >= 90)
    x_90 = data_array[p90_idx]
    y_90 = percentages[p90_idx]
    
    ax.scatter(x_90, y_90, color='red', s=15)
    ax.text(x_90 * 1.05, y_90 + 1, 
            f"P90: x={x_90:.0f}, y={y_90:.0f}%", 
            fontsize=8, color='black')
    
    ax.plot([0, x_90], [y_90, y_90], 'k--', linewidth=0.6)
    ax.plot([x_90, x_90], [0, y_90], 'k--', linewidth=0.6)
    
    p95_idx = np.argmax(percentages >=95)
    x_95 = data_array[p95_idx]
    y_95 = percentages[p95_idx]
    
    ax.scatter(x_95, y_95, color='red', s=15)
    ax.text(x_95 * 1.05, y_95 + 1, 
            f"P95: x={x_95:.0f}, y={y_95:.0f}%", 
            fontsize=8, color='black')
    
    ax.plot([0, x_95], [y_95, y_95], 'k--', linewidth=0.6)
    ax.plot([x_95, x_95], [0, y_95], 'k--', linewidth=0.6)

    # 99%点处理
    p99_idx = np.argmax(percentages >= 99)
    x_99 = data_array[p99_idx]
    y_99 = percentages[p99_idx]
    
    ax.scatter(x_99, y_99, color='red', s=15)
    ax.text(x_99 * 1.05, y_99 + 1, 
            f"P99: x={x_99:.0f}, y={y_99:.0f}%", 
            fontsize=8, color='black')
    
    ax.plot([0, x_99], [y_99, y_99], 'k--', linewidth=0.6)
    ax.plot([x_99, x_99], [0, y_99], 'k--', linewidth=0.6)
    
    # 设置坐标轴标签
    ax.set_title(f'CDF of {file_name}')
    ax.set_xlabel('Insert Latancy (ns)')
    ax.set_ylabel('Cumulative Percentage (%)')
    
    # 保存图片
    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.close()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <csv_file_path>")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    try:
        generate_plot(csv_file)
        print(f"Plot generated: ../pic/CDF_{os.path.splitext(os.path.basename(csv_file))[0]}.png")
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
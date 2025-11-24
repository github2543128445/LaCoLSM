import csv
import os
import argparse
import matplotlib.pyplot as plt
from pathlib import Path

def generate_line_chart(csv_file_path):
    # 提取文件名（去除路径和后缀）
    file_name = Path(csv_file_path).stem
    
    # 创建保存图片的目录（如果不存在）
    pic_dir = "../pic"
    os.makedirs(pic_dir, exist_ok=True)
    
    # 读取CSV文件数据
    data = []
    try:
        with open(csv_file_path, 'r') as file:
            csv_reader = csv.reader(file)
            for row in csv_reader:
                if row:  # 跳过空行
                    try:
                        value = float(row[0])
                        data.append(value)  # 不再过滤非正数（线性坐标支持所有数值）
                    except ValueError:
                        print(f"警告：无法将 '{row[0]}' 转换为数值，已跳过")
    except FileNotFoundError:
        print(f"错误：文件 '{csv_file_path}' 不存在")
        return
    except Exception as e:
        print(f"读取文件时发生错误：{str(e)}")
        return
    
    if not data:
        print("错误：没有有效的数据可绘制")
        return
    
    # 生成X轴数据（平均分布）
    x_data = list(range(len(data)))
    
    # 绘制折线图（调整线宽和去除数据点）
    plt.figure(figsize=(10, 6))
    plt.plot(x_data, data, linestyle='-', color='b', linewidth=0.8, marker=None)
    
    # 若需要保留极小数据点，可替换为以下行
    # plt.plot(x_data, data, linestyle='-', color='b', linewidth=0.8, marker='.', markersize=1)
    
    # 移除Y轴对数刻度设置（默认即为线性坐标）
    
    # 添加图表标题和轴标签（更新标题，移除对数相关描述）
    plt.title(f'Data from {file_name}')
    plt.xlabel('Index (evenly distributed)')
    plt.ylabel('Value')  # 移除对数刻度说明
    
    # 保存图片
    output_path = os.path.join(pic_dir, f"{file_name}.png")
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"折线图已保存至：{output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='生成CSV文件数据的折线图（细线，无数据点）')
    parser.add_argument('file', help='CSV文件的路径（相对路径或绝对路径）')
    args = parser.parse_args()
    
    generate_line_chart(args.file)
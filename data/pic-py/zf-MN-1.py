import pandas as pd
import matplotlib.pyplot as plt
import glob
import os

# 设置字体
plt.rcParams['font.family'] = 'Liberation Serif'
plt.rcParams['font.style'] = 'italic'

# 获取所有MNzf3-1-avg.csv文件
data_files = glob.glob('../data-node*/MNzf3-1-avg.csv')

# 读取并处理所有数据
all_data = []
for file in data_files:
    # 从文件路径中提取node编号
    node_num = int(file.split('node')[1].split('/')[0])
    df = pd.read_csv(file)
    df['node'] = node_num
    all_data.append(df)

if not all_data:
    print("未找到任何数据文件！")
    exit(1)

# 合并所有数据
combined_data = pd.concat(all_data)

# 将throughput转换为Mops/sec
combined_data['throughput'] = combined_data['throughput'] / 1000000

# 获取唯一的node值和行索引
nodes = sorted(combined_data['node'].unique())
row_indices = range(len(combined_data) // len(nodes))

# 设置图表样式
plt.figure(figsize=(12, 6))
bar_width = 0.1
group_spacing = 0.3

# 定义柔和的颜色方案
colors = ['#7CB9E8', '#F08080', '#98FB98', '#DDA0DD', '#F0E68C', '#B0C4DE', '#E6B0AA']

# 绘制柱状图
for i, node in enumerate(nodes):
    node_data = combined_data[combined_data['node'] == node]
    x = [j + i * bar_width for j in range(len(node_data))]
    plt.bar(x, 
            node_data['throughput'],
            bar_width,
            label=f'Node {node}',
            color=colors[i % len(colors)],
            alpha=0.8,
            zorder=2)  # 确保柱状图在网格线上方

# 设置x轴标签
plt.xticks([i + (len(nodes) - 1) * bar_width / 2 for i in range(len(row_indices))],
           combined_data[combined_data['node'] == nodes[0]]['thread'])

# 设置标签和标题
plt.xlabel('Number of Threads')
plt.ylabel('Throughput (Mops/sec)')

# 设置y轴范围从1.0开始
y_min, y_max = plt.ylim()
plt.ylim(1.0, y_max * 1.2)

# 将图例移到右上角
plt.legend(loc='upper right')
plt.grid(True, linestyle='--', alpha=0.7, zorder=0)  # 将网格线置于底层

# 保存图片
plt.savefig('../pic-png/zf-MN-1.png', dpi=300, bbox_inches='tight')
plt.savefig('../pic-svg/zf-MN-1.svg', bbox_inches='tight')
plt.close()
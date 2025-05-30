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
plt.figure(figsize=(10, 5))
bar_width = 0.095  # 减小柱子宽度
group_spacing = 0.3

# 绘制柱状图
for i, node in enumerate(nodes):
    node_data = combined_data[combined_data['node'] == node]
    x = [j + i * (bar_width + 0.005) for j in range(len(node_data))]  # 添加0.005的间隔
    
    # 根据不同的node设置不同的填充样式
    if i == 0:  # node5
        plt.bar(x, 
                node_data['throughput'],
                bar_width,
                label=f'Node {node}',
                color='#DC143C',
                alpha=1,
                zorder=2)
    elif i == 1:  # node6
        plt.bar(x, 
                node_data['throughput'],
                bar_width,
                label=f'Node {node}',
                color='none',
                edgecolor='#000080',
                hatch='//////',
                zorder=2)
    else:  # node7
        plt.bar(x, 
                node_data['throughput'],
                bar_width,
                label=f'Node {node}',
                color='none',
                edgecolor='#87CEEB',
                hatch='xxx',
                zorder=2)

# 设置x轴标签位置需要相应调整
plt.xticks([i + (len(nodes) - 1) * (bar_width + 0.005) / 2 for i in range(len(row_indices))],
           combined_data[combined_data['node'] == nodes[0]]['thread'])

# 设置标签和标题
plt.xlabel('Number of Threads')
plt.ylabel('Throughput (Mops/sec)')

# 获取当前y轴的范围
y_min, y_max = plt.ylim()
# 增加y轴上限，使图表有更多空间
plt.ylim(y_min, y_max * 1.2)

# 将图例移到右上角
plt.legend(loc='upper right')
plt.grid(True, linestyle='--', alpha=0.7, zorder=0)  # 将网格线置于底层

# 保存图片
plt.savefig('../pic-png/zf-MN.png', dpi=300, bbox_inches='tight')
plt.savefig('../pic-svg/zf-MN.svg', bbox_inches='tight')
plt.close()
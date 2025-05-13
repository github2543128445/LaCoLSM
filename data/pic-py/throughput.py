import pandas as pd
import matplotlib.pyplot as plt
import os

# 设置全局字体为 Liberation Serif 斜体
plt.rcParams['font.family'] = 'Liberation Serif'
plt.rcParams['font.style'] = 'italic'

# 创建目标文件夹
os.makedirs('../pic-png', exist_ok=True)
os.makedirs('../pic-svg', exist_ok=True)

# 读取数据
cn_data = pd.read_csv('../data-avg/CNuni.csv')
mn_data = pd.read_csv('../data-avg/MNuni.csv')

# 创建图表
plt.figure(figsize=(10, 6))

# 绘制两条折线
plt.plot(cn_data['thread'], cn_data['throughput']/1000000, marker='o', label='CN-Compaction')
plt.plot(mn_data['thread'], mn_data['throughput']/1000000, marker='s', label='MN-Compaction')

# 设置图表属性
plt.xlabel('Number of Threads')
plt.ylabel('Throughput (Mops/sec)')
plt.grid(True, linestyle='--', alpha=0.7)
plt.legend()

# 保存图表
plt.savefig('../pic-png/uni-throughput.png', dpi=300, bbox_inches='tight')
plt.savefig('../pic-svg/uni-throughput.svg', bbox_inches='tight')
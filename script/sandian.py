import sys
import pandas as pd
import matplotlib.pyplot as plt
import os

def main():
    # 检查参数数量
    if len(sys.argv) != 4:
        print("用法: python scatter_plot.py <csv文件路径> <X轴列号> <Y轴列号>")
        print("注意: 列号从1开始计数")
        print("示例: python scatter_plot.py data.csv 2 3")
        sys.exit(1)
    
    # 获取命令行参数
    file_path = sys.argv[1]
    x_col = int(sys.argv[2]) - 1  # 转换为0基索引
    y_col = int(sys.argv[3]) - 1
    
    try:
        # 读取CSV文件
        df = pd.read_csv(file_path)
        
        # 检查列号是否有效
        if x_col < 0 or x_col >= len(df.columns) or y_col < 0 or y_col >= len(df.columns):
            print(f"错误: 列号无效。文件共有{len(df.columns)}列，请确保列号在1-{len(df.columns)}范围内")
            sys.exit(1)
        
        # 获取列名
        x_col_name = df.columns[x_col]
        y_col_name = df.columns[y_col]
        
        # 创建散点图
        plt.figure(figsize=(10, 6))
        plt.scatter(df.iloc[:, x_col], df.iloc[:, y_col], alpha=0.6, s=50, c='blue')
        
        # 添加标签和标题
        # plt.xlabel(x_col_name)
        # plt.ylabel(y_col_name)
        # plt.title(f'{y_col_name} 与 {x_col_name} 的关系散点图')
        
        # 添加网格
        plt.grid(True, alpha=0.3)
        
        # 从输入路径中提取文件名（不含扩展名）[6,8](@ref)
        base_name = os.path.splitext(os.path.basename(file_path))[0]
        
        # 构造输出路径
        output_dir = "../pic"
        # 确保输出目录存在[3,5](@ref)
        os.makedirs(output_dir, exist_ok=True)
        
        # 固定输出为jpg格式
        output_path = os.path.join(output_dir, f"{base_name}.jpg")
        
        # 保存图表为图片文件
        plt.savefig(output_path, dpi=300, bbox_inches='tight', format='jpg')
        print(f"散点图已保存为: {output_path}")
        
    except FileNotFoundError:
        print(f"错误: 文件 '{file_path}' 未找到")
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print("错误: CSV文件为空")
        sys.exit(1)
    except pd.errors.ParserError:
        print("错误: CSV文件格式错误")
        sys.exit(1)
    except Exception as e:
        print(f"发生未知错误: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
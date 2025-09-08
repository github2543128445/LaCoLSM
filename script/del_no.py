import sys
import paramiko

def main():
    # 检查参数数量
    if len(sys.argv) != 3:
        print("用法: python delete_csv_rows.py <本节点编号> <目标NO号>")
        sys.exit(1)
    
    # 获取参数
    current_node = sys.argv[1]
    target_no = sys.argv[2]
    
    # 确保当前节点编号是数字
    if not current_node.isdigit():
        print("错误: 本节点编号必须是数字")
        sys.exit(1)
    
    # 遍历节点1-7
    for node in range(1, 8):
        node_str = str(node)
        
        # 跳过本节点
        if node_str == current_node:
            print(f"跳过本节点: {node_str}")
            continue
        
        # 处理其他节点
        print(f"处理节点: {node_str}")
        hostname = f"skv-node{node_str}"
        
        try:
            # 建立SSH连接（假设已配置SSH密钥认证）
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(hostname, username='kvgroup')  # 假设用户名为kvgroup
            
            # 查找符合条件的CSV文件
            find_cmd = "find /home/kvgroup/louzy/LaCoLSM/* -maxdepth 1 -type f -name '*.csv'"
            stdin, stdout, stderr = ssh.exec_command(find_cmd)
            csv_files = stdout.read().decode().splitlines()
            
            if not csv_files:
                print(f"节点 {node_str} 没有找到符合条件的CSV文件")
                ssh.close()
                continue
            
            # 处理每个CSV文件
            for csv_file in csv_files:
                print(f"处理文件: {csv_file}")
                
                # 检查文件是否包含NO列
                check_cmd = f"head -n 1 {csv_file} | grep -q 'NO'"
                stdin, stdout, stderr = ssh.exec_command(check_cmd)
                exit_status = stdout.channel.recv_exit_status()
                
                if exit_status != 0:
                    print(f"文件 {csv_file} 不包含NO列，跳过")
                    continue
                
                # 创建临时文件，用于存储处理后的数据
                temp_file = f"{csv_file}.tmp"
                
                # 使用awk删除NO等于目标值的行
                delete_cmd = f"""awk -F ',' '$1 == "NO" {{print; next}} $1 != "{target_no}"' {csv_file} > {temp_file} && mv {temp_file} {csv_file}"""
                stdin, stdout, stderr = ssh.exec_command(delete_cmd)
                exit_status = stdout.channel.recv_exit_status()
                
                if exit_status == 0:
                    print(f"文件 {csv_file} 处理完成")
                else:
                    error = stderr.read().decode()
                    print(f"处理文件 {csv_file} 时出错: {error}")
                    ssh.exec_command(f"rm -f {temp_file}")
            
            # 关闭SSH连接
            ssh.close()
            
        except Exception as e:
            print(f"连接或处理节点 {node_str} 时出错: {str(e)}")

if __name__ == "__main__":
    main()


#python3 /home/kvgroup/louzy/LaCoLSM/script/del_no.py <本节点编号> <目标NO号>
#删除远程节点中NO次测试的信息
#快速用法：python3 /home/kvgroup/louzy/LaCoLSM/script/del_no.py 3 1
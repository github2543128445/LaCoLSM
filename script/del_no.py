import sys
import paramiko
import subprocess

def process_remote_node(node_str, target_nos):
    """处理远程节点的CSV文件"""
    print(f"处理远程节点: {node_str}")
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
            print(f"远程节点 {node_str} 没有找到符合条件的CSV文件")
            ssh.close()
            return
        
        # 处理每个CSV文件
        process_files_ssh(ssh, csv_files, target_nos)
        
        # 关闭SSH连接
        ssh.close()
        
    except Exception as e:
        print(f"连接或处理远程节点 {node_str} 时出错: {str(e)}")

def process_local_node(target_nos):
    """处理本地节点的CSV文件"""
    print(f"处理本地节点")
    
    try:
        # 查找符合条件的CSV文件
        find_cmd = "find /home/kvgroup/louzy/LaCoLSM/* -maxdepth 1 -type f -name '*.csv'"
        result = subprocess.run(find_cmd, shell=True, capture_output=True, text=True)
        csv_files = result.stdout.splitlines()
        
        if not csv_files:
            print("本地节点没有找到符合条件的CSV文件")
            return
        
        # 处理每个CSV文件
        process_files_local(csv_files, target_nos)
        
    except Exception as e:
        print(f"处理本地节点时出错: {str(e)}")

def process_files_ssh(ssh, csv_files, target_nos):
    """通过SSH处理远程文件"""
    for csv_file in csv_files:
        print(f"处理远程文件: {csv_file}")
        
        # 检查文件是否包含NO列
        check_cmd = f"head -n 1 {csv_file} | grep -q 'NO'"
        stdin, stdout, stderr = ssh.exec_command(check_cmd)
        exit_status = stdout.channel.recv_exit_status()
        
        if exit_status != 0:
            print(f"远程文件 {csv_file} 不包含NO列，跳过")
            continue
        
        # 对每个目标NO号执行删除操作
        for target_no in target_nos:
            print(f"删除远程文件 {csv_file} 中NO={target_no}的记录")
            
            # 创建临时文件，用于存储处理后的数据
            temp_file = f"{csv_file}.tmp.{target_no}"
            
            # 使用awk删除NO等于目标值的行
            delete_cmd = f"""awk -F ',' '$1 == "NO" {{print; next}} $1 != "{target_no}"' {csv_file} > {temp_file} && mv {temp_file} {csv_file}"""
            stdin, stdout, stderr = ssh.exec_command(delete_cmd)
            exit_status = stdout.channel.recv_exit_status()
            
            if exit_status == 0:
                print(f"远程文件 {csv_file} 中NO={target_no}的记录已删除")
            else:
                error = stderr.read().decode()
                print(f"处理远程文件 {csv_file} 中NO={target_no}时出错: {error}")
                ssh.exec_command(f"rm -f {temp_file}")

def process_files_local(csv_files, target_nos):
    """处理本地文件"""
    for csv_file in csv_files:
        print(f"处理本地文件: {csv_file}")
        
        # 检查文件是否包含NO列
        check_cmd = f"head -n 1 {csv_file} | grep -q 'NO'"
        result = subprocess.run(check_cmd, shell=True)
        
        if result.returncode != 0:
            print(f"本地文件 {csv_file} 不包含NO列，跳过")
            continue
        
        # 对每个目标NO号执行删除操作
        for target_no in target_nos:
            print(f"删除本地文件 {csv_file} 中NO={target_no}的记录")
            
            # 创建临时文件，用于存储处理后的数据
            temp_file = f"{csv_file}.tmp.{target_no}"
            
            # 使用awk删除NO等于目标值的行
            delete_cmd = f"""awk -F ',' '$1 == "NO" {{print; next}} $1 != "{target_no}"' {csv_file} > {temp_file} && mv {temp_file} {csv_file}"""
            result = subprocess.run(delete_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"本地文件 {csv_file} 中NO={target_no}的记录已删除")
            else:
                error = result.stderr
                print(f"处理本地文件 {csv_file} 中NO={target_no}时出错: {error}")
                subprocess.run(f"rm -f {temp_file}", shell=True)

def main():
    # 检查参数数量，至少需要节点编号和一个目标NO号
    if len(sys.argv) < 3:  # 修改参数检查，至少需要节点编号和一个目标NO
        print("用法: python delete_csv_rows.py <本节点编号> <目标NO号1> [<目标NO号2> ...]")
        sys.exit(1)
    
    # 获取参数
    current_node = sys.argv[1]
    target_nos = sys.argv[2:]  # 获取所有目标NO号
    
    # 确保当前节点编号是数字
    if not current_node.isdigit():
        print("错误: 本节点编号必须是数字")
        sys.exit(1)
    
    # 确保所有目标NO号都是数字
    for no in target_nos:
        if not no.isdigit():
            print(f"错误: 目标NO号 '{no}' 必须是数字")
            sys.exit(1)
    
    # 遍历节点1-7
    for node in range(1, 8):
        node_str = str(node)
        
        # 处理本节点
        if node_str == current_node:
            process_local_node(target_nos)
        else:
            # 处理远程节点
            process_remote_node(node_str, target_nos)

if __name__ == "__main__":
    main()


#python3 /home/kvgroup/louzy/LaCoLSM/script/del_no.py <本节点编号> <目标NO号1> [<目标NO号2> ...]
#删除远程节点中NO次测试的信息
#快速用法：python3 /home/kvgroup/louzy/LaCoLSM/script/del_no.py 3 1 10 15
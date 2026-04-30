# SSH 工具合集

## 一、SSH 安全加固脚本
### 功能清单
- ✅ 服务器本地自动生成 SSH ED25519 密钥对
- ✅ 私钥随机 20 位高强度密码（大小写字母 + 数字 + @#&*）
- ✅ 浏览器私钥下载链接，60秒自动失效关闭端口
- ✅ 自定义 SSH 登录端口
- ✅ 防火墙关闭默认22端口，彻底禁用密码登录，仅密钥可连
- ✅ 系统时间同步强制配置：`time1.google.com time2.google.com time3.google.com time4.google.com`
- ✅ 全系统通用：Ubuntu / Debian / CentOS

### 一键运行命令
```bash
apt update >/dev/null 2>&1 || yum update -y >/dev/null 2>&1 && apt install -y wget >/dev/null 2>&1 || yum install -y wget >/dev/null 2>&1 && wget -N https://raw.githubusercontent.com/ai7778/ssh/main/ssh.sh && chmod +x ssh.sh && ./ssh.sh






## 二、交互式 SSH 密钥批量生成脚本

### 功能清单
✅ 自动安装 curl、net-tools 依赖  
✅ 自动处理端口占用 9096 → 8181  
✅ 交互式自定义密钥生成对数  
✅ 交互式自定义密码位数 12~30 位  
✅ 5 分钟自动关闭服务、清理文件，恢复服务器原状  
✅ 完美修复 502 网关错误  
✅ 全系统通用：Ubuntu / Debian / CentOS  

### 一键运行命令
```bash
apt update >/dev/null 2>&1 || yum update -y >/dev/null 2>&1 && apt install -y wget openssl zip python3 curl >/dev/null 2>&1 || yum install -y wget openssl zip python3 curl >/dev/null 2>&1 && wget -N https://raw.githubusercontent.com/ai7778/ssh/main/ssh_key_gen.sh && chmod +x ssh_key_gen.sh && ./ssh_key_gen.sh

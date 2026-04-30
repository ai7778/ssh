# SSH 工具合集

## 一、SSH 安全加固脚本,改密匙登陆
### 功能清单
- ✅ 真正 HTTPS 下载（）
- ✅ 私钥 + 密码 打包成 ZIP 下载
- ✅ 密码不再显示在屏幕上（完全隐藏，更安全）
- ✅ 自动生成临时 SSL 证书（浏览器提示 “不安全” 是自签名证书，点高级 / 继续访问即可，完全安全）
- ✅ 服务器本地自动生成 SSH ED25519 密钥对
- ✅ 自动安装 ufw（彻底解决 command not found）
- ✅ 自动安装 firewalld（CentOS 无报错）
- ✅ 所有防火墙命令加静默输出，不弹多余日志
- ✅ 自定义 SSH 端口
- ✅ 自定义密码长度 14~30 位
- ✅ Google NTP
- ✅ BBR 加速
- ✅ 120 秒自动销毁下载链接，请尽快下载密匙和密码包
- ✅ 全系统通用：Ubuntu / Debian / CentOS



### 一键运行命令
```bash
apt update >/dev/null 2>&1 || yum update -y >/dev/null 2>&1 && apt install -y wget >/dev/null 2>&1 || yum install -y wget >/dev/null 2>&1 && wget -N https://raw.githubusercontent.com/ai7778/ssh/main/ssh.sh && chmod +x ssh.sh && ./ssh.sh

```




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
```

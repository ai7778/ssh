#!/bin/bash
clear
echo "============================================="
echo "  Ubuntu/Debian/CentOS 通用安全加固脚本"
echo "============================================="

# 全局变量
SSH_PORT=""
PASS_LEN=""

# 1. 输入SSH端口并校验
while true; do
    read -p "请输入 SSH 自定义端口(1024-65535)：" SSH_PORT
    if [[ $SSH_PORT =~ ^[0-9]+$ && $SSH_PORT -ge 1024 && $SSH_PORT -le 65535 ]]; then
        break
    fi
    echo "❌ 端口无效，请输入 1024~65535 之间数字"
done

# 2. 输入私钥密码长度 14~30 位
while true; do
    read -p "请输入私钥密码长度(14-30)：" PASS_LEN
    if [[ $PASS_LEN =~ ^[0-9]+$ && $PASS_LEN -ge 14 && $PASS_LEN -le 30 ]]; then
        break
    fi
    echo "❌ 只能输入 14~30 之间数字"
done

# 3. 识别系统
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_INSTALL="apt install -yq"
    PKG_UPDATE="apt update -yq"
    PKG_UPGRADE="apt upgrade -yq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
    FIREWALL="ufw"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    PKG_INSTALL="yum install -y -q"
    PKG_UPDATE="yum update -y -q"
    PKG_UPGRADE=""
    FIREWALL="firewalld"
else
    echo "❌ 不支持当前系统"
    exit 1
fi

echo -e "\n[系统检测] 当前系统：$OS"

# 4. 清理包管理器锁定
echo -e "\n[1/9] 清理包锁定..."
pkill -f apt >/dev/null 2>&1 || true
pkill -f yum >/dev/null 2>&1 || true
pkill -f dpkg >/dev/null 2>&1 || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
rm -f /var/run/yum.pid

# 5. 系统更新升级
echo -e "\n[2/9] 系统更新升级..."
export DEBIAN_FRONTEND=noninteractive
$PKG_UPDATE
$PKG_UPGRADE

# 6. 安装必备依赖 + 防火墙
echo -e "\n[3/9] 安装必备组件..."
if [ "$FIREWALL" = "ufw" ]; then
    $PKG_INSTALL sudo curl wget python3 openssl ufw
else
    $PKG_INSTALL sudo curl wget python3 openssl firewalld
fi

# 7. 时区 + NTP
echo -e "\n[4/9] 配置时区与Google NTP服务器..."
timedatectl set-timezone America/Los_Angeles 2>/dev/null

cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=time1.google.com time2.google.com time3.google.com time4.google.com
FallbackNTP=0.us.pool.ntp.org 1.us.pool.ntp.org
EOF

systemctl enable --now systemd-timesyncd >/dev/null 2>&1
systemctl restart systemd-timesyncd >/dev/null 2>&1

# 8. BBR
echo -e "\n[5/9] 开启BBR加速..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

# 9. SSH密钥
echo -e "\n[6/9] 生成SSH密钥与${PASS_LEN}位高强度私钥密码..."
CHARSET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#!%^*'
RANDOM_PASS=$(head /dev/urandom | tr -dc "$CHARSET" | head -c $PASS_LEN)

mkdir -p /root/.ssh
chmod 700 /root/.ssh
cd /root/.ssh
ssh-keygen -t ed25519 -N "$RANDOM_PASS" -f id_ed25519 -q

cat id_ed25519.pub > authorized_keys
chmod 600 authorized_keys
chmod 600 id_ed25519
chown root:root /root/.ssh -R

# 10. SSH加固
echo -e "\n[7/9] 加固SSH配置..."
sed -i 's/^Port 22/#Port 22/' /etc/ssh/sshd_config
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile     .ssh\/authorized_keys/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl restart sshd 2>/dev/null || systemctl restart ssh

# 11. 防火墙
echo -e "\n[8/9] 配置防火墙..."
if [ "$FIREWALL" = "ufw" ]; then
    ufw allow $SSH_PORT/tcp >/dev/null 2>&1
    ufw allow 8088/tcp >/dev/null 2>&1
    ufw delete allow 22/tcp >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    ufw reload >/dev/null 2>&1
else
    systemctl enable --now firewalld >/dev/null 2>&1
    firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
    firewall-cmd --permanent --add-port=8088/tcp
    firewall-cmd --permanent --remove-port=22/tcp 2>/dev/null
    firewall-cmd --reload
fi

# 12. HTTPS 下载服务（自动生成SSL证书）
echo -e "\n[9/9] 启动HTTPS私钥下载服务..."
IP=$(curl -s ifconfig.me 2>/dev/null)
[ -z "$IP" ] && IP="127.0.0.1"

mkdir -p /tmp/sshdown
cp /root/.ssh/id_ed25519 /tmp/sshdown/
cd /tmp/sshdown

# 自动生成自签名SSL证书
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 1 -nodes -subj "/CN=$IP" >/dev/null 2>&1

# 启动HTTPS服务器
cat > server.py <<EOF
import http.server
import ssl
import os

os.chdir('/tmp/sshdown')
server = http.server.HTTPServer(('0.0.0.0', 8088), http.server.SimpleHTTPRequestHandler)
server.socket = ssl.wrap_socket(server.socket, certfile='cert.pem', keyfile='key.pem', server_side=True)
server.serve_forever()
EOF

python3 server.py >/dev/null 2>&1 &
HTTP_PID=$!
DOWN_URL="https://${IP}:8088/id_ed25519"

# 60秒自动销毁
(
sleep 60
kill -9 $HTTP_PID >/dev/null 2>&1
rm -rf /tmp/sshdown

if [ "$FIREWALL" = "ufw" ]; then
    ufw delete allow 8088/tcp >/dev/null 2>&1
else
    firewall-cmd --permanent --remove-port=8088/tcp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
fi
) &

# 输出
echo -e "\n============================================="
echo "✅ 部署完成！"
echo "🔌 SSH 端口：$SSH_PORT"
echo "🔐 私钥密码长度：${PASS_LEN}位"
echo "🔑 私钥密码：$RANDOM_PASS"
echo "🌐 私钥下载链接：$DOWN_URL"
echo "⏰ 60秒后自动销毁"
echo "🚀 BBR 已开启 | 🛡️ 仅密钥登录"
echo "============================================="

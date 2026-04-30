#!/bin/bash
clear
echo "============================================="
echo "  Ubuntu/Debian/CentOS 通用安全加固脚本"
echo "============================================="

# 全局变量
NTP_SERVERS="time1.google.com time2.google.com time3.google.com time4.google.com"
SSH_PORT=""

# 1. 选择SSH端口
read -p "请输入 SSH 自定义端口(1024-65535)：" SSH_PORT

# 2. 识别系统
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
    echo "不支持当前系统"
    exit 1
fi

echo -e "\n[系统检测] 当前系统：$OS"

# 3. 解锁包管理器
echo -e "\n[1/8] 清理包锁定..."
pkill -f apt >/dev/null 2>&1 || true
pkill -f yum >/dev/null 2>&1 || true
pkill -f dpkg >/dev/null 2>&1 || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
rm -f /var/run/yum.pid

# 4. 系统更新
echo -e "\n[2/8] 系统更新升级..."
export DEBIAN_FRONTEND=noninteractive
$PKG_UPDATE
$PKG_UPGRADE

# 5. 安装通用依赖
echo -e "\n[3/8] 安装必备组件..."
$PKG_INSTALL sudo curl wget python3 openssl

# 6. 时区 + 通用NTP时间配置
echo -e "\n[4/8] 配置时区与Google NTP服务器..."
timedatectl set-timezone America/Los_Angeles 2>/dev/null

# systemd-timesyncd 配置
if [ -f /etc/systemd/timesyncd.conf ]; then
    sed -i "s/^#NTP=.*/NTP=$NTP_SERVERS/" /etc/systemd/timesyncd.conf
    sed -i "s/^NTP=.*/NTP=$NTP_SERVERS/" /etc/systemd/timesyncd.conf
else
    mkdir -p /etc/systemd/
    echo -e "[Time]\nNTP=$NTP_SERVERS" > /etc/systemd/timesyncd.conf
fi

systemctl enable --now systemd-timesyncd >/dev/null 2>&1
systemctl restart systemd-timesyncd >/dev/null 2>&1

# 7. 生成20位强密码 + ED25519密钥
echo -e "\n[5/8] 生成SSH密钥与20位高强度私钥密码..."
CHARSET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#!%^*'
RANDOM_PASS=$(head /dev/urandom | tr -dc "$CHARSET" | head -c 20)

mkdir -p /root/.ssh
chmod 700 /root/.ssh
cd /root/.ssh
ssh-keygen -t ed25519 -N "$RANDOM_PASS" -f id_ed25519 -q

cat id_ed25519.pub > authorized_keys
chmod 600 authorized_keys
chmod 600 id_ed25519
chown root:root /root/.ssh -R

# 8. SSH 通用加固配置
echo -e "\n[6/8] 加固SSH配置..."
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

# 9. 通用防火墙适配
echo -e "\n[7/8] 配置防火墙..."
if [ "$FIREWALL" = "ufw" ]; then
    ufw allow $SSH_PORT/tcp
    ufw allow 8088/tcp
    ufw delete allow 22/tcp 2>/dev/null
    ufw --force enable
    ufw reload
else
    firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
    firewall-cmd --permanent --add-port=8088/tcp
    firewall-cmd --permanent --remove-port=22/tcp 2>/dev/null
    firewall-cmd --reload
fi

# 10. 私钥下载服务 60秒自动关闭
IP=$(curl -s ifconfig.me)
mkdir -p /tmp/sshdown
cp /root/.ssh/id_ed25519 /tmp/sshdown/
cd /tmp/sshdown

python3 -m http.server 8088 >/dev/null 2>&1 &
HTTP_PID=$!
DOWN_URL="http://${IP}:8088/id_ed25519"

# 后台倒计时自动清理
(
sleep 60
kill -9 $HTTP_PID >/dev/null 2>&1
rm -rf /tmp/sshdown
if [ "$FIREWALL" = "ufw" ]; then
    ufw delete allow 8088/tcp 2>/dev/null
else
    firewall-cmd --permanent --remove-port=8088/tcp 2>/dev/null
    firewall-cmd --reload
fi
) &

# 输出结果
echo -e "\n============================================="
echo "✅ 部署完成！系统：$OS"
echo "🔌 SSH 端口：$SSH_PORT"
echo "🔑 私钥20位强密码：$RANDOM_PASS"
echo "🌐 私钥下载链接：$DOWN_URL"
echo "⏰ 60秒后链接自动失效、8088端口关闭"
echo "🕒 NTP时间源：$NTP_SERVERS"
echo "🛡️ 已禁用密码登录，仅密钥可登录"
echo "============================================="

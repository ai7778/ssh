#!/bin/bash
clear

echo "============================================="
echo "     服务器安全加固脚本（Ubuntu/Debian/CentOS 通用）"
echo "============================================="
echo ""

read -p "请输入 SSH 端口 (1024-65535)：" SSH_PORT

# 自动识别系统
if command -v apt-get &> /dev/null; then
    OS="debian"
    PKG_UPDATE="apt-get update -yq"
    PKG_UPGRADE="apt-get upgrade -yq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
    PKG_INSTALL="apt install -yq"
    FIREWALL="ufw"
elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
    OS="centos"
    PKG_UPDATE="yum makecache -q"
    PKG_UPGRADE="yum update -yq"
    PKG_INSTALL="yum install -yq"
    FIREWALL="firewalld"
else
    echo "❌ 不支持的系统"
    exit 1
fi

# ====================== 解锁包管理器 ======================
echo -e "\n[1/9] 自动解锁包管理器缓存..."
if [ "$OS" = "debian" ]; then
    pkill -f apt >/dev/null 2>&1 || true
    pkill -f dpkg >/dev/null 2>&1 || true
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
    dpkg --configure -a >/dev/null 2>&1
fi

# ====================== 系统更新 ======================
echo -e "\n[2/9] 系统更新升级..."
export DEBIAN_FRONTEND=noninteractive
$PKG_UPDATE
$PKG_UPGRADE

# ====================== 安装依赖 ======================
echo -e "\n[3/9] 安装必备工具..."
if [ "$OS" = "debian" ]; then
    $PKG_INSTALL sudo curl wget ca-certificates ufw systemd-timesyncd
else
    $PKG_INSTALL curl wget ca-certificates firewalld chrony
    systemctl enable --now chronyd
fi

# ====================== 时区 NTP ======================
echo -e "\n[4/9] 设置时区与时间同步..."
timedatectl set-timezone America/Los_Angeles

cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=time1.google.com time2.google.com time3.google.com time4.google.com
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org
EOF

systemctl daemon-reload >/dev/null 2>&1
systemctl enable --now systemd-timesyncd >/dev/null 2>&1

# ====================== BBR 加速 ======================
echo -e "\n[5/9] 开启 BBR 加速..."
cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p >/dev/null 2>&1

# ====================== 固定公钥 ======================
echo -e "\n[6/9] 下载公钥..."
USE_KEY="flagstick_id_ed25519.pub"

mkdir -p ~/.ssh
chmod 700 ~/.ssh
cd ~/.ssh
rm -f authorized_keys

wget --https-only -q -t 2 "https://raw.githubusercontent.com/ai7778/ssh/main/key/${USE_KEY}" -O authorized_keys
chmod 600 authorized_keys

# ====================== SSH 加固 ======================
echo -e "\n[7/9] 加固 SSH 配置..."
sed -i 's/^Port 22/#Port 22/' /etc/ssh/sshd_config
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# ====================== 防火墙 ======================
echo -e "\n[8/9] 配置防火墙..."
if [ "$FIREWALL" = "ufw" ]; then
    ufw allow "$SSH_PORT"/tcp >/dev/null 2>&1
    ufw delete allow 22/tcp >/dev/null 2>&1 || true
    ufw --force enable >/dev/null 2>&1
    ufw reload >/dev/null 2>&1
else
    systemctl enable --now firewalld >/dev/null 2>&1
    firewall-cmd --permanent --add-port=$SSH_PORT/tcp
    firewall-cmd --permanent --remove-port=22/tcp 2>/dev/null
    firewall-cmd --reload
fi

# ====================== 重启 SSH ======================
echo -e "\n[9/9] 重启 SSH 服务..."
systemctl restart sshd 2>/dev/null || systemctl restart ssh

# ====================== 完成 ======================
echo -e "\n============================================="
echo "✅ 部署完成！"
echo "🔐 使用公钥：${USE_KEY}"
echo "🔌 SSH 端口：$SSH_PORT"
echo "🚀 BBR 加速已开启"
echo "🛡️ 密码登录已关闭 | 仅密钥登录"
echo "============================================="

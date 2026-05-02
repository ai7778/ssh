#!/bin/bash
clear

echo "============================================="
echo " 服务器安全加固脚本（Ubuntu/Debian/CentOS/Alpine 通用）"
echo "============================================="
echo ""

read -p "请输入 SSH 端口 (1024-65535)：" SSH_PORT
echo ""

# 预设默认公钥地址
DEFAULT_PUBKEY="https://raw.githubusercontent.com/ai7778/ssh/main/key/flagstick_id_ed25519.pub"
read -p "请输入公钥RAW地址(直接回车使用默认公钥)：" PUBKEY_URL
[ -z "$PUBKEY_URL" ] && PUBKEY_URL="$DEFAULT_PUBKEY"

# 自动识别系统与包管理器
if command -v apt-get &> /dev/null; then
    OS="debian"
    PKG_UPDATE="apt-get update -yq"
    PKG_UPGRADE="apt-get upgrade -yq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
    PKG_INSTALL="apt install -yq"
    FIREWALL="ufw"
    SSH_SERVICE="sshd"
elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
    OS="centos"
    PKG_UPDATE="yum makecache -q"
    PKG_UPGRADE="yum update -yq"
    PKG_INSTALL="yum install -yq"
    FIREWALL="firewalld"
    SSH_SERVICE="sshd"
elif command -v apk &> /dev/null; then
    OS="alpine"
    PKG_UPDATE="apk update"
    PKG_UPGRADE="apk upgrade"
    PKG_INSTALL="apk add --no-cache"
    FIREWALL="iptables"
    SSH_SERVICE="sshd"
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
elif [ "$OS" = "centos" ]; then
    $PKG_INSTALL curl wget ca-certificates firewalld chrony
    systemctl enable --now chronyd
elif [ "$OS" = "alpine" ]; then
    $PKG_INSTALL curl wget ca-certificates openssh iptables
fi

# ====================== 时区 NTP ======================
echo -e "\n[4/9] 设置时区与时间同步..."
if [ "$OS" = "alpine" ]; then
    apk add --no-cache tzdata
    ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
    echo "America/Los_Angeles" > /etc/timezone
else
    timedatectl set-timezone America/Los_Angeles
    cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=time1.google.com time2.google.com time3.google.com time4.google.com
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable --now systemd-timesyncd >/dev/null 2>&1
fi

# ====================== BBR 加速 ======================
echo -e "\n[5/9] 开启 BBR 加速..."
if [ "$OS" != "alpine" ]; then
cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p >/dev/null 2>&1
else
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi

# ====================== 下载公钥 ======================
echo -e "\n[6/9] 下载公钥..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cd ~/.ssh
rm -f authorized_keys

wget --https-only -q -t 2 "$PUBKEY_URL" -O authorized_keys
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

# ====================== 防火墙适配 ======================
echo -e "\n[8/9] 配置防火墙..."
if [ "$FIREWALL" = "ufw" ]; then
    ufw allow "$SSH_PORT"/tcp >/dev/null 2>&1
    ufw delete allow 22/tcp >/dev/null 2>&1 || true
    ufw --force enable >/dev/null 2>&1
    ufw reload >/dev/null 2>&1
elif [ "$FIREWALL" = "firewalld" ]; then
    systemctl enable --now firewalld >/dev/null 2>&1
    firewall-cmd --permanent --add-port=$SSH_PORT/tcp
    firewall-cmd --permanent --remove-port=22/tcp 2>/dev/null
    firewall-cmd --reload
elif [ "$FIREWALL" = "iptables" ]; then
    iptables -F
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j DROP
    rc-update add iptables default
    /etc/init.d/iptables save
fi

# ====================== 重启 SSH ======================
echo -e "\n[9/9] 重启 SSH 服务..."
if [ "$OS" = "alpine" ]; then
    rc-service sshd restart >/dev/null 2>&1
else
    systemctl restart sshd 2>/dev/null || systemctl restart ssh
fi

# ====================== 完成 ======================
echo -e "\n============================================="
echo "✅ 部署完成！"
echo "🔗 使用公钥：$PUBKEY_URL"
echo "🔌 SSH 端口：$SSH_PORT"
echo "🚀 BBR 加速已开启"
echo "🛡️ 密码登录已关闭 | 仅密钥登录"
echo "============================================="

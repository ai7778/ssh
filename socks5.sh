#!/bin/bash
clear
echo "============================================="
echo "    四系统通用一键 SOCKS5 代理部署"
echo "    Ubuntu/Debian/CentOS/Alpine 通用"
echo "============================================="
echo ""

# 交互式配置
read -p "请输入 SOCKS5 端口(1024-65535)：" SOCK_PORT
read -p "请输入 SOCKS5 账号：" SOCK_USER
read -p "请输入 SOCKS5 密码：" SOCK_PASS

# 识别系统
if command -v apt-get &>/dev/null; then
    OS="deb"
    INSTALL="apt install -yq"
    SERVICE_CMD="systemctl"
elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
    OS="rpm"
    INSTALL="yum install -yq"
    SERVICE_CMD="systemctl"
elif command -v apk &>/dev/null; then
    OS="alpine"
    INSTALL="apk add --no-cache"
else
    echo "❌ 不支持当前系统"
    exit 1
fi

echo -e "\n[1/5] 安装 dante 服务..."
$INSTALL dante-server

# 写入配置
echo -e "\n[2/5] 生成 SOCKS5 配置文件..."
cat > /etc/danted.conf <<EOF
internal: 0.0.0.0 port $SOCK_PORT
external: eth0
method: username
user.privileged: root
user.unprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF

# 创建系统账号
echo -e "\n[3/5] 创建 SOCKS5 登录账号..."
if [ "$OS" = "alpine" ]; then
    adduser -D -s /sbin/nologin $SOCK_USER
    echo "$SOCK_USER:$SOCK_PASS" | chpasswd
else
    useradd -m -s /usr/sbin/nologin $SOCK_USER
    echo "$SOCK_USER:$SOCK_PASS" | chpasswd
fi

# 放行端口防火墙
echo -e "\n[4/5] 防火墙放行端口..."
if [ "$OS" = "deb" ]; then
    ufw allow $SOCK_PORT/tcp >/dev/null 2>&1
elif [ "$OS" = "rpm" ]; then
    firewall-cmd --permanent --add-port=$SOCK_PORT/tcp >/dev/null 2>&1
    firewall-cmd --reload
elif [ "$OS" = "alpine" ]; then
    iptables -A INPUT -p tcp --dport $SOCK_PORT -j ACCEPT
fi

# 启动开机自启
echo -e "\n[5/5] 启动服务并设置开机自启..."
if [ "$OS" = "alpine" ]; then
    rc-update add danted default
    rc-service danted restart
else
    $SERVICE_CMD enable danted
    $SERVICE_CMD restart danted
fi

echo -e "\n============================================="
echo "✅ SOCKS5 部署完成！"
echo "🔌 代理地址：服务器IP:$SOCK_PORT"
echo "👤 账号：$SOCK_USER"
echo "🔑 密码：$SOCK_PASS"
echo "============================================="

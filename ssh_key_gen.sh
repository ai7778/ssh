#!/bin/bash
clear
echo "============================================="
echo "  交互式ED25519密钥批量生成 · 全系统通用版"
echo "  自定义密钥对数 + 自定义密码12~30位"
echo "============================================="

# 固定配置
KEY_DIR="/root/ssh_ed25519_batch"
ZIP_NAME="ssh_keys_batch.zip"
PASS_FILE="password_list.txt"
DOWNLOAD_PORT=9096
BACKUP_PORT=8181
RETRY_COUNT=3
RETRY_INTERVAL=2
MIN_PASS_LEN=12
MAX_PASS_LEN=30

# ========== 交互式：输入密钥对数 ==========
echo -e "\n🔑 请输入要生成的密钥对数(正整数)："
read KEY_COUNT

while true; do
    if [[ $KEY_COUNT =~ ^[1-9][0-9]*$ ]]; then
        echo -e "✅ 确认生成 $KEY_COUNT 对密钥"
        break
    else
        echo -e "❌ 无效输入，请输入正整数！"
        echo -e "🔑 重新输入密钥对数："
        read KEY_COUNT
    fi
done

# ========== 交互式：输入密码位数 12~30 ==========
echo -e "\n🔒 请输入密码位数(12~30位)："
read PASS_LEN

while true; do
    if [[ $PASS_LEN =~ ^[0-9]+$ ]] && [ $PASS_LEN -ge $MIN_PASS_LEN ] && [ $PASS_LEN -le $MAX_PASS_LEN ]; then
        echo -e "✅ 确认密码位数 $PASS_LEN 位"
        break
    else
        echo -e "❌ 必须是12~30之间的数字！"
        echo -e "🔒 重新输入密码位数："
        read PASS_LEN
    fi
done

# ========== 系统识别 ==========
if [ -f /etc/debian_version ]; then
    OS="Debian/Ubuntu"
    PKG_UPDATE="apt update -yq"
    PKG_INSTALL="apt install -yq"
elif [ -f /etc/redhat-release ]; then
    OS="CentOS"
    PKG_UPDATE="yum update -y -q"
    PKG_INSTALL="yum install -y -q"
else
    echo "❌ 不支持当前系统"
    exit 1
fi
echo -e "\n[系统检测] 当前系统：$OS"

# ========== 清理包管理器锁定 ==========
if [ "$OS" = "Debian/Ubuntu" ]; then
    pkill -f apt dpkg 2>/dev/null
    rm -f /var/lib/dpkg/lock* /var/cache/apt/archives/lock 2>/dev/null
else
    pkill -f yum 2>/dev/null
    rm -f /var/run/yum.pid 2>/dev/null
fi

# ========== 安装依赖 ==========
echo -e "\n[1/4] 安装必备依赖..."
$PKG_UPDATE >/dev/null 2>&1

if [ "$OS" = "Debian/Ubuntu" ]; then
    $PKG_INSTALL zip openssl python3 net-tools >/dev/null 2>&1
    if ! command -v netstat &>/dev/null; then
        apt install -y net-tools >/dev/null 2>&1
    fi
else
    $PKG_INSTALL zip openssl python3 >/dev/null 2>&1
    if ! command -v netstat &>/dev/null; then
        yum install -y net-tools >/dev/null 2>&1
    fi
fi

# ========== 生成密钥+密码 ==========
echo -e "\n[2/4] 正在生成 $KEY_COUNT 对密钥，每对 $PASS_LEN 位密码..."
rm -rf $KEY_DIR
mkdir -p $KEY_DIR
CHARSET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#&*"

echo "SSH密钥密码对照表 共$KEY_COUNT对 密码长度:$PASS_LEN位" > $KEY_DIR/$PASS_FILE
echo "=============================================" >> $KEY_DIR/$PASS_FILE

for i in $(seq 1 $KEY_COUNT); do
    KEY_PASS=$(head /dev/urandom | tr -dc "$CHARSET" | head -c $PASS_LEN)
    ssh-keygen -t ed25519 -N "$KEY_PASS" -f $KEY_DIR/id_ed25519_$i -q
    echo "密钥$i | id_ed25519_$i | 密码:$KEY_PASS" >> $KEY_DIR/$PASS_FILE
done
echo -e "✅ 密钥及密码生成完成"

# ========== 打包 ==========
echo -e "\n[3/4] 打包文件中..."
zip -j $KEY_DIR/$ZIP_NAME $KEY_DIR/* >/dev/null 2>&1
if [ ! -f "$KEY_DIR/$ZIP_NAME" ]; then
    zip -j $KEY_DIR/$ZIP_NAME $KEY_DIR/* >/dev/null 2>&1
fi
echo -e "✅ 打包完成"

# ========== 启动下载服务 ==========
echo -e "\n[4/4] 启动下载服务(5分钟后自动关闭)..."
SERVER_IP=$(curl -s ifconfig.me)
[ -z "$SERVER_IP" ] && SERVER_IP="127.0.0.1"

cd $KEY_DIR

# 端口检测
if netstat -tuln 2>/dev/null | grep -q ":$DOWNLOAD_PORT "; then
    echo -e "⚠️  $DOWNLOAD_PORT 端口占用，切换备用端口 $BACKUP_PORT"
    CURRENT_PORT=$BACKUP_PORT
else
    CURRENT_PORT=$DOWNLOAD_PORT
fi

# 启动HTTP服务函数
start_http_server() {
    python3 -c "
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler
class ReuseAddrHTTPServer(HTTPServer):
    def server_bind(self):
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        super().server_bind()
server = ReuseAddrHTTPServer(('', $CURRENT_PORT), SimpleHTTPRequestHandler)
server.serve_forever()
    " >/dev/null 2>&1 &
    HTTP_PID=$!
    sleep 1
    if netstat -tuln 2>/dev/null | grep -q ":$CURRENT_PORT "; then
        return 0
    else
        kill -9 $HTTP_PID 2>/dev/null
        return 1
    fi
}

# 重试启动
RETRY=0
while [ $RETRY -lt $RETRY_COUNT ]; do
    if start_http_server; then
        break
    fi
    RETRY=$((RETRY+1))
    echo -e "⚠️  服务启动失败，重试 $RETRY/$RETRY_COUNT"
    sleep $RETRY_INTERVAL
done

if [ $RETRY -ge $RETRY_COUNT ]; then
    echo -e "❌ 下载服务启动失败，请用SCP/FTP手动下载"
    DOWNLOAD_URL="手动路径: $KEY_DIR/$ZIP_NAME"
else
    DOWNLOAD_URL="http://$SERVER_IP:$CURRENT_PORT/$ZIP_NAME"
fi

# 5分钟后自动关闭+清理
(
sleep 300
kill -9 $HTTP_PID 2>/dev/null
rm -rf $KEY_DIR
) &

# ========== 输出信息 ==========
echo -e "\n============================================="
echo "✅ 全部完成"
echo "📦 下载链接：$DOWNLOAD_URL"
echo "🔢 密钥对数：$KEY_COUNT 对"
echo "🔐 密码长度：$PASS_LEN 位"
echo "⏰ 链接5分钟后自动失效并清理文件"
echo "============================================="

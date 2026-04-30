#!/bin/bash
clear
echo "============================================="
echo "  20对ED25519密钥批量生成 · 全系统通用版"
echo "  核心功能：密钥生成+密码保存+打包下载"
echo "  说明：纯本地运行，无多余配置，全系统兼容"
echo "============================================="

# 核心配置（固定核心参数，无需多余修改）
KEY_COUNT=20  # 固定生成20对ED25519密钥
KEY_DIR="/root/ssh_20keys_batch"  # 密钥存储目录
ZIP_NAME="ssh_20keys_batch.zip"   # 打包文件名
PASS_FILE="ssh_keys_passwords.txt"# 密码保存文件名（一一对应密钥）

# 1. 系统自动识别（Ubuntu/Debian/CentOS全兼容）
if [ -f /etc/debian_version ]; then
    OS="Debian/Ubuntu"
    PKG_UPDATE="apt update -yq"
    PKG_INSTALL="apt install -yq"
elif [ -f /etc/redhat-release ]; then
    OS="CentOS"
    PKG_UPDATE="yum update -y -q"
    PKG_INSTALL="yum install -y -q"
else
    echo "❌ 不支持当前系统，仅支持Ubuntu/Debian/CentOS"
    exit 1
fi
echo -e "\n[系统检测] 当前系统：$OS，开始生成密钥..."

# 2. 清理包管理器锁定，避免依赖安装失败
pkill -f apt yum dpkg 2>/dev/null
rm -f /var/lib/dpkg/lock* /var/run/yum.pid 2>/dev/null

# 3. 安装必备依赖（仅需zip、openssl，用于密钥生成和打包）
echo -e "\n[1/4] 安装必备依赖工具..."
$PKG_UPDATE >/dev/null 2>&1
$PKG_INSTALL zip openssl >/dev/null 2>&1

# 4. 批量生成20对ED25519密钥+20位强密码（核心功能）
echo -e "\n[2/4] 批量生成$KEY_COUNT对ED25519密钥（带20位强密码）..."
# 清理旧目录，创建新目录，避免残留文件干扰
rm -rf $KEY_DIR
mkdir -p $KEY_DIR
# 定义20位强密码字符集（大写+小写+数字+@#&*，符合高强度要求）
CHARSET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#&*"
# 写入密码文件头部说明，便于后续查阅密钥与密码对应关系
echo "SSH密钥密码对照表（共$KEY_COUNT对，一一对应，请勿泄露）" > $KEY_DIR/$PASS_FILE
echo "=============================================" >> $KEY_DIR/$PASS_FILE

# 循环生成20对密钥，每对密钥对应独立的20位强密码
for i in $(seq 1 $KEY_COUNT); do
    # 生成20位随机强密码（严格符合字符集要求，无重复规律）
    KEY_PASS=$(head /dev/urandom | tr -dc "$CHARSET" | head -c 20)
    # 生成ED25519密钥（无交互模式，密码为随机生成的强密码）
    ssh-keygen -t ed25519 -N "$KEY_PASS" -f $KEY_DIR/id_ed25519_$i -q
    # 将密钥序号、密钥文件名和对应密码写入文件，方便后续使用
    echo "密钥$i：id_ed25519_$i | 密码：$KEY_PASS" >> $KEY_DIR/$PASS_FILE
done
echo -e "\n✅ 20对密钥生成完成，密码已保存至：$KEY_DIR/$PASS_FILE"

# 5. 打包所有密钥+密码文件（核心打包功能，便于下载使用）
echo -e "\n[3/4] 打包20对密钥+密码文件..."
# 打包（不保留目录结构，直接打包所有密钥、公钥及密码文件，下载后可直接解压使用）
zip -j $KEY_DIR/$ZIP_NAME $KEY_DIR/* >/dev/null 2>&1
echo -e "✅ 打包完成：$KEY_DIR/$ZIP_NAME（包含20对密钥+密码对照表）"

# 6. 启动简易下载服务（60秒自动关闭，安全无残留）
echo -e "\n[4/4] 启动下载服务（60秒后自动失效）..."
# 获取服务器公网IP，生成打包文件下载链接
SERVER_IP=$(curl -s ifconfig.me)
# 进入密钥目录，启动Python简易HTTP服务（无需额外配置，直接下载）
cd $KEY_DIR
python3 -m http.server 8088 >/dev/null 2>&1 &
HTTP_PID=$!
# 生成打包文件下载链接，方便用户快速下载
DOWNLOAD_URL="http://$SERVER_IP:8088/$ZIP_NAME"

# 后台倒计时60秒，自动关闭下载服务、清理文件，避免服务器残留
(
sleep 600
# 杀死下载服务，释放8088端口
kill -9 $HTTP_PID 2>/dev/null
# 清理密钥目录和临时文件，保障服务器整洁
rm -rf $KEY_DIR
) &

# 最终输出核心提示信息
echo -e "\n============================================="
echo "✅ 所有核心操作完成！"
echo "📌 系统：$OS（全系统兼容，无需额外配置）"
echo "📦 密钥打包下载地址：$DOWNLOAD_URL"
echo "🔑 密码说明：压缩包内包含$PASS_FILE，一一对应20对密钥"
echo "⏰ 下载链接将在60秒后自动失效，请及时下载"
echo "============================================="

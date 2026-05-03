#!/bin/bash

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 必须root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}请以 root / sudo 执行本脚本${NC}"
    exit 1
fi

CONF="/etc/fail2ban/jail.local"

# 检查配置文件
if [ ! -f "$CONF" ]; then
    echo -e "${RED}未找到 $CONF 请先安装配置fail2ban${NC}"
    exit 1
fi

echo -e "${GREEN}===== Fail2Ban SSH 防护端口交互式修改工具 =====${NC}"
echo "示例输入："
echo "  单个端口：22022"
echo "  多个端口：22022,22033,22044"
echo "----------------------------------------"
read -p "请输入新的防护端口: " PORT_STR

# 简单格式校验
if ! [[ $PORT_STR =~ ^[0-9]{1,5}(,[0-9]{1,5})*$ ]]; then
    echo -e "${RED}端口格式错误！只能是数字，多端口用逗号分隔${NC}"
    exit 1
fi

# 替换port行
sed -i "s/^port\s*=.*/port     = $PORT_STR/" "$CONF"

# 重启服务
systemctl restart fail2ban

echo -e "${GREEN}----------------------------------------${NC}"
echo -e "✅ 已成功设置防护端口：$PORT_STR"
echo -e "✅ 已重启 Fail2Ban 服务"
echo -e "${GREEN}----------------------------------------${NC}"
echo "当前SSH防护状态："
fail2ban-client status sshd

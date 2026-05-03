#!/bin/bash
# Fail2Ban 终极一体化工具箱 最终版
# 功能：安装配置 | 改端口 | 查解封IP | 全球黑名单 | 定时更新

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 权限校验
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}请使用 root / sudo 执行本脚本！${NC}"
    exit 1
fi

CONF="/etc/fail2ban/jail.local"
IPSET_NAME="global-blacklist"
BLACKLIST_DIR="/etc/fail2ban/blacklist"
mkdir -p $BLACKLIST_DIR

# 黑名单源
BLACK_SOURCES=(
"https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"
"https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset"
"https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_generator_lists/bad-ip-addresses.list"
)

# ==================== 菜单 ====================
main_menu(){
    clear
    echo -e "${GREEN}=============================================${NC}"
    echo "        Fail2Ban 安全防护终极工具箱"
    echo -e "${GREEN}=============================================${NC}"
    echo "1. 一键安装配置(2次错误 24h永久封禁)"
    echo "2. 修改SSH防护端口(单/多端口)"
    echo "3. 查看已封禁IP列表"
    echo "4. 手动解封指定IP"
    echo "5. 在线下载导入全球恶意IP黑名单"
    echo "6. 查看黑名单数量"
    echo "7. 清空IP黑名单"
    echo "8. 设置每天自动更新黑名单"
    echo "9. 查看Fail2Ban运行状态"
    echo "0. 退出"
    echo -e "${GREEN}=============================================${NC}"
    read -p "请输入选项 [0-9]: " opt
}

# ==================== 1 一键安装配置 ====================
install_f2b(){
    echo -e "${YELLOW}开始安装 Fail2Ban...${NC}"
    if grep -qi debian /etc/os-release; then
        apt update -y
        apt install -y fail2ban ipset curl wget
        LOGPATH="/var/log/auth.log"
    else
        yum install -y epel-release fail2ban ipset curl wget
        LOGPATH="/var/log/secure"
    fi

    # 写入配置：2次失败 24h 永久封禁
    cat > $CONF <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
bantime  = -1
findtime = 86400
maxretry = 2

[sshd]
enabled  = true
port     = 22
filter   = sshd
logpath  = $LOGPATH
EOF

    systemctl enable --now fail2ban
    echo -e "${GREEN}✅ 安装配置完成！规则：24小时内错误2次永久封禁${NC}"
    read -p "回车返回菜单..."
}

# ==================== 2 修改端口 ====================
change_port(){
    [ ! -f "$CONF" ] && echo -e "${RED}请先执行安装配置！${NC}" && read -p "回车返回..." && return
    echo "格式示例：单端口22022  | 多端口22022,22033"
    read -p "输入新防护端口: " pstr
    if ! [[ $pstr =~ ^[0-9]{1,5}(,[0-9]{1,5})*$ ]]; then
        echo -e "${RED}端口格式错误！${NC}"
        read -p "回车返回..."
        return
    fi
    sed -i "s/^port\s*=.*/port     = $pstr/" $CONF
    systemctl restart fail2ban
    echo -e "${GREEN}✅ 端口修改成功，已重启服务${NC}"
    read -p "回车返回菜单..."
}

# ==================== 3 查看封禁IP ====================
list_ban_ip(){
    echo -e "${YELLOW}已封禁IP列表：${NC}"
    fail2ban-client status sshd | grep -i banned
    echo -e "\n防火墙封禁详情："
    iptables -nL f2b-sshd 2>/dev/null | grep -v "Chain\|target\|prot"
    read -p "回车返回菜单..."
}

# ==================== 4 解封IP ====================
unban_single_ip(){
    read -p "输入要解封的IP: " ip
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        fail2ban-client set sshd unbanip $ip
        echo -e "${GREEN}✅ 已解封 $ip${NC}"
    else
        echo -e "${RED}IP格式错误${NC}"
    fi
    read -p "回车返回菜单..."
}

# ==================== 黑名单初始化 ====================
init_ipset(){
    if ! ipset list $IPSET_NAME &>/dev/null; then
        ipset create $IPSET_NAME hash:ip family inet
        iptables -I INPUT -m set --match-set $IPSET_NAME src -j DROP
    fi
}

# ==================== 5 下载导入黑名单 ====================
down_blacklist(){
    init_ipset
    tmpfile=$(mktemp)
    echo -e "${YELLOW}正在下载黑名单...${NC}"
    for url in "${BLACK_SOURCES[@]}"; do
        curl -s --connect-timeout 10 --max-time 30 "$url" >> $tmpfile
    done
    # 过滤合法IP去重
    grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' $tmpfile | sort -u > $BLACKLIST_DIR/global.ip.list
    rm -f $tmpfile
    cnt=$(wc -l < $BLACKLIST_DIR/global.ip.list)
    echo -e "${GREEN}✅ 下载完成，有效恶意IP：$cnt 个${NC}"

    echo -e "${YELLOW}导入ipset拦截...${NC}"
    while read ip; do
        ipset add $IPSET_NAME $ip -exist
    done < $BLACKLIST_DIR/global.ip.list
    echo -e "${GREEN}✅ 全部导入拦截成功${NC}"
    read -p "回车返回菜单..."
}

# ==================== 6 查看黑名单数量 ====================
show_black_count(){
    init_ipset
    cnt=$(ipset list $IPSET_NAME | wc -l)
    echo -e "${GREEN}当前黑名单IP总数：$cnt${NC}"
    read -p "回车返回菜单..."
}

# ==================== 7 清空黑名单 ====================
clear_black(){
    init_ipset
    ipset flush $IPSET_NAME
    echo -e "${GREEN}✅ 已清空所有黑名单IP${NC}"
    read -p "回车返回菜单..."
}

# ==================== 8 定时自动更新 ====================
add_cron_update(){
    cronfile="/etc/cron.d/f2b_blacklist"
    echo "0 3 * * * root $0 auto_update" > $cronfile
    echo -e "${GREEN}✅ 已设置每天凌晨3点自动更新黑名单${NC}"
    read -p "回车返回菜单..."
}

# 定时任务自动执行入口
if [ "$1" = "auto_update" ]; then
    init_ipset
    down_blacklist
    exit 0
fi

# ==================== 9 查看状态 ====================
show_status(){
    echo -e "${YELLOW}=== 全局状态 ===${NC}"
    fail2ban-client status
    echo -e "\n${YELLOW}=== SSHD防护状态 ===${NC}"
    fail2ban-client status sshd
    read -p "回车返回菜单..."
}

# ==================== 主循环 ====================
while true; do
    main_menu
    case $opt in
        1) install_f2b ;;
        2) change_port ;;
        3) list_ban_ip ;;
        4) unban_single_ip ;;
        5) down_blacklist ;;
        6) show_black_count ;;
        7) clear_black ;;
        8) add_cron_update ;;
        9) show_status ;;
        0) echo -e "${GREEN}已退出${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
done

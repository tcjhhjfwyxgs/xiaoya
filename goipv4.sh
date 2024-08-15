export LANG=zh_CN.UTF-8
#############################################功能说明###########################################################
# 本脚本为openwrt软路由系统写的，理论上也支持linux类型系统，自行研究。
# 本脚本为全自动下载CFST，优选CF官方IP，并挂载到域名，支持自定义IP文件路径，可以自定义非CF的IP，例如反代
# 脚本全明文带中文解说，请仔细查看解说根据自身环境需求修改后执行。
# 可在openwrt计划任务中添加定时，比如 0 4 * * * cd /root/CF && bash goip.sh 就是每天凌晨4点自动运行。
################################################################################################################
####################设置API代理网址 有时候国内API无法链接导致账号登陆失败或无法下载时使用#######################
# 代理网址建议用自己的，随时可能失效
DL="https://dl.houyitfg.icu/proxy/"
##################################################账号设置######################################################
# --cloudflare账号邮箱--
x_email=940689561@qq.com,密码=Xw10086@
#
# --Global API Key--
# --到你托管的域名--右下角“获取您的API令牌”--Global API Key查看
api_key=d1cae10dc3575edccd709e8cf4875280fb73d
#
# --挂载的完整域名，支持同账号下的多域名--
#	示例：("www.dfsgsdg.com" "www.wrewstdzs.cn")
hostnames=("yufeixia.us.kg" "xyf.dns-dynamic.net")
##################################################测速设置######################################################
# --运行模式--
#	选择优选ipv4还是ipv6
IP_ADDR=ipv4
#
# --IPV4测速文件路径--
#	默认路径"./CFST/ip.txt"，可自定义路径
TESTIPV4="./CFST/ip.txt"
#
# --IPV6测速文件路径--
#	默认路径"./CFST/ipv6.txt"，可自定义路径
TESTIPV6="./CFST/ipv6.txt"
#
# --测速结果文件路径，不需要改--
CSV_FILE="./CFST/result.csv"
#
# --测速地址--
#	建议使用自己的测速地址(https://xxx.xxxx.xxxxxx)，CM测速地址搭建教程https://github.com/cmliu/CF-Workers-SpeedTestURL
CFST_URL="https://cesu.houyitfg.dynv6.net"
#
# --测速地址端口--
#	指定测速端口；延迟测速/下载测速时使用的端口；(默认 443 端口)
CFST_TP=80
#
# --下载测速时间--
#	单个IP下载测速最长时间，不能太短；（默认 10 秒）
CFST_DT=5
#
# --测速线程数量--
#	越多测速越快，性能弱的设备 (如路由器) 请勿太高；(默认 200 最多 1000 )
CFST_N=800
#
# --延迟测速次数--
#	单个 IP 延迟测速次数，为 1 时将过滤丢包的IP，TCP协议；(默认 4 次 )
CFST_T=4
#
# --下载测速数量--
#	测速的数量，凑够测速结果才会结束测速，合理设置，同时也是自动挂载到域名的IP数，建议1-5个，反代域名建议只挂载1个IP
CFST_DN=5
#
# --平均延迟上限--
#	只输出低于指定平均延迟的 IP，可与其他上限/下限搭配；(默认9999 ms 这里推荐配置300 ms)
CFST_TL=600
#
# --平均延迟下限--
#	只输出高于指定平均延迟的 IP，可与其他上限/下限搭配、过滤假墙 IP；(默认 0 ms 这里推荐配置40)
CFST_TLL=10
#
# --丢包几率上限--
#	只输出低于/等于指定丢包率的 IP，范围 0.00~1.00，0 过滤掉任何丢包的 IP；(默认 1.00 推荐0.2)
CFST_TLR=0
#
# --下载速度下限--
#	只输出高于指定下载速度的 IP，凑够指定数量 [-dn] 才会停止测速；(默认 0.00 MB/s 这里推荐5.00MB/s)
CFST_SL=5
########################################检查是否关闭代理############################################
#----------------------------------openwrt科学上网插件配置------------------------------------------
# --优选节点时是否自动停止科学上网服务--
#	true=自动停止 false=不停止 默认为 true
pause=false
#
# --客户端代码--
#	填写openwrt使用的是哪个科学上网客户端，填写对应的“数字”  默认为 1  客户端为passwall
#	1=passwall 2=passwall2 3=ShadowSocksR Plus+ 4=clash 5=openclash 6=bypass
clien=6
#
# --延时执行--
#	填写重启科学上网服务后，需要等多少秒后才开始进行优选 单位：秒
#	根据自己的网络情况来填写 推荐 15
sleepTime=30
#
#读取配置文件中的客户端
case $clien in
  "6") CLIEN=bypass;;
  "5") CLIEN=openclash;;
  "4") CLIEN=clash;;
  "3") CLIEN=shadowsocksr;;
  "2") CLIEN=passwall2;;
  *) CLIEN=passwall;;
esac
# 判断是否停止科学上网服务
if [ "$pause" = "false" ] ; then
  echo "按要求未停止科学上网服务";
else
  /etc/init.d/$CLIEN stop;
  echo "已停止$CLIEN 等待${sleepTime}秒后开始优选";
  sleep ${sleepTime}s;
fi
#####################可能需要以下几个依赖，如果无法自动安装就手动自行安装########################
DEPENDENCIES=("curl" "bash" "jq" "wget" "unzip" "tar" "sed" "grep")
#################################################################################################
# 检测发行版及其包管理器
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    case $OS in
        "Ubuntu"|"Debian"|"Armbian")
            PKG_MANAGER="apt-get"
            UPDATE_CMD="apt-get update"
            INSTALL_CMD="apt-get install -y"
            CHECK_CMD="dpkg -s"
            ;;
        "CentOS"|"Red Hat Enterprise Linux")
            PKG_MANAGER="yum"
            UPDATE_CMD="yum update -y"
            INSTALL_CMD="yum install -y"
            CHECK_CMD="rpm -q"
            ;;
        "Fedora")
            PKG_MANAGER="dnf"
            UPDATE_CMD="dnf update -y"
            INSTALL_CMD="dnf install -y"
            CHECK_CMD="rpm -q"
            ;;
        "Arch Linux")
            PKG_MANAGER="pacman"
            UPDATE_CMD="pacman -Syu"
            INSTALL_CMD="pacman -S --noconfirm"
            CHECK_CMD="pacman -Qi"
            ;;
        "OpenWrt")
            PKG_MANAGER="opkg"
            UPDATE_CMD="opkg update"
            INSTALL_CMD="opkg install"
            CHECK_CMD="opkg list-installed"
            ;;
        *)
            echo "Unsupported Linux distribution: $OS"
            exit 1
            ;;
    esac
else
    echo "Cannot detect Linux distribution."
    exit 1
fi

# 更新包管理器数据库
echo "Updating package database..."
$UPDATE_CMD

# 函数：检测依赖项是否已安装
function is_installed {
    case $PKG_MANAGER in
        "apt-get")
            dpkg -s $1 &> /dev/null
            ;;
        "yum"|"dnf")
            rpm -q $1 &> /dev/null
            ;;
        "pacman")
            pacman -Qi $1 &> /dev/null
            ;;
        "opkg")
            opkg list-installed | grep $1 &> /dev/null
            ;;
        *)
            echo "Unsupported package manager: $PKG_MANAGER"
            exit 1
            ;;
    esac
    return $?
}

# 安装依赖项
for DEP in "${DEPENDENCIES[@]}"; do
    echo "Checking if $DEP is installed..."
    if is_installed $DEP; then
        echo "$DEP is already installed."
    else
        echo "Installing $DEP..."
        $INSTALL_CMD $DEP
    fi
done

# 检测CPU架构
CPU_ARCH=$(uname -m)
echo "CPU Architecture: $CPU_ARCH"

#CFST的下载地址，如果你的系统无法自动安装则自行去作者仓库查找并更换下载链接https://github.com/XIU2/CloudflareSpeedTest/releases
echo 检查CloudflareST是否安装
CloudflareST="./CFST/CloudflareST"
if [ ! -f ${CloudflareST} ]; then
	if [ -d "CFST" ]; then
	  # 目录存在，清空目录内容
	  rm -rf "CFST"/*
	  echo "目录已存在，已清空内容。"
	else
	  # 目录不存在，创建目录
	  mkdir "CFST"
	  echo "目录不存在，已新建目录。"
	fi
# 根据CPU架构执行特定操作
case $CPU_ARCH in
    "x86_64"|"amd64")
        URL="${DL}https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_amd64.tar.gz"
        wget -P ./CFST/tmp/ $URL
        tar -zxf ./CFST/tmp/CloudflareST_linux_*.tar.gz -C ./CFST/tmp/
        mv ./CFST/tmp/CloudflareST ./CFST/tmp/ip.txt ./CFST/tmp/ipv6.txt ./CFST/
        rm -rf ./CFST/tmp/
        ;;
    "i686"|"i386")
        URL="${DL}https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_386.tar.gz"
        wget -P ./CFST/tmp/ $URL
        tar -zxf ./CFST/tmp/CloudflareST_linux_*.tar.gz -C ./CFST/tmp/
        mv ./CFST/tmp/CloudflareST ./CFST/tmp/ip.txt ./CFST/tmp/ipv6.txt ./CFST/
        rm -rf ./CFST/tmp/
        ;;
    "armv7l"|"armhf")
        URL="${DL}https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_armv7.tar.gz"
        wget -P ./CFST/tmp/ $URL
        tar -zxf ./CFST/tmp/CloudflareST_linux_*.tar.gz -C ./CFST/tmp/
        mv ./CFST/tmp/CloudflareST ./CFST/tmp/ip.txt ./CFST/tmp/ipv6.txt ./CFST/
        rm -rf ./CFST/tmp/
        ;;
    "aarch64"|"arm64")
        URL="${DL}https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_arm64.tar.gz"
        wget -P ./CFST/tmp/ $URL
        tar -zxf ./CFST/tmp/CloudflareST_linux_*.tar.gz -C ./CFST/tmp/
        mv ./CFST/tmp/CloudflareST ./CFST/tmp/ip.txt ./CFST/tmp/ipv6.txt ./CFST/
        rm -rf ./CFST/tmp/
        ;;
    *)
        echo "无法识别你的系统架构，请自行到https://github.com/XIU2/CloudflareSpeedTest/releases下载对应依赖并解压到CFST目录"
        exit 1
        ;;
esac
fi

# 检测CloudflareST权限
if [[ ! -x ${CloudflareST} ]]; then
chmod +x $CloudflareST
fi
############################################检查登陆账号############################################
# 获取区域ID
get_zone_id() {
    local hostname=$1
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$(echo ${hostname} | cut -d "." -f 2-)" -H "X-Auth-Email: $x_email" -H "X-Auth-Key: $api_key" -H "Content-Type: application/json" | jq -r '.result[0].id'
}

# 获取并检查zone_id
for hostname in "${hostnames[@]}"; do
    ZONE_ID=$(get_zone_id "$hostname")

    if [ -z "$ZONE_ID" ]; then
        echo "账号登陆失败，域名: $hostname，检查账号信息和网络状态"
        exit 1;
    else
        echo "账号登陆成功，域名: $hostname"
    fi
done
############################################开始优选################################################
echo "开始ST优选主程序"
if [ "$IP_ADDR" = "ipv6" ] ; then
  #开始优选IPv6
  $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -tll $CFST_TLL -sl $CFST_SL -p $CFST_DN -tlr $CFST_TLR -f $TESTIPV6 -o $CSV_FILE
else
  #开始优选IPv4
  $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -tll $CFST_TLL -sl $CFST_SL -p $CFST_DN -tlr $CFST_TLR -f $TESTIPV4 -o $CSV_FILE
fi
echo "测速完毕";
# 删除多余条目，防止测速目标未达到导致所有IP都存入结果文件，导致挂载大量IP
SS=$((CFST_DN + 1)); sed -i "1,${SS}!d" $CSV_FILE
sed -i '1d; s/,.*//' $CSV_FILE

echo "开始更新DNS记录"
# 查询A和AAAA记录的函数
query_records() {
    local zone_id=$1
    local record_type=$2
    local hostname=$3
    curl -s \
        -H "X-Auth-Email: $x_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$hostname&per_page=100&order=type&direction=desc&match=all" |
        jq -r '.result[] | select(.proxied == false) | "\(.id) \(.name) \(.content)"'
}

# 删除记录的函数
delete_record() {
    local zone_id=$1
    local record_id=$2
    local record_name=$3
    local record_content=$4
    response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "X-Auth-Email: $x_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id")
    if [ "$response" -eq 200 ]; then
        echo "$record_name的DNS记录[$record_content]已成功删除"
    else
        echo "$record_name的DNS记录[$record_content]删除失败"
    fi
}

# 添加记录的函数
add_record() {
    local zone_id=$1
    local ip=$2
    local record_type=$3
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "X-Auth-Email: $x_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$record_type\",\"name\":\"$hostname\",\"content\":\"$ip\",\"ttl\":60,\"proxied\":false}" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records")
    if [ "$response" -eq 200 ]; then
        echo "$hostname的DNS记录[$ip]已成功添加"
    else
        echo "$hostname的DNS记录[$ip]添加失败"
    fi
}
# 删除域名DNS记录
for hostname in "${hostnames[@]}"; do
    ZONE_ID=$(get_zone_id "$hostname")
    for record_type in A AAAA; do
        echo "正在删除 $hostname 的 $record_type 记录..."
        query_records "$ZONE_ID" "$record_type" "$hostname" | while read -r record_id record_name record_content; do
            delete_record "$ZONE_ID" "$record_id" "$record_name" "$record_content"
        done
    done
done

# 同步更新到所有域名
for hostname in "${hostnames[@]}"; do
    ZONE_ID=$(get_zone_id "$hostname")
        while IFS= read -r ip
        do
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                record_type="A"
            elif [[ $ip =~ ^[0-9a-fA-F:]+$ ]]; then
                record_type="AAAA"
            fi
            add_record "$ZONE_ID" "$ip" "$record_type"
        done < "$CSV_FILE"
done
######################################打开代理##############################################
#判断是否重启科学服务
if [ "$pause" = "false" ] ; then
  echo "按要求未重启科学上网服务";
  sleep 1 > /dev/null
else
  /etc/init.d/$CLIEN restart;
  echo "已重启$CLIEN";
fi
echo "=======================优选完毕========================="
exit 0;
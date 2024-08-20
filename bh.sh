# 标准库
import os
import re
import random
import ipaddress
import subprocess
import concurrent.futures

# 第三方库
import requests
from lxml import etree
from fake_useragent import UserAgent
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# 文件配置
ips = "oldip.txt"
domains = "domain.txt"
dns_result = "dns_result.txt"


# 并发数配置
max_workers_request = 20   # 并发请求数量
max_workers_dns = 50       # 并发DNS查询数量

# 生成随机User-Agent
ua = UserAgent()

# 网站配置
sites_config = {
    "site_ip138": {
        "url": "https://site.ip138.com/",
        "xpath": '//ul[@id="list"]/li/a'
    },
    "dnsdblookup": {
        "url": "https://dnsdblookup.com/",
        "xpath": '//ul[@id="list"]/li/a'
    },
    "ipchaxun": {
        "url": "https://ipchaxun.com/",
        "xpath": '//div[@id="J_domain"]/p/a'
    }
}

# 设置会话
def setup_session():
    session = requests.Session()
    retries = Retry(total=5, backoff_factor=0.3, status_forcelist=[500, 502, 503, 504])
    adapter = HTTPAdapter(max_retries=retries)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    return session

# 生成请求头
def get_headers():
    return {
        'User-Agent': ua.random,
        'Accept': '*/*',
        'Connection': 'keep-alive',
    }

# 查询域名的函数，自动重试和切换网站
def fetch_domains_for_ip(ip_address, session, attempts=0, used_sites=None):
    print(f"Fetching domains for {ip_address}...")
    if used_sites is None:
        used_sites = []
    if attempts >= 3:  # 如果已经尝试了3次，终止重试
        return []

    # 选择一个未使用的网站进行查询
    available_sites = {key: value for key, value in sites_config.items() if key not in used_sites}
    if not available_sites:
        return []  # 如果所有网站都尝试过，返回空结果

    site_key = random.choice(list(available_sites.keys()))
    site_info = available_sites[site_key]
    used_sites.append(site_key)

    try:
        url = f"{site_info['url']}{ip_address}/"
        headers = get_headers()
        response = session.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        html_content = response.text

        parser = etree.HTMLParser()
        tree = etree.fromstring(html_content, parser)
        a_elements = tree.xpath(site_info['xpath'])
        domains = [a.text for a in a_elements if a.text]

        if domains:
            print(f"succeed to fetch domains for {ip_address} from {site_info['url']}")
            return domains
        else:
            raise Exception("No domains found")

    except Exception as e:
        print(f"Error fetching domains for {ip_address} from {site_info['url']}: {e}")
        return fetch_domains_for_ip(ip_address, session, attempts + 1, used_sites)

# 并发处理所有IP地址
def fetch_domains_concurrently(ip_addresses):
    session = setup_session()
    domains = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers_request) as executor:
        future_to_ip = {executor.submit(fetch_domains_for_ip, ip, session): ip for ip in ip_addresses}
        for future in concurrent.futures.as_completed(future_to_ip):
            domains.extend(future.result())

    return list(set(domains))

# DNS查询函数
def dns_lookup(domain):
    print(f"Performing DNS lookup for {domain}...")
    result = subprocess.run(["nslookup", domain], capture_output=True, text=True)
    return domain, result.stdout

# 通过域名列表获取绑定过的所有ip
def perform_dns_lookups(domain_filename, result_filename, unique_ipv4_filename):
    try:
        # 读取域名列表
        with open(domain_filename, 'r') as file:
            domains = file.read().splitlines()

        # 创建一个线程池并执行DNS查询
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers_dns) as executor:
            results = list(executor.map(dns_lookup, domains))

        # 写入查询结果到文件
        with open(result_filename, 'w') as output_file:
            for domain, output in results:
                output_file.write(output)

        # 从结果文件中提取所有IPv4地址
        ipv4_addresses = set()
        for _, output in results:
            ipv4_addresses.update(re.findall(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', output))

        with open(unique_ipv4_filename, 'r') as file:
            exist_list = {ip.strip() for ip in file}

        # 检查IP地址是否为公网IP
        filtered_ipv4_addresses = set()
        for ip in ipv4_addresses:
            try:
                ip_obj = ipaddress.ip_address(ip)
                if ip_obj.is_global:
                    filtered_ipv4_addresses.add(ip)
            except ValueError:
                # 忽略无效IP地址
                continue
  
        filtered_ipv4_addresses.update(exist_list)

        # 保存IPv4地址
        with open(unique_ipv4_filename, 'w') as output_file:
            for address in filtered_ipv4_addresses:
                output_file.write(address + '\n')

    except Exception as e:
        print(f"Error performing DNS lookups: {e}")

# 主函数
def main():
    # 判断是否存在IP文件
    if not os.path.exists(ips):
        with open(ips, 'w') as file:
            file.write("")
  
    # 判断是否存在域名文件
    if not os.path.exists(domains):
        with open(domains, 'w') as file:
            file.write("")

    # IP反查域名
    with open(ips, 'r') as ips_txt:
        ip_list = [ip.strip() for ip in ips_txt]

    domain_list = fetch_domains_concurrently(ip_list)
    print("域名列表为")
    print(domain_list)
    with open("Fission_domain.txt", "r") as file:
        exist_list = [domain.strip() for domain in file]

    domain_list = list(set(domain_list + exist_list))

    with open("Fission_domain.txt", "w") as output:
        for domain in domain_list:
            output.write(domain + "\n")
    print("IP -> 域名 已完成")

    # 域名解析IP
    perform_dns_lookups(domains, dns_result, ips)
    print("域名 -> IP 已完成")

# 程序入口
if __name__ == '__main__':
    main()
#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 脚本主目录
BASH_FILE="$SCRIPT_DIR/cdn"

# IP文件目录
IP_FILE="$SCRIPT_DIR/cdn/IP"

# 优选IP结果
RESULT="$SCRIPT_DIR/cdn/RESULT"

# 文件配置
ips="$SCRIPT_DIR/oldip.txt"            # 存储IP地址的文件

# 输出不同颜色的信息
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
grey(){
    echo -e "\033[36m\033[01m$1\033[0m"
}
purple(){
    echo -e "\033[35m\033[01m$1\033[0m"
}
greenbg(){
    echo -e "\033[43;42m\033[01m $1 \033[0m"
}
redbg(){
    echo -e "\033[37;41m\033[01m $1 \033[0m"
}
yellowbg(){
    echo -e "\033[33m\033[01m\033[05m[ $1 ]\033[0m"
}

# 获取BASH_FILE和IP_FILE所在的文件夹路径
get_FILE_info() {
    BASH_FILE="$SCRIPT_DIR/cdn"
    IP_FILE="$SCRIPT_DIR/cdn/IP"
    RESULT="$SCRIPT_DIR/cdn/RESULT"

    # 检查BASH_FILE和IP_FILE是否存在，不存在则创建
    if [ ! -d "$BASH_FILE" ]; then
        red "文件夹不存在，开始创建..."
        mkdir -p "$BASH_FILE"
        chmod -R 777 "$BASH_FILE"  # 赋予写入、读取、执行的所有权限
        purple "$BASH_FILE 文件夹创建完成。"
    else
        green "$BASH_FILE 文件夹已存在，跳过创建。"
    fi
  
    # 检查IP_FILE是否存在，不存在则创建
    if [ ! -d "$IP_FILE" ]; then
        red "文件夹不存在，开始创建..."
        mkdir -p "$IP_FILE"
        chmod -R 777 "$IP_FILE"  # 赋予写入、读取、执行的所有权限
        purple "$IP_FILE 文件夹创建完成。"
    else
        green "$IP_FILE 文件夹已存在，跳过创建。"
    fi

    # 检查RESULT是否存在，不存在则创建
    if [ ! -d "$RESULT" ]; then
        red "文件夹不存在，开始创建..."
        mkdir -p "$RESULT"
        chmod -R 777 "$RESULT"  # 赋予写入、读取、执行的所有权限
        purple "$RESULT 文件夹创建完成。"
    else
        green "$RESULT 文件夹已存在，跳过创建。"
    fi
}

# 检查依赖项是否存在，如果不存在则安装
check_dependencies() {
    dependencies=("curl" "unzip" "jq" "wget" "python-full" "dnsutils")

    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" &> /dev/null; then
            red "$dependency 未安装，尝试安装..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                if ! command -v brew &> /dev/null; then
                    yellow "正在安装 Homebrew..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                fi
                brew install "$dependency"
            elif [ -x "$(command -v apt-get)" ]; then
                # Ubuntu 或 Debian
                apt-get update
                apt-get install -y "$dependency"
            elif [ -x "$(command -v yum)" ]; then
                # CentOS 或 Fedora
                yum install -y "$dependency"
            elif [ -x "$(command -v apk)" ]; then
                # Alpine
                apk add "$dependency"
            else
                yellow "无法确定系统包管理器，无法安装 $dependency"
            fi
        else
            green "$dependency 已安装"
        fi
    done
}

# 删除IP文件
DEL_IP(){
# 删除旧的配置

find "$IP_FILE" -name "*.txt" -type f -exec rm -f {} \;

}

# 生成随机User-Agent
generate_user_agent() {
    # 定义一些常用的User-Agent字符串
    user_agents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15"
        "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:91.0) Gecko/20100101 Firefox/91.0"
        "Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Mobile Safari/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    )
    # 随机选择一个User-Agent
    ua=${user_agents[$RANDOM % ${#user_agents[@]}]}
}


# 检查IP和端口是否反代了Cloudflare CDN
check_ip_port_cdn() {
    local ip="$1"
    local port="$2"
    local url="http://$ip:$port/cdn-cgi/trace"

    generate_user_agent  # 生成随机User-Agent

    # 发起请求，并设置超时时间为1.5秒
    response=$(curl -s -A "$ua" --max-time 1.5 "$url")

    # 检查请求是否成功且返回包含Cloudflare相关信息
    if [[ $? -eq 0 && "$response" =~ "cloudflare" ]]; then
        echo "$ip" >> "$IP_FILE/newip.txt"
        echo "$ip" >> "$IP_FILE/${port}.txt"
        blue "$ip:$port 是通过Cloudflare反代的"
    else
        red "$ip:$port 不是Cloudflare反代或超时"
    fi
}

# 处理所有IP和端口
check_all_ips_ports() {

    local ports=("443" "2053" "2083" "2087" "2096" "8443")
    while IFS= read -r ip; do
        for port in "${ports[@]}"; do
            check_ip_port_cdn "$ip" "$port" &
        done
        wait  # 等待所有后台任务完成
    done < "$ips"
}

# 合并IP文件
merge_IP(){
sort "$IP_FILE/newip.txt" | uniq > "$IP_FILE/ip.txt"

grey "合并去重完成，结果保存在 $IP_FILE/ip.txt "

}


# 主函数
main() {
    # 获取BASH_FILE和IP_FILE所在的文件夹路径
    get_FILE_info

    # 检查依赖项是否存在，如果不存在则安装
    check_dependencies

    # 删除IP文件
    DEL_IP

    # 检查IP和端口是否反代了Cloudflare
    check_all_ips_ports

    # 合并IP文件
    merge_IP
}

# 调用主函数
main

#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 脚本运行时间 # 凌晨1点 3点 早5
jobtime="0 1,3,5 * * *" 

# 设置变量
# Cloudflare 设置

# Cloudflare Global API Key
API_KEY="d1cae10dc3575edccd709e8cf4875280fb73d"
# 用于 Cloudflare 账户的邮箱地址
EMAIL="940689561@qq.com"
# 主域名Zone ID
zone_id="bc2e76dcf234dd31dbdd0447e8a13c60"
# 是否开启小云朵（值：false 和 true）
PROXIED="false"

# 主域名地址
domain="yufeixia.us.kg" 

# 443更新的域名地址
RECORD_NAME="yufeixia.us.kg"

# 设置变量
# 基础 设置

# 日志文件位置
LOG_FILE="$SCRIPT_DIR/cdn/surgelog.txt"
# CloudflareST主程序文件
CloudflareST_FILE="$SCRIPT_DIR/cdn/CloudflareST"
# CloudflareST下载地址
CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_amd64.tar.gz"
# CloudflareST主程序压缩包位置
DownLoad_File="$SCRIPT_DIR/cdn/CloudflareST.tar.gz"

# 脚本主目录
BASH_FILE="$SCRIPT_DIR/cdn"

# IP文件目录
IP_FILE="$SCRIPT_DIR/cdn/IP"

# 优选IP结果
RESULT="$SCRIPT_DIR/cdn/RESULT"

# 声明一个包含唯一端口号的数组
ports=("443" "2053" "2083" "2087" "2096" "8443")

# 提供测速地址
TEST="https://cf.xiu2.xyz/Github/CloudflareSpeedTest.png"
#TEST="https://cdn.cloudflare.steamstatic.com/steam/apps/256843155/movie_max.mp4"
#TEST="https://cdn.cloudflare.steamstatic.com/steam/apps/257034980/movie_max.mp4"
#TEST="https://speed.cloudflare.com/__down?bytes=200000000"

# 记录日志
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# 输出不同颜色的信息
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
grey(){
    echo -e "\033[36m\033[01m$1\033[0m"
}
purple(){
    echo -e "\033[35m\033[01m$1\033[0m"
}
greenbg(){
    echo -e "\033[43;42m\033[01m $1 \033[0m"
}
redbg(){
    echo -e "\033[37;41m\033[01m $1 \033[0m"
}
yellowbg(){
    echo -e "\033[33m\033[01m\033[05m[ $1 ]\033[0m"
}


# 获取BASH_FILE和IP_FILE所在的文件夹路径
get_FILE_info() {
    BASH_FILE="$SCRIPT_DIR/cdn"
    IP_FILE="$SCRIPT_DIR/cdn/IP"
    RESULT="$SCRIPT_DIR/cdn/RESULT"

    # 检查BASH_FILE和IP_FILE是否存在，不存在则创建
    if [ ! -d "$BASH_FILE" ]; then
        red "文件夹不存在，开始创建..."
        mkdir -p "$BASH_FILE"
        chmod -R 777 "$BASH_FILE"  # 赋予写入、读取、执行的所有权限
        purple "$BASH_FILE 文件夹创建完成。"
    else
        green "$BASH_FILE 文件夹已存在，跳过创建。"
    fi
  
    # 检查IP_FILE是否存在，不存在则创建
    if [ ! -d "$IP_FILE" ]; then
        red "文件夹不存在，开始创建..."
        mkdir -p "$IP_FILE"
        chmod -R 777 "$IP_FILE"  # 赋予写入、读取、执行的所有权限
        purple "$IP_FILE 文件夹创建完成。"
    else
        green "$IP_FILE 文件夹已存在，跳过创建。"
    fi

    # 检查RESULT是否存在，不存在则创建
    if [ ! -d "$RESULT" ]; then
        red "文件夹不存在，开始创建..."
        mkdir -p "$RESULT"
        chmod -R 777 "$RESULT"  # 赋予写入、读取、执行的所有权限
        purple "$RESULT 文件夹创建完成。"
    else
        green "$RESULT 文件夹已存在，跳过创建。"
    fi
}

# 检查依赖项是否存在，如果不存在则安装
check_dependencies() {
    dependencies=("curl" "unzip" "jq" "wget" "python-full" "dnsutils")

    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" &> /dev/null; then
            red "$dependency 未安装，尝试安装..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                if ! command -v brew &> /dev/null; then
                    yellow "正在安装 Homebrew..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                fi
                brew install "$dependency"
            elif [ -x "$(command -v apt-get)" ]; then
                # Ubuntu 或 Debian
                apt-get update
                apt-get install -y "$dependency"
            elif [ -x "$(command -v yum)" ]; then
                # CentOS 或 Fedora
                yum install -y "$dependency"
            elif [ -x "$(command -v apk)" ]; then
                # Alpine
                apk add "$dependency"
            else
                yellow "无法确定系统包管理器，无法安装 $dependency"
            fi
        else
            green "$dependency 已安装"
        fi
    done
}

# 根据系统类型和架构设置下载链接
set_cloudflarest_url() {
    local os_type=$(uname -s)
    local arch=$(uname -m)

    case "$os_type" in
        Linux)
            case "$arch" in
                x86_64)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_amd64.tar.gz"
                    ;;
                i686 | i386)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_386.tar.gz"
                    ;;
                aarch64)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_arm64.tar.gz"
                    ;;
                armv5*)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_armv5.tar.gz"
                    ;;
                armv6*)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_armv6.tar.gz"
                    ;;
                armv7*)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_armv7.tar.gz"
                    ;;
                mips)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_mips.tar.gz"
                    ;;
                mips64)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_mips64.tar.gz"
                    ;;
                mipsle)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_mipsle.tar.gz"
                    ;;
                mips64le)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_mips64le.tar.gz"
                    ;;
                *)
                    redbg "不支持的 Linux 架构: $arch"
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_darwin_amd64.zip"
                    ;;
                arm64)
                    CLOUDFLAREST_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_darwin_arm64.zip"
                    ;;
                *)
                    redbg "不支持的 MacOS 架构: $arch"
                    exit 1
                    ;;
            esac
            ;;
        *)
            redbg "不支持的操作系统: $os_type"
            exit 1
            ;;
    esac
}

# 检查 CloudflareST 主程序是否存在且给予权限
download_cloudflarest() {
    if [ ! -f "$CloudflareST_FILE" ]; then
        green "CloudflareST 不存在，开始下载..."

        if wget --timeout=30 -O "$DownLoad_File" "$CLOUDFLAREST_URL"; then
            grey "CloudflareST 下载完成。"
        else
            red "下载 CloudflareST 文件超时！请检查网络连接并重试。"
            exit 1
        fi

        if [ -f "$DownLoad_File" ]; then
            if [[ "$CLOUDFLAREST_URL" == *.zip ]]; then
                unzip -d "$SCRIPT_DIR/cdn" "$DownLoad_File"
            else
                tar -xzf "$DownLoad_File" -C "$SCRIPT_DIR/cdn" CloudflareST
            fi

            rm "$DownLoad_File"
            chmod +x "$CloudflareST_FILE"
            grey "CloudflareST 解压并赋予执行权限完成。"
        else
            red "无可用的 CloudflareST 压缩包。"
            exit 1
        fi
    else
        blue "CloudflareST 已存在，跳过下载。"
    fi
}



# 运行 CloudflareST 工具进行 IP 优选
run_cloudflarest() {
        for port in "${ports[@]}"; do
        blue "================================= 优选端口 $port ================================="
        $CloudflareST_FILE -n 1000 -dn 10 -dt 20 -t 10 -tll 10 -tl 100 -sl 25 -tp "$port" -url "$TEST" -f "$IP_FILE/ip.txt" -o "$RESULT/$port.csv" /dev/null
        grey "端口 $port 优选完成，结果保存在 $RESULT/$port.csv"


        local record_name
        [ "$port" == "443" ] && record_name="$RECORD_NAME" || record_name="${port}.${domain}"
  

        RESULT_CSV="$RESULT/$port.csv"
        # 获取当前优选 IP 地址
        CURRENT_IP=$(sed -n '2p' "$RESULT_CSV" | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -wv 255)

        # 域名 TTL值（1，为自动，按秒计算，常用设置为300秒）
        if [ "$PROXIED" = "true" ]; then
            TTL="1"
        else
            TTL="60"
        fi
  

        green "获取 $port 端口 的优选 IP为： $CURRENT_IP "
  
        # 获取记录 ID
        RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$record_name" \
             -H "X-Auth-Email: $EMAIL" \
             -H "X-Auth-Key: $API_KEY" \
             -H "Content-Type: application/json" | grep -Eo '"id":"[a-zA-Z0-9]{32}"' | grep -o '[a-zA-Z0-9]\{32\}')

        green "获取记录$record_name ID为： $RECORD_ID "   

        # 更新 DNS 记录
        UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$RECORD_ID" \
             -H "X-Auth-Email: $EMAIL" \
             -H "X-Auth-Key: $API_KEY" \
             -H "Content-Type: application/json" \
             --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$CURRENT_IP\",\"ttl\":$TTL,\"proxied\":$PROXIED,\"comment\":\"$port\"}")


        # 检查是否成功
        if [[ $UPDATE_RESULT == *"\"success\":true"* ]]; then
            log "DNS 更新成功: $record_name -> $CURRENT_IP"
            green "DNS记录已更新。新IP地址:$CURRENT_IP"
        else
            red "DNS记录更新失败"
        fi
done
}



# 函数：记录日志
log_info() {
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    purple "[$current_time] $1" >> "$LOG_FILE"

    # 自动添加到 Cron 任务
    CRON_JOB="$jobtime $SCRIPT_DIR/$(basename "$0") >> \"$LOG_FILE\" 2>&1"
    (crontab -l 2>/dev/null | grep -Fq "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    # 检查 Cron 任务
    if crontab -l | grep -Fq "$SCRIPT_DIR/$(basename "$0")"; then
        green "Cron 任务已存在并已更新。"
    else
        red "Cron 任务不存在，尝试添加失败。"
    fi
}

# 函数：格式化输出（居中对齐）
format_output() {
    local header1="$1"
    local header2="$2"
    local header3="$3"
    local header4="$4"
  
    local width1=16
    local width2=14
    local width3=16
    local width4=12
  
    # 打印表头（居中对齐）
    printf "%${width1}s %${width2}s %${width3}s %${width4}s\n" \
           "$(printf "%*s" $(((${width1} + ${#header1}) / 2)) "$header1")" \
           "$(printf "%*s" $(((${width2} + ${#header2}) / 2)) "$header2")" \
           "$(printf "%*s" $(((${width3} + ${#header3}) / 2)) "$header3")" \
           "$(printf "%*s" $(((${width4} + ${#header4}) / 2)) "$header4")"
}

# 函数：打印数据行（居中对齐）
print_row() {
    local ip="$1"
    local port="$2"
    local speed="$3"
    local time="$4"
  
    local width1=16
    local width2=10
    local width3=12
    local width4=12
  
    # 打印数据行（居中对齐）
    printf "%${width1}s %${width2}s %${width3}s %${width4}s\n" \
           "$(printf "%*s" $(((${width1} + ${#ip}) / 2)) "$ip")" \
           "$(printf "%*s" $(((${width2} + ${#port}) / 2)) "$port")" \
           "$(printf "%*s" $(((${width3} + ${#speed}) / 2)) "$speed")" \
           "$(printf "%*s" $(((${width4} + ${#time}) / 2)) "$time")"
}

# 提取优选IP信息并输出表格
IP_INFO() {
    # 打开文件描述符3，用于同时写入文件和终端
    exec 3>&1 1> >(tee "$RESULT/ip_info.txt") 2>&1

    # 输出表头
    format_output "优选IP" "端口" "速度Mb/s" "延迟ms"

    for port in "${ports[@]}"; do
        RESULT_CSV="$RESULT/$port.csv"

        # 确保 CSV 文件存在
        if [ ! -f "$RESULT_CSV" ]; then
            print_row "N/A" "$port" "N/A" "N/A"
            continue
        fi

        # 获取优选的IP地址
        IP=$(sed -n '2p' "$RESULT_CSV" | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}")

        # 提取优选IP网速
        speed=$(cut -d , -f 6 "$RESULT_CSV" | sed -n 2p)

        # 提取优选IP延时
        time=$(cut -d , -f 5 "$RESULT_CSV" | sed -n 2p)

        # 输出结果
        print_row "$IP" "$port" "$speed" "$time"
    done

    # 关闭文件描述符3
    exec 1>&3 3>&-
}

# 主函数
main(){
    # 记录开始时间
    log_info "脚本开始执行"

    # 获取BASH_FILE和IP_FILE所在的文件夹路径
    get_FILE_info

    # 检查依赖项是否存在，如果不存在则安装
    check_dependencies

    # 根据系统类型和架构设置下载链接
    set_cloudflarest_url

    # 检查 CloudflareST 主程序是否存在且给予权限
    download_cloudflarest

    # 运行 CloudflareST 工具进行 IP 优选并推送优选 IP 信息到域名
    run_cloudflarest

    # 函数：提取优选IP信息
    IP_INFO

    # 记录结束时间
    log_info "脚本执行结束"
}

main


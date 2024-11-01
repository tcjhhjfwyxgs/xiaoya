#!/bin/bash

LOG_FILE="upgrade.log"
TEMP_LOG_FILE="temp_upgrade.log"
PIPE_FILE="log_pipe"
CLIENT_LOG_FILE="log_r_client.log"

# 创建命名管道
mkfifo ${PIPE_FILE}
tee -a ${LOG_FILE} < ${PIPE_FILE} &
exec >${PIPE_FILE} 2>&1

# 清理管道文件
trap "rm -f ${PIPE_FILE} ${TEMP_LOG_FILE} ${LOG_FILE}" EXIT

echo
echo
echo -e "\033[32m-----------------------------------使用说明------------------------------------\033[0m"
echo ""
echo -e "     \033[32m 请保证你执行下载的目录和你准备启动脚本的目录为同一个目录\033[0m"
echo ""
echo -e "     \033[32m bash sh_client_bot.sh     （启动客户端） \033[0m"
echo ""
echo -e "     \033[32m tail -f log_r_client.log  （实时查看日志,ctrl+c退出日志）\033[0m"
echo ""
echo -e "     \033[32m pgrep -f r_client | xargs -r kill -9 (终止进程)\033[0m"
echo ""
echo -e "     \033[32m bash sh_client_bot.sh 8888 可更换默认9527为8888端口 \033[0m"
echo ""
echo -e "     \033[32m https://t.me/radiance_helper_bot  /help 获取使用帮助 \033[0m"
echo ""
echo -e "     \033[32m 使用本脚本证明您已阅读并同意github上的相关协议，请知悉 \033[0m"
echo ""
echo -e "\033[32m-----------------------------------使用说明------------------------------------\033[0m"
echo
echo

# 获取系统架构
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
  DOWNLOAD_URL="https://github.com/semicons/java_oci_manage/releases/latest/download/gz_client_bot_aarch.tar.gz"
elif [[ "$ARCH" == "x86_64" ]]; then
  # 获取 CPU 特性
  cpu_flags=$(lscpu | grep Flags | awk '{for (i=2; i<=NF; i++) print $i}')

  # 定义需要的高级特性
  required_flags="avx avx2 sse4_2"

  # 检查 CPU 是否支持所有高级特性
  supports_advanced_features=true
  for flag in $required_flags; do
    if [[ ! "$cpu_flags" == *"$flag"* ]]; then
      supports_advanced_features=false
      break
    fi
  done

  # 下载相应的包
  if [ "$supports_advanced_features" = true ]; then
    DOWNLOAD_URL="https://github.com/semicons/java_oci_manage/releases/latest/download/gz_client_bot_x86.tar.gz"
  else
    DOWNLOAD_URL="https://github.com/semicons/java_oci_manage/releases/latest/download/gz_client_bot_x86_compatible.tar.gz"
  fi
else
  echo "不支持的架构: $ARCH"
  exit 1
fi

# 检查是否传递了 upgrade 参数或者初次下载
if [ ! -f "r_client" ] || { [ -n "$2" ] && [ "$2" == "upgrade" ]; }; then
  echo "下载文件包..."
  wget -q --no-check-certificate -O gz_client_bot.tar.gz $DOWNLOAD_URL
  if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连接或下载 URL。"
    exit 1
  fi
  tar -zxvf gz_client_bot.tar.gz --exclude=client_config
  tar -zxvf gz_client_bot.tar.gz --skip-old-files client_config
  chmod +x r_client
  chmod +x sh_client_bot.sh
  echo "下载完毕"
fi

# 删除旧的可执行文件
if [ -f "r_client.jar" ];then
  pgrep -f r_client.jar | xargs -r kill -9
  rm r_client.jar
fi

# 杀掉进程
pgrep -f r_client | xargs -r kill -9


# 启动新的 r_client 进程
if [ -z "$1" ];then
  nohup ./r_client --configPath=client_config >${TEMP_LOG_FILE} 2>&1 &
else
  nohup ./r_client --server.port="$1" --configPath=client_config >${TEMP_LOG_FILE} 2>&1 &
fi

# 检查日志文件是否存在，如果不存在则创建一个空文件
if [ ! -f "${CLIENT_LOG_FILE}" ];then
  touch ${CLIENT_LOG_FILE}
fi

echo "即将查看日志,请稍后(按【ctrl+c】可退出日志)"
tail -f ${CLIENT_LOG_FILE}


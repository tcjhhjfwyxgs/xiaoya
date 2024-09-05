#!/bin/bash

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }

USERNAME=$(whoami)
HOSTNAME=$(hostname)

run_nezha(){


 if pgrep -x "dashboard" > /dev/null 
 then
   green "nezha dashboard  still runing……"
 else
   yellow "nezha dashboard  has stopped,starting dashboard now!!"
   nohup /home/${USERNAME}/.nezha-dashboard/start.sh >/dev/null 2>&1 &
   sleep 2
 fi

 DASHBOARD_PID=$(pgrep -x "dashboard")
 echo "nezha pid=$DASHBOARD_PID"
 purple "nezha dashboard running done!"
 
}


#主菜单
menu() {
  clear
  green "哪吒面板保活脚本执行开始……"
  run_nezha
  green "哪吒面板保活脚本执行完成!"
}
menu
export LANG=zh_CN.UTF-8
# 功能，验证TXT文件，验证真反代和纯净IP，识别落地地区
# 验证速度，单位秒，网络不好可以适当增加数值1-5左右比较合理
speed="1"
# 识别后的结果文件夹名称
FILEPATH="FDIP"
# 验证的文件名
temp_file="cffdip.txt"
#####################################################################################################
rm -rf "$FILEPATH"
sleep 1 > /dev/null
mkdir "$FILEPATH"
mkdir "$FILEPATH/C"
# 读取IP去重
awk '{ sub(/,.*/, ""); if ($0 ~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) { split($0, octets, "."); if (octets[1] < 256 && octets[2] < 256 && octets[3] < 256 && octets[4] < 256 && !seen[$0]++) print $0 } }' $temp_file > temp.txt && mv temp.txt $temp_file
#######################################验证反代IP及纯净度###########################################
FDIP="$FILEPATH/FDIP.txt"
FDIPC="$FILEPATH/FDIPC.txt"
> $FDIP
> $FDIPC
echo ========================验证反代IP及纯净度，保留纯净IP===========================
while IFS= read -r ip; do
urlinfo=$(curl -i -s --connect-timeout ${speed} --max-time ${speed} "http://$ip/cdn-cgi/trace")
sleep 1 > /dev/null
# 第一步特征，是否正常进入检查页面
if echo "${urlinfo}" | grep -q "h=$ip"; then
    # 第二步特征，剔除国内的，这时候基本已经是反代了
    if ! echo "${urlinfo}" | grep -q "loc=CN"; then
        WEBPAGE=$(curl -i -s --connect-timeout 5 --max-time 5 "https://scamalytics.com/ip/$ip")
        if echo "$WEBPAGE" | grep -A 1 '<th>Server</th>' | grep -q 'risk yes'; then #进一步验证反代服务
        if ! echo "$WEBPAGE" | grep -A 1 'Anonymizing VPN' | grep -q 'risk yes'; then #这是验证IP是否是VPN，如果是则丢弃此IP
        # 第三步特征，验证反代+反代
        if echo "${urlinfo}" | grep -q "ip=$ip"; then #验证IP是否是中转IP，如果是则丢弃此IP
            DQ=$(echo "${urlinfo}" | awk -F'loc=' '/loc=/ {print $2}') #这是大概识别落地地区的
            echo "$ip" >> "${FDIP}"
            echo "$ip" >> "$FILEPATH/${DQ}.txt"
            echo "得到一个反代IP[$ip]，落地地区是[${DQ}]"
                if echo "$WEBPAGE" | grep -q '"risk":"low"'; then
                    echo "$ip" >> "${FDIPC}"
                    echo "$ip" >> "$FILEPATH/C/${DQ}.txt"
                    echo "此反代IP纯净[$ip]，落地地区是[${DQ}]"
                fi
        else
        echo "[$ip]是中转IP，不一定适合反代，保留在[中转IP.txt]，备用"
        echo "$ip,${DQ}" >> "$FILEPATH/中转IP.txt"
        fi
        else
        echo "[$ip]是VPN，不适合反代，丢弃"
        fi
        fi
    fi
else
echo "[$ip]不通或不是反代IP"
fi
done < "$temp_file"

echo "IP验证完毕，结果已储存在${FILEPATH}文件夹中，纯净IP文件夹为C，未识别前的文件为FDIPtemp.txt"
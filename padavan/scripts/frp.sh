#!/bin/sh
frps_stop ()
{
	killall frps
	logger -t "frp" "已停止FRPS"
}

frps_start()
{
	#创建服务端配置文件
	cat > "/tmp/frps.ini" <<-\EOF
	# ==========服务端配置：==========
	[common]
	bind_port = 5443
	dashboard_port = 
	dashboard_user = 
	dashboard_pwd = 
	token = 
	max_pool_count = 100
	# ====================
	EOF
	if [ ! -f "/tmp/frps" ];then
		logger -t "frp" "正在下载FRPS..."
		curl -k -s -o /tmp/frps --connect-timeout 10 --retry 3 https://cdn.jsdelivr.net/gh/Junec/CDN/padavan/frps
		chmod 777 /tmp/frps
	fi

	/tmp/frps -c /tmp/frps.ini 2>&1 &
	logger -t "frp" "FRPS启动成功"
}

case $1 in
frps_start)
	frps_start
	;;
frps_stop)
	frps_stop
	;;
frps_restart)
	frps_stop
	frps_start
	;;
*)
    echo "check"
    #exit 0
    ;;
esac
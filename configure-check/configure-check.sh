#!/bin/bash
g_current_dir=$(pwd)
g_log_file=${g_current_dir}/log-$(date "+%F-%H-%M-%S")

function green() 
{ 
	echo -e "\033[1;32m$1\033[0m" 
}

function red() 
{ 
	echo -e "\033[1;31m$1\033[0m" 
}

function pink() 
{ 
	echo -e "\033[1;35m$1\033[0m" 
}

function log()
{
	local state=$1
	local item=$2
	local str=$3
	local log_path=$(dirname ${g_log_file})

	case $state in
	    OK)
		    message="$(date +'%F %H:%M:%S') [$(green '  OK  ')] [$(pink ${item})] ${str}" ;;
		FAILED)
		    message="$(date +'%F %H:%M:%S') [$(red 'FAILED')] [$(pink ${item})] ${str}" ;;
		INFO)
		    message="$(date +'%F %H:%M:%S') [$(green ' INFO ')] [$(pink ${item})] ${str}" ;;
	esac

	if [ ! -d ${log_path} ]; then
	    mkdir -p ${log_path}
		chmod 700 ${log_path}
	fi
	echo -e "${message}" | tee -a "${g_log_file}" | fold -s -w 120

	chmod 600 ${g_log_file}
}

function add_space()
{
	echo "$1" | sed -e 's/^/                             /g'
}

function check_rpm()
{
	local rpm_name=$1
	#local rpm_version="$(rpm -qa | grep "^${rpm_name}" | sed -e 's/^/                             /g')"
	local rpm_version="$(rpm -qa | grep "^${rpm_name}")"

	if [ -n "${rpm_version}" ]; then
		rpm_version="$(add_space "${rpm_version}")"
		log OK "$FUNCNAME" "Installed package(s):\n${rpm_version}"
	else
		log FAILED "$FUNCNAME" "Package $(red ${rpm_name}) not installed"
	fi
}

function check_rpms()
{
	local rpms_name=$1

	for pkg in ${rpms_name}; do
		check_rpm ${pkg}
	done
}

function check_ipv6_state()
{
	local is_disabled="$(grep -irn "ipv6.*disable" /etc/sysctl.d/ /etc/sysctl.conf /boot/grub2/grub.cfg /boot/efi/EFI/euleros/grub.cfg 2>/dev/null)"

	if [ -n "${is_disabled}" ]; then
		is_disabled="$(add_space "${is_disabled}")"
		log FAILED "$FUNCNAME" "IPV6 is disabled in follow files:\n${is_disabled}"
	else
		is_disabled="$(ip addr | grep inet6)"
		if [ -n "${is_disabled}" ]; then
			is_disabled="$(add_space "${is_disabled}")"
			log OK "$FUNCNAME" "IPV6 is enabled:\n${is_disabled}"
		else
			log FAILED "$FUNCNAME" "IPV6 is disabled"
		fi
	fi
}

function main_check()
{
	log INFO "$FUNCNAME" "Begin to check config"

	# 1. 检查 os_version
	log INFO check_os_version "$(cat /etc/os_version)"

	# 2. 检查 rpm 包是否安装
	check_rpms "kernel chen"

	# 3. 检查 ipv6 是否禁用
	check_ipv6_state
}

main_check
exit 0

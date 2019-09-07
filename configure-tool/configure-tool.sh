#!/usr/bin/sh

#######################################################################################
#
# Description: EulerOS Security Tool
#
#######################################################################################

#######################################################################################
# name of this script
readonly NAME=`basename $0`
# working directory
readonly WORKD=`pwd`/
# the separator of fields of security configration file
readonly FIELD_SEP='@'

# distinction
DST=""
# security configuration file
SCONF=""
# USER security configuration file
USR_SCONF=""
# File where to write log
LOGFILE=""
# flag
SILENT=0
# execute configure item's id
EXECID=0
# temporary target of decompress and compress
TMPTARGET="EulerOS"

# distinction type(rootfs, ar, cpio.gz)
DST_TYPE="rootfs"
# directory of decompressed rootfs
ROOTFS=""
# distinction name when it's not rootfs
AR_F=""
GZ_F=""

##############################################################################

#=============================================================================
# Function Name: pushd/popd
# Description  : the same to standard pushd/popd except that no info printed
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function pushd()
{
    builtin pushd "$@" > /dev/null
    return $?
}
function popd()
{
    builtin popd "$@" > /dev/null
    return $?
}

#=============================================================================
# Function Name: fn_test_params_num
# Description  : test if the num of params is the right num(do not support flexible parameters), quit otherwise
# Parameter    : params_num
# Returns      : none
#=============================================================================
function _fn_test_params_num()
{
    if [ $# -lt 3 ] || [ $2 -ne $3 ]; then
        echo "Line $1: num of params $2 not equals to $3"
        exit 1
    fi
}
alias fn_test_params_num='_fn_test_params_num $LINENO $#'

#=============================================================================
# Function Name: fn_test_type
# Description  : test if the specific file type by a keyword
# Parameter    : file, keyword(directory, cpio archive, gzip compressed, ar archive, ...)
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_test_type()
{
    fn_test_params_num 2

    file "$1"| awk -F: '{print $2}' |grep "$2" >/dev/null
    return $?
}

#=============================================================================
# Function Name: fn_get_fullpath
# Description  : get absolute path name of file
# Parameter    : file
# Returns      : fullpath
#=============================================================================
function fn_get_fullpath()
{
    fn_test_params_num 1

    local p=$1
    local out

    if [ "${p:0:1}" = "/" ]; then
        echo $p
        return
    fi

    pushd `dirname $p`
    out=`pwd`
    popd
    echo $out"/"`basename $p`
}

#=============================================================================
# Function Name: fn_escape_string
# Description  : set special character(/) in the string to be escaped
# Parameter    : string
# Returns      : escaped string
#=============================================================================
function fn_escape_string()
{
    fn_test_params_num 1

    echo "$1"| sed 's/\//\\\//g'| sed 's/\./\\\./g'| sed 's/\[/\\[/g'| sed 's/\]/\\]/g' | sed 's/\$/\\\$/g' | sed 's/\*/\\\*/g'
}

#=============================================================================
# Function Name: fn_log
# Description  : write a message to log file or console
# Parameter    : lineno level(error, warn, info) message
# Returns      : none
#=============================================================================
function fn_log()
{
    fn_test_params_num 3

    local lno=$1
    local level=$2
    shift 2

	# highlight in different color for level
	case $level in
	FAILED) level=`echo $level | sed -r 's/FAILED/\\\033\\[31;1mFAILED\\\033\\[0m/g'`;;
	INFO) level=`echo $level | sed -r 's/INFO/\\\033\\[35;1m\ INFO\ \\\033\\[0m/g'`;;
	WARN) level=`echo $level | sed -r 's/WARN/\\\033\\[33;1m\ WARN\ \\\033\\[0m/g'`;;
	esac

	lname=`echo $NAME | sed -r 's/(.*)/\\\033\\[33;0m\\1\\\033\\[0m/g'`
	lno=`echo $lno | sed -r 's/(.*)/\\\033\\[35;0m\\1\\\033\\[0m/g'`

	# highlight in different color for level
    output=$@
    opt=`echo $output | grep -e "^success"`
    if [ $? -eq 0 ];then
        output=`echo $opt | sed -r 's/^success/\\\033\\[32;1msuccess\\\033\\[0m/g'`
    fi
    opt=`echo $output | grep -e "^fail"`
    if [ $? -eq 0 ];then
        output=`echo $opt | sed -r 's/^fail/\\\033\\[31;1mfail\ \ \ \\\033\\[0m/g'`
    fi

    if [ $SILENT -eq 0 ] || [ "$level" = "ERROR" ]; then
    	echo -e "`date '+%F %H:%M:%S'` [$level] $output"
    fi
    echo -e "`date '+%F %H:%M:%S'` [$level] $output" >> $LOGFILE

}
alias fn_failed='fn_log $LINENO FAILED'
alias fn_warn='fn_log $LINENO WARN'
alias fn_info='fn_log $LINENO INFO'

#=============================================================================
# Function Name: fn_exit
# Description  : to be excuted when exit with return value(0 ok, 1 params error, 2 hardening error)
# Parameter    : status(0 ok, otherwise error), [message]
# Returns      : none
#=============================================================================
function fn_exit()
{
    fn_test_params_num 1
    local s=$1
    # log
    fn_info "========exit, status is [$s]========"
    exit $s
}

#=============================================================================
# Function Name: fn_usage
# Description  : print help messages to console
# Parameter    : none
# Returns      : none
#=============================================================================
function fn_usage()
{
    cat <<EOF
    EulerOS Security Tool
    Usage:     $NAME [Options]
    Options
        -c config_file
            Specify the security configuration file
        -d distinction
            AR format target or cpio.gz format rootfs to be hardened
        -l log_file
            Specify a file to save logs, which is default euleros-security.log
        -x item_id
            Specify the id of security configuration item to be hardened
        -h
            Display help messages
        -s
            Silent mode, without any confirmation or generic printing
EOF
}

#=============================================================================
# Function Name: fn_parse_params
# Description  : parse all the parameters from user
# Parameter    : user params
# Returns      : none
#=============================================================================
function fn_parse_params()
{
    local args=$@

    if [ $# -eq 0 ] || [ "$1" = "-h" ]; then
        fn_usage
        exit 0
    fi

    while getopts c:d:l:x:s arg $args
    do
        case "$arg" in
        c) SCONF=`fn_get_fullpath $OPTARG`;;
        d) DST=`fn_get_fullpath $OPTARG`;;
        l) LOGFILE=`fn_get_fullpath $OPTARG`;;
        x) EXECID=$OPTARG;;
		s) SILENT=1;;
        *) echo "unknown args:$args"
           fn_usage
           exit 1;;
        esac
    done

    # first get LOGFILE resolved
    if [ "$LOGFILE" = "" ]; then
        LOGFILE=$WORKD'euleros-security.log'
    fi
    mkdir -p `dirname $LOGFILE`
    touch $LOGFILE
    chown root:root $LOGFILE
    chmod 600 $LOGFILE

    # Test if dst and conf is valid
    if [ ! -e "$DST" ]; then
        fn_failed "distinction [$DST] not existed"
        fn_exit 2
    fi

    if [ ! -e "$SCONF" ]; then
        fn_failed "config_file [$SCONF] not existed"
        fn_exit 2
    fi

    readonly DST
    readonly SCONF
    readonly LOGFILE
    readonly SILENT
    readonly EXECID

    fn_info "working directory is [$WORKD]"
	fn_info "logging file is [$LOGFILE]"
    fn_info "parsing params[$args] done"
}

#=============================================================================
# Function Name: fn_pre_hardening
# Description  : uncompress ar or cpio.gz source to rootfs
# Parameter    : none
# Returns      : none
#=============================================================================
function fn_pre_hardening()
{
    fn_info "begin pre_hardening"

    if [ -d "$DST" ]; then
        ROOTFS=$DST
        fn_info "hardening destination is a rootfs dir [$ROOTFS]"
    fi
}

#=============================================================================
# Function Name: fn_check_rootfs
# Description  : examine if rootfs is a standard hiberarchy
# Parameter    : none
# Returns      : none
#=============================================================================
function fn_check_rootfs()
{
    for i in bin usr/bin sbin usr/sbin etc boot lib home root opt var tmp proc sys mnt
    do
        if [ ! -d "$ROOTFS/$i" ]; then
            fn_failed "[$i] does not exist, [$ROOTFS] is not a standard EulerOS rootfs"
            fn_exit 2
        fi
    done
}

#=============================================================================
# Function Name: fn_handle_key
# Description  : deal with configurations referred to key and value
# Parameter    : operator, file, key, f4, f5
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_key()
{
    fn_test_params_num 5

    local op file
    op=$1
    file=$2

    file=$ROOTFS$file
    if [ ! -w "$file" ]; then
        fn_warn "file [$file] not existed or writable"
        return 1
    fi

    # key and value with string escaped
    local key f4 f5
    key=`fn_escape_string "$3"`
    f4=`fn_escape_string "$4"`
    f5=`fn_escape_string "$5"`

    # to ingore the differences of key caused by blank characters
    echo "$key" | egrep "^-e.*"
    if [[ $? == 0 ]]
    then
        local grepkey="[[:blank:]]*"`echo "$key" | sed -r 's/[[:blank:]]+/[[:blank:]]\+/g'`
    else
        local grepkey="[[:blank:]]*"`echo $key | sed -r 's/[[:blank:]]+/[[:blank:]]\+/g'`
    fi

    case "$op" in
    # d@file@key
    d)
        grep -E "$grepkey" $file >/dev/null
        if [ $? -eq 0 ]; then
            # comment a line
            sed -ri "s/^[^#]*$grepkey/#&/" $file
            return $?
        else
            return 0
        fi
        ;;
    # m@file@key[@value]
    m)
        grep -E "^$grepkey" $file >/dev/null
        if [ $? -eq 0 ]; then
            sed -ri "s/^$grepkey.*/$key$f4/g" $file
        else
            # add a blank line to file because sed cannot deal with empty file by 'a'
            if [ ! -s $file ]; then
                echo >> $file
            fi

            sed -i "\$a $key$f4" $file
        fi

        return $?
        ;;
    # sm@file@key[@value] similar to m: strict modify on the origin position
    sm)
        grep -E "^$grepkey" $file >/dev/null
        if [ $? -eq 0 ]; then
            sed -ri "s/$key.*/$key$f4/g" $file
        else
            # add a blank line to file because sed cannot deal with empty file by 'a'
            if [ ! -s $file ]; then
                echo >> $file
            fi
            sed -i "\$a $key$f4" $file
        fi

        return $?
        ;;
    # M@file@key@key2[@value2]
    M)
        grep -E "^$grepkey" $file >/dev/null
        if [ $? -eq 0 ]; then
            grep "^$grepkey.*$f4" $file >/dev/null
            if [ $? -eq 0 ]; then
                sed -ri "/^$grepkey/ s/$f4[^[:space:]]*/$f4$f5/g" $file
            else
                sed -ri "s/^$grepkey.*/&$f4$f5/g" $file
            fi

            return $?
        else
            fn_warn "key [$key] not found in [$file]"
            return 1
        fi
        ;;
    *)
        fn_failed "bad operator [$op]"
        return 1
        ;;
    esac
}

#=============================================================================
# Function Name: fn_handle_which
# Description  : deal with configurations referred to commands checking
# Parameter    : commands
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_which()
{
    fn_test_params_num 1

    local ret=0
    local ok
    local c p

    # parse which@command1 [command2 ...]
    for c in $1
    do
        ok=0
        for p in /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin
        do
            if [ ! -d "$ROOTFS$p" ];then
                continue
            fi

            # TODO: deal with the source of softlink
            ls $ROOTFS$p/$c >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                ok=1
                break
            fi
        done

        if [ $ok -ne 1 ]; then
            ret=1
            fn_warn "which command [$c] not found"
        fi
    done

    return $ret
}

#=============================================================================
# Function Name: fn_handle_bashcmd
# Description  : deal with configurations referred to operations to files
# Parameter    : command[option], files
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_bashcmd()
{
    fn_test_params_num 2

    local op=$1
    local files=$2
    local status=0

    # add ROOTFS path for every file
    for file in `echo "$files" | awk -v rf="$ROOTFS" '{
        for(i=1; i<=NF; i++) {
                       printf "%s%s\n",rf,$i
        }
    }'`; do
		echo "${op} ${file}"
        /bin/bash -c "${op} ${file}"
        if [ $? -ne 0 ]; then
            status=1
        fi
    done
    unset f

    return $status
}

#=============================================================================
# Function Name: fn_handle_command
# Description  : deal with configurations referred to operations to files
# Parameter    : command[option], files
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_command()
{
    fn_test_params_num 2

    local op=$1
    local files=$2
    local status=0

    # add ROOTFS path for every file
    for file in `echo "$files" | awk -v rf="$ROOTFS" '{
        for(i=1; i<=NF; i++) {
                       printf "%s%s\n",rf,$i
        }
    }'`; do
        ${op} ${file} >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            status=1
        fi
    done
    unset f

    return $status
}

#=============================================================================
# Function Name: fn_handle_find
# Description  : deal with configurations referred to operations to files
# Parameter    : dir option command
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_find()
{
    fn_test_params_num 3

    dir=$1
    option=$2
    command=$3

    for FD in `find $ROOTFS/$dir $option`;do
        fn_handle_command "$command" "$FD"
    done
}

#=============================================================================
# Function Name: fn_handle_file
# Description  : harden the files and directories
# Parameter    : sec_file
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_file()
{
    fn_test_params_num 1

    sec_file=$1

    for FD in `awk '{print $0 }' $sec_file`; do
        FILE=`echo $FD | awk -F, '{ print $1 }'`
        OWNER=`echo $FD | awk -F, '{ print $2 }'`
        GROUP=`echo $FD | awk -F, '{ print $3 }'`
        PERM=`echo $FD | awk -F, '{ print $4 }'`
        FLAG=`echo $FD | awk -F, '{ print $5 }'`
        if [ $FLAG = "SUBDIRS" ]; then
            find $ROOTFS$FILE -maxdepth 0 -type d -exec chown $OWNER {} \;
            find $ROOTFS$FILE -maxdepth 0 -type d -exec chgrp $GROUP {} \;
            find $ROOTFS$FILE -maxdepth 0 -type d -exec chmod $PERM {} \;
        elif [ $FLAG = "SUBFILES" ]; then
            find $ROOTFS$FILE -maxdepth 1 -type f -exec chown $OWNER {} \;
            find $ROOTFS$FILE -maxdepth 1 -type f -exec chgrp $GROUP {} \;
            find $ROOTFS$FILE -maxdepth 1 -type f -exec chmod $PERM {} \;
        else
            chown $OWNER $ROOTFS$FILE >/dev/null 2>&1
            chgrp $GROUP $ROOTFS$FILE >/dev/null 2>&1
            chmod $PERM $ROOTFS$FILE  >/dev/null 2>&1
        fi
    done

    return 0
}

#=============================================================================
# Function Name: fn_handle_cp
# Description  : deal with configurations referred to operations to files
# Parameter    : src_file dst_file
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_cp()
{
    fn_test_params_num 2

    src_file=$1
    dst_file=$2

    cp -p $src_file $ROOTFS/$dst_file
    if [ $? -ne 0 ]; then
        return 1
    else
        return 0
    fi
}

#=============================================================================
# Function Name: fn_handle_systemctl
# Description  : start or stop services
# Parameter    : service_name service_status
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_systemctl()
{
    fn_test_params_num 2

    syetem_service_name=$1
    syetem_service_status=$2
	if [ "$ROOTFS" = "/" ]; then
    	systemctl ${syetem_service_status} ${syetem_service_name}
	else
		systemctl ${syetem_service_status} ${syetem_service_name} --root=$ROOTFS
	fi

    return $?
}

#=============================================================================
# Function Name: fn_handle_path
# Description  : restrict PATH
# Parameter    : path_list
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_path()
{
    fn_test_params_num 1

    path_list=$1

    for PART in `echo $PATH | awk -F: '{for (NUM=1;NUM<=NF;NUM++) {print $NUM}}'`; do
        # Ignore default directories in PATH
        if [ "$PART" == "/bin" -o "$PART" == "/sbin" -o "$PART" == "/usr/bin" -o "$PART" == "/usr/sbin" -o "$PART" == "/usr/local/bin" -o "$PART" == "/usr/local/sbin" ]; then
            continue
        fi

        # Eliminate X11 and games in existing PATH
        if [ "$PART" == "/usr/bin/X11" -o "$PART" == "/usr/X11R6/bin" -o "$PART" == "/usr/games" ]; then
            continue
        fi

        # Eliminate redundant ":" in existing PATH
        if [ "$PART" == "" ]; then
            continue
        fi

        # Eliminate directories that do not exist
        if [ ! -d "$PART" ]; then
            continue
        fi

        path_list="${path_list}:$PART"
    done

    echo "PATH=${path_list}" >> "$ROOTFS/etc/profile"
    echo "export PATH" >> "$ROOTFS/etc/profile"

    return $?
}

#=============================================================================
# Function Name: fn_handle_home
# Description  : deal with user home directories.
#                User home directories should be mode 750 or more restrictive.
# Parameter    : user_file
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_home()
{
    fn_test_params_num 1

    user_file=$1

    for DIR in `awk -F: '($3 >= 1000) { print $6 }' "$ROOTFS${user_file}"`; do
        chmod g-w "$ROOTFS$DIR" > /dev/null 2>&1
        chmod o-rwx "$ROOTFS$DIR" > /dev/null 2>&1
    done

    return 0
}

#=============================================================================
# Function Name: fn_handle_umask
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_handle_umask()
{
    fn_test_params_num 2

    local target=$1
    local value=$2
    local ret=0

    if [ "$target" == "user" ]
    then
        echo "umask $value" >> "$ROOTFS/etc/bashrc"
        echo "umask $value" >> "$ROOTFS/etc/csh.cshrc"
        for file in $(find "$ROOTFS/etc/profile.d/" -type f)
        do
           echo '' >> $file # 防止配置文件末尾没有换行符的情况
           echo "umask $value" >> $file
        done
    elif [ "$target" == "deamon" ]
    then
        echo "umask $value" >> "$ROOTFS/etc/sysconfig/init"
    else
        ret = 1
    fi

    return $ret
}

#=============================================================================
# Function Name: fn_harden_rootfs
# Description  : harden the rootfs, according to configuration file
# Parameter    : none
# Returns      : none
#=============================================================================
function fn_harden_rootfs()
{
    fn_check_rootfs

    fn_info "---begin hardening rootfs by [$SCONF]---"
    local status
    local f1 f2 f3 f4 f5 f6

    #  do configuration traversal, with comments and lines starting with blankspace ignored
    grep -v '^#' $SCONF| grep -v '^$'| grep -Ev '^[[:space:]]+'| while read line
    do
        f1=`echo $line | awk -F$FIELD_SEP '{print $1}'`
        if [ $EXECID -ne 0 ] && [ "$EXECID" -ne "$f1" ];then
            continue
        fi

        f2=`echo $line | awk -F$FIELD_SEP '{print $2}'`
        f3=`echo $line | awk -F$FIELD_SEP '{print $3}'`
        f4=`echo $line | awk -F$FIELD_SEP '{print $4}'`
        f5=`echo $line | awk -F$FIELD_SEP '{print $5}'`
        f6=`echo $line | awk -F$FIELD_SEP '{print $6}'`
        case "$f2" in
        d|m|sm|M)
            fn_handle_key "$f2" "$f3" "$f4" "$f5" "$f6"
            status=$?
            ;;
        which)
            fn_handle_which "$f3"
            status=$?
            ;;
        find)
            fn_handle_find "$f3" "$f4" "$f5"
            status=$?
            ;;
        cp)
            fn_handle_cp "$f3" "$f4"
            status=$?
            ;;
        file)
            fn_handle_file "$f3"
            status=$?
            ;;
        systemctl)
            fn_handle_systemctl "$f3" "$f4"
            status=$?
            ;;
        path)
            fn_handle_path "$f3"
            status=$?
            ;;
        home)
            fn_handle_home "$f3"
            status=$?
            ;;
        umask)
            fn_handle_umask "$f3" "$f4"
            status=$?
            ;;
		bashcmd)
			fn_handle_bashcmd "$f3" "$f4"
			status=$?
			;;
        *)
            fn_handle_command "$f2" "$f3"
            status=$?
            ;;
        esac

        if [ $status -eq 0 ]; then
            fn_info "success [$line]"
        else
            fn_warn "fail [$line]"
        fi
    done
    unset line
    fn_info "---end hardening rootfs---"

    fn_check_rootfs
}

#=============================================================================
# Function Name: fn_main
# Description  : main function
# Parameter    : command line params
# Returns      : 0 on success, otherwise on fail
#=============================================================================
function fn_main()
{
    # operator must be root
    if [ `id -u` -ne 0 ]; then
        echo "You must be logged in as root."
        exit 1
    fi

    # parse user params
    fn_parse_params "$@"

    # pre-process
    fn_pre_hardening

    # harden rootfs
    fn_harden_rootfs

    # do cleanup and exit
    fn_exit 0
}

# check cancel action and do cleanup
trap "echo 'canceled by user...'; fn_exit 1" INT TERM
# main entrance

fn_main "$@"

exit 0

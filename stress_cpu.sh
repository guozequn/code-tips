#!/bin/bash
# Author:        GuoZeQun
# Mail:          guozequn@jd.com
# Date:          2020/7/14 11:34
# Description:

# stress bin path
STRESS_BIN=/usr/bin/stress
# expect cpu usage. 30 means cpu.use > 0.3
EXPECT_CPU_RATE=30
# max cores used percent
MIN_CORE_LEFT=4
# default timeout
PRESS_TIMEOUT=30
# default exec interval(${interval}-1 sec is recommended)
EXEC_INTERVAL=599
# app list.
APP_NAME_LIST=(
    "app_name_1"
    "app_name_2"
)

# current cpu number.
SUITABLE_CORE=


function get_curr_host_ip(){
    local ip=$(python -c "import socket;print([(s.connect(('8.8.8.8', 53)),
    s.getsockname()[0], s.close()) for s in
    [socket.socket(socket.AF_INET,socket.SOCK_DGRAM)]][0][1])")
    echo ${ip}
}


function round_value(){
    local _need_to_round=$1
    local _num=${_need_to_round%.*}
    echo ${_num}
}


# Get current appName
function get_curr_app_name(){
    local ip=$1
    
    # fetch current app name of host
    local app_name=($(query app ${ip}))
    
    if [[ ${#app_name[@]} -ne 1 ]]; then
        echo ""
    else
        echo ${app_name[0]}
    fi
}

# Current cpu usage.
function get_curr_cpu_rate(){
	local curr_cpu_idle=`env LC_ALL=en_US.UTF8 sar 1 1 | grep ^Average | awk '{print $8}' `
	local curr_cpu_rate_int=$(round_value ${curr_cpu_idle})
	local rate=$(expr 100 - ${curr_cpu_rate_int})
	echo ${rate}
}


# Current cpu cores.
function get_cpu_core_num(){
	local cpu_core_num=`cat /proc/cpuinfo| grep "processor"| wc -l`
	echo ${cpu_core_num}
}

# get stress core count by usage.
function get_stress_cores(){
    local current_cores=$1
    local current_usage=$2
    local diff_rate=$(round_value $(expr ${EXPECT_CPU_RATE} - ${current_usage}))

    if [[ "$SUITABLE_CORE" == "" ]];then
        if [[ ${diff_rate} -gt 0 ]]; then
            local _count=$(round_value $(echo "${diff_rate} * ${current_cores} / 100"|bc))
            SUITABLE_CORE=${_count}
            echo ${_count}
        else
            echo "Skip"
        fi
    else
        if [[ ${diff_rate} -gt 0 ]]; then
            SUITABLE_CORE=$(expr ${SUITABLE_CORE} + 1)
            echo ${SUITABLE_CORE}
        elif [[ ${diff_rate} -lt -5 ]]; then
            SUITABLE_CORE=$(expr ${SUITABLE_CORE} - 1)
            echo ${SUITABLE_CORE}
        else
            echo "Skip"
        fi
    fi
}

# Check app in app_list belongs to "$appName"
function check_condition(){
    local app_name=$1
    for _app in ${APP_NAME_LIST[@]};do
        if [[ "${_app}"x == "${app_name}"x ]]; then
            return
        fi
    done
    echo "Skip"
}


function judge_cores(){
    # checks whether stress the suppress need to execute.
    local current_cores=$1
    local cores_to_judge=$2
    local left_cores=$(expr ${current_cores} - ${cores_to_judge})
    if [[ ${left_cores} -lt ${MIN_CORE_LEFT} ]]; then
        echo "Skip"
    fi
}

# action.
function suppress_usage(){
    while true; do
        if [[ -z "$(/usr/sbin/pidof stress)" ]]; then
            [[ ${SUITABLE_CORE} -eq 0 ]] && break
            [[ ${PRESS_TIMEOUT} -lt 1 ]] && exit
            ${STRESS_BIN} --cpu ${SUITABLE_CORE} --timeout ${PRESS_TIMEOUT} > /dev/null 2>&1 &
            break
        else
            sleep 1
            continue
        fi
    done
}


# get current timestamp.
function get_current_timestamp(){
    local _timestamp=$(date +%s)
    echo ${_timestamp}
}


# check timeout.
function check_timeout(){
    local _start_time=$1
    local _running_time=$(expr $(get_current_timestamp) - ${_start_time})
    [[ ${_running_time} -gt ${EXEC_INTERVAL} ]] && exit 0
    local _left_time=$(expr ${EXEC_INTERVAL} - ${_running_time})
    [[ ${_left_time} -lt ${PRESS_TIMEOUT} ]] && PRESS_TIMEOUT=${_left_time}
}


# pressure main process.
function mainly_process(){
    local _cores=$(get_cpu_core_num)
    local _start_time=$(get_current_timestamp)
    while true; do
        check_timeout ${_start_time}
        local _app_name=$(get_curr_app_name $(get_curr_host_ip))
        case $(check_condition ${_app_name}) in
            "Skip")
                sleep ${PRESS_TIMEOUT}
                continue
                ;;
            *)
                local curr_usage=$(get_curr_cpu_rate)
                get_stress_cores ${_cores} ${curr_usage}
                case ${SUITABLE_CORE} in
                    "Skip")
                        sleep ${PRESS_TIMEOUT}
                        continue
                        ;;
                    *)
                        case $(judge_cores ${_cores} ${SUITABLE_CORE}) in
                            "Skip")
                                sleep ${PRESS_TIMEOUT}
                                continue
                                ;;
                            *)
                                suppress_usage
                                sleep $(expr ${PRESS_TIMEOUT} - 1)
                                ;;
                            esac
                        ;;
                esac
                ;;
        esac
    done
}

mainly_process


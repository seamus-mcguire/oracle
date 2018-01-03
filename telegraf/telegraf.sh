#!/bin/bash

####  Variables
# Command-line options
TELEGRAF_OPTS=

# Ansible Variables 
install_dir="{{ telegraf_install_dir }}"
binary="{{ telegraf_binary }}"

conf_dir="${install_dir}/etc/telegraf"
config="${conf_dir}/telegraf.conf"
log_dir="${install_dir}/var/log/telegraf"
log_file="${log_dir}/telegraf.log"
process=$(basename "$binary")
user="{{ telegraf_user }}"

####  Functions
pidofproc() {

   ps_sig="${process} -config"

   OS=$(uname -s)
   case $OS in
                SunOS)  PIDS=$(/usr/ucb/ps -axuwww | grep "$ps_sig" | grep -v grep | grep $user  | sed -e 's/[^ ]* *\([0-9]*\).*/\1/g')
                        ;;
                Linux)  PIDS=$(ps -edf | grep "$ps_sig" | grep -v grep | grep $user  | sed -e 's/[^ ]* *\([0-9]*\).*/\1/g')
                        ;;
                CYGWIN_NT-5.1)  PIDS=$(ps wwaux | grep "$ps_sig" | grep -v grep | grep $user | sed -e 's/[^ ]* *\([0-9]*\).*/\1/g')
                        ;;
                *)      echo ERROR "Unsupported OS: $OS"
                        exit 1
        esac

   echo $PIDS | grep .
}

log_failure_msg() {
    echo "[ FAILED ]" "$@"
}

log_success_msg() {
    echo "[ OK ]" "$@"
}

####  Go

# If the binary is not there, then exit.
if [ ! -x "$binary" ]; then
 log_failure_msg "$binary does not exist or is not executable"
 exit 1
fi

case $1 in
    start)
        # Checked if running already
        pid=$(pidofproc)
        if [ -n "$pid" ]; then
                log_failure_msg "$process process is running with PID: ${pid}"
                exit 0
        fi

        log_success_msg "Starting the process" "$process"
        /bin/sh -c "nohup $binary -config $config -config-directory $conf_dir $TELEGRAF_OPTS > ${log_file} 2>&1 &"
        sleep 2

        pid=$(pidofproc)
        if [ -n "$pid" ]; then
                log_success_msg "$process process was started with PID: ${pid}"
                exit 0
        else
                log_failure_msg "$process process is not running"
                exit 1
        fi
        ;;

    stop)
        # Checked if running already
        pid=$(pidofproc)
        if [ -n "$pid" ]; then
                kill -9 $pid
                log_success_msg "$process process with PID ${pid} was stopped"
                exit 0
        else
                log_failure_msg "$process process is not running"
                exit 1
        fi
        ;;

    restart)
        # Restart the binary.
        $0 stop && sleep 2 && $0 start
        ;;

    status)
        # Checked if running already
        pid=$(pidofproc)
        if [ -n "$pid" ]; then
                log_success_msg "$process process is running with PID: ${pid}"
                exit 0
        else
            log_failure_msg "$process process is not running"
            exit 1
        fi
        ;;

    version)
        $binary version
        ;;

    *)
        # For invalid arguments, print the usage message.
        echo "Usage: $0 {start|stop|restart|status|version}"
        exit 1
        ;;
esac


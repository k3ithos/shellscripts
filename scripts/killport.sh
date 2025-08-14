#!/bin/bash
# https://stackoverflow.com/questions/33502525/kill-sigterm-and-killsig-safely-terminating-applications
# 
# Usefull during development in VS Code
#  Sometimes a (terminal) process keeps running after VS Code is shut down
# 
# 1. Identify pid from port number
# 2. Instead of using 'kill -9 <pid>'', attempt 'kill -SIGTERM <pid>'
# 
# Author Janick Mantov, 2025
# 
verbose=undef
force=undef
PORT=undef
PID=undef

function usage () {
    cat <<EOUSAGE
$(basename $0) [options] portnumber

    Options:
    -v    Verbose
    -f    Force kill - use SIGKILL instead of SIGTERM
    -h    Help (this usage message)

EOUSAGE
}

# check input arguments
# Optional input
get_opts()
{
    # in the optstring - ':' means read from $OPTARG to take the next input
    # Filename: '-f filename', add 'f:' to optstring
    # Verbose : '-v', add 'v' to optstring
    optstring='hvf'

    while getopts :$optstring opt
    do
        case $opt in
            v)
                verbose=1
                ;;
            f)
                force=1
                ;;
            h)
                usage
                exit 1
                ;;
            *)
                echo "Invalid option: -$OPTARG" >&2
                usage
                exit 2
                ;;
        esac
    done
}

# Additional (required arguments comming AFTER options
get_args()
{
    CNT=0
    while [[ "$@" != "" ]]
    do
        arg="$1"
        let CNT=$(($CNT + 1))
        ARGS[$CNT]="$arg"
        shift
    done
}

# echo " options: $#"
get_opts $*
# [ $verbose ] && echo "\$@ pre shift is \"$@\""
shift $((OPTIND - 1))
[ "$verbose" == "1" ] && echo "Verbose : $verbose"
[ "$verbose" == "1" ] && echo "Force   : $force"

get_args $@
[ "$verbose" == "1" ] && echo Number of arguments received: ${#ARGS[@]}
[ "$verbose" == "1" ] && echo "Additional arguments: '$@'"

if [ "${#ARGS[@]}" != "1" ]; then
    echo "Illegal input!"
    usage
else
    PORT="$@"
    [ "$verbose" == "1" ] && echo "port    : $PORT"
fi

# Identify pid from port number
# netstat - Print network connections, routing tables, interface statistics, masquerade connections, and multicast memberships
# netstat -nlp
# 
# Dump socket statistics - information similar to netstat. It can display more TCP and state informations than other tools.
# sudo ss -nlpt 
# 
SOCKET_STATISTICS=$(ss -nlpt | grep $PORT)
if [ "$SOCKET_STATISTICS" == "" ]; then
    [ "$verbose" == "1" ] && echo
    echo "  No socket statistics found on port $PORT."
    echo
    exit 0
fi
# [ "$verbose" == "1" ] && [ "$SOCKET_STATISTICS" != "" ] && echo "SOCKET_STATISTICS:" && echo "$SOCKET_STATISTICS"
# ➜  scripts ss -nlpt              
# State        Recv-Q       Send-Q                  Local Address:Port                Peer Address:Port       Process                                    
# LISTEN       0            511                         127.0.0.1:3000                     0.0.0.0:*           users:(("node",pid=1412375,fd=24))        
# LISTEN       0            4096                             [::]:3306                        [::]:*                                                     

# fetch 6'th element from line (delimited by whitespace)
SOCKET_PROCESS=$(echo $SOCKET_STATISTICS | cut -d ' ' -f 6)
# [ "$verbose" == "1" ] && echo "Process : $SOCKET_PROCESS"

# strip prefix until first ','
key_val=${SOCKET_PROCESS#*,}
# strip suffix from first ','
key_val=${key_val%,*}
# [ "$verbose" == "1" ] && echo "key_val : $key_val"

PID=$(echo $key_val | cut -d '=' -f 2)
[ "$verbose" == "1" ] && echo "pid     : $PID" && echo


# Attempt 'kill -SIGTERM <pid>'
SIGFLAG=SIGTERM
[ "$force" == "1" ] && SIGFLAG=SIGKILL

[ "$force" == "1" ] || [ "$verbose" == "1" ] && echo "kill -$SIGFLAG $PID"
exit_status=$(kill -$SIGFLAG $PID; echo $?)
if [ "$exit_status" == "0" ]; then
    echo "Successfully killed PID $PID on port $PORT."
    echo
    exit 0
fi
exit 1
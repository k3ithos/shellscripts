#!/bin/bash
# 
# Clean up orphaned processes spawnd by node on cPanel host
# 1. Identify pid 'lsnode' + subdomain foldernames
# 2. Instead of using 'kill -9 <pid>'', attempt 'kill -SIGTERM <pid>'
# 
# NodeJS processes that should have terminated often keep running as orphaned 'ghosts'
# it's not just 'once in while', cleaning up is a serious task on a production server
# 
# Author Janick Mantov, 2025
#

SCRIPTNAME=$(basename $0)
LOGFILE=${SCRIPTNAME/.sh/.log}
LOGDIR=$(dirname $(realpath "$0"))
[ ! -e $LOGDIR ] && LOGDIR="."

function add_log () {
    LOGTXT=$*
    [ "$verbose" == "1" ] && echo "$(date "+%Y-%m-%d %H:%M:%S") - $LOGTXT"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $LOGTXT" 2>&1 >>$LOGDIR/$LOGFILE
}

verbose=
force=
dryrun=
SEARCHSTRING="lsnode:/home/$USER/"
PID=

# multible kinds of processes
declare -A domains
domains[1]='mydomain.com'
domains[2]='api.mydomain.com'
domains[3]='dev.mydomain.com'
domains[4]='test.mydomain.com'

# --- input handling ----------------------------------------------------------

function usage () {
    cat <<EOUSAGE
$SCRIPTNAME [options] 'SEARCHSTRING'

    Options:
    -v    Verbose
    -d    Dry-run - show intended behaviour but don't touch anything
    -f    Force kill - use SIGKILL instead of SIGTERM
    -h    Help (this usage message)

    Default SEARCHSTRING: '$SEARCHSTRING'

    If called without 'SEARCHSTRING', the script runs through the internal 
    array of domains (foldernames added to search string), to clean up each
    'domain' separately, one by one.

EOUSAGE
}

# check input arguments
# Optional input
get_opts()
{
    # in the optstring - ':' means read from $OPTARG to take the next input
    # Filename: '-f filename', add 'f:' to optstring
    # Verbose : '-v', add 'v' to optstring
    optstring='hvfd'

    while getopts :$optstring opt
    do
        case $opt in
            v)
                verbose=1
                ;;
            f)
                force=1
                ;;
            d)
                dryrun=1
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
get_args $@

if [ "${#ARGS[@]}" != "0" ]; then
    if [ "${#ARGS[@]}" == "1" ]; then
        SEARCHSTRING="$@"
        # [ "$verbose" == "1" ] && echo "Additional argument: '$SEARCHSTRING'"
    else
        echo "Illegal input!"
        usage
    fi
fi

# --- main script handling ----------------------------------------------------

if [ "$verbose" == "1" ] || [ "$dryrun" == "1" ]; then
    VERBOSE_CMD="${SCRIPTNAME}"
    [ "$verbose" == "1" ] && VERBOSE_CMD="${VERBOSE_CMD} -v"
    [ "$force" == "1" ] && VERBOSE_CMD="${VERBOSE_CMD} -f"
    [ "$dryrun" == "1" ] && VERBOSE_CMD="${VERBOSE_CMD} -d"
    add_log "${VERBOSE_CMD}"
fi

# rotate log - maintain logsize at an acceptable limit
LOGSIZE=$(cat $LOGDIR/$LOGFILE | wc -l)
if [ $LOGSIZE -gt 1000 ]; then
    mv -f $LOGDIR/$LOGFILE $LOGDIR/$LOGFILE.1
fi
if [ ! -f $LOGDIR/$LOGFILE ]; then
    echo "### Log produced by cron-job ${SCRIPTNAME}" >>$LOGDIR/$LOGFILE
fi
[ "$verbose" == "1" ] && echo "LOGFILE : $LOGDIR/$LOGFILE"

handle_orphaned_processes()
{
    SEARCHSTR=$*
    prev_line=""
    [ "$verbose" == "1" ] && add_log "handle_orphaned_processes('${SEARCHSTR}')"
    ps -aux | grep ${SEARCHSTR} | while read -r line
    # expecting 'ps -aux' to produce something like this:
    # USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    # username   22806  0.0  0.0 1086556 70912 ?       Sl   11:12   0:00 lsnode:/home/username/dev.mydomain.com/
    # username  245696  0.0  0.0  45832  3996 pts/0    R+   11:57   0:00 ps -aux
    # username 1626931  0.0  0.0 1175736 54720 ?       Sl   Aug11   0:01 lsnode:/home/username/mydomain.com/
    # username 3879283  0.0  0.0  13444  4356 pts/0    S    10:04   0:00 /bin/bash -l
    # username 3911293  0.0  0.0 1086604 73900 ?       Sl   10:11   0:00 lsnode:/home/username/dev.mydomain.com/
    do
        # avoid matching the actual 'grep' command
        echo "$line" | grep -q "[g]rep" && continue

        # latest process is the active one, keep it alive by only removing 'prev' processes 
        if [ "$prev_line" != "" ]; then
            [ "$verbose" == "1" ] && echo "process: $prev_line"
            # fetch 2., 9. and 11. element from prev_line (delimited by whitespace)
            PID=$(echo $prev_line | cut -d ' ' -f 2)
            START=$(echo $prev_line | cut -d ' ' -f 9)
            COMMAND=$(echo $prev_line | cut -d ' ' -f 11-)

            if [[ "${COMMAND}" =~ ^${SEARCHSTR}.*$ ]]; then
                # Attempt 'kill -SIGTERM <pid>'
                SIGFLAG=SIGTERM
                [ "$force" == "1" ] && SIGFLAG=SIGKILL

                # [ "$force" == "1" ] || [ "$verbose" == "1" ] && add_log "kill -$SIGFLAG $PID"
                if [ "$dryrun" == "1" ]; then
                    echo "kill -${SIGFLAG} ${PID}; echo \$?"
                    exit_status="0"
                else
                    exit_status=$(kill -${SIGFLAG} ${PID}; echo $?)
                fi
                if [ "$exit_status" == "0" ]; then
                    add_log "Orphaned process removed: pid ${PID}, started at ${START} - '${COMMAND}'"
                else
                    add_log "FAILED to remove process: pid ${PID}, started at ${START} - '${COMMAND}'"
                fi
            fi
        fi
        prev_line=$line
    done
}

if [ "${SEARCHSTRING}" != "lsnode:/home/$USER/" ]; then
    handle_orphaned_processes "${SEARCHSTRING}"
else
    # bash
    for key in ${!domains[@]}; do
        [ "$verbose" == "1" ] && echo "### ${key}: ${domains[${key}]}"
        handle_orphaned_processes "lsnode:/home/$USER/${domains[${key}]}"
        [ "$verbose" == "1" ] && echo
    done
fi

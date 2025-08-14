# shellscripts

## cPanel/cleanup_orphans.sh

Created to run as a cron job in a cPanel webhotel.

This is not a _great_ solution - it is rather a work-around, since it doesn't resolve any problems. What it does, is handling the symptoms (hanging processes) by sending them a SIGTERM to make them terminate - and this way freeing locked resources - creating stability around the webhosted NodeJS app.

### Purpose

Running NodeJS applications in a cPanel hosted environment is a bit different from running NodeJS apps on localhost. P
rocesses might fail and cause the cPanel process control system to respawn a new NodeJS - or processes that were supposed to terminate keeps hanging as ghosts - eventually ending up taking all resources until the cPanel Resource Monitor blocks further usage.

```shell
cleanup_orphans.sh [options] 'COMMAND (sub)string'

    Options:
    -v    Verbose
    -d    Dry-run - show intended behaviour but don't touch anything
    -f    Force kill - use SIGKILL instead of SIGTERM
    -h    Help (this usage message)
```

### Logging

Logging is implemented to have a history - be able to track how many processes are being handled.
At the same time - too much loging could cause another problem; _We don't want the disk to run out of space_ due to endless logging. The solution is to limit logging to two files holding up to 1000 lines each.

### Deployment into specific cPanel solution

1. Copy the script 'as is' to a local disk.
2. The script has this associative array declared, holding the root-foldernames of all the webhosted NodeJS apps

   ```shell
    declare -A domains
    domains[1]='mydomain.com'
    domains[2]='api.mydomain.com'
    domains[3]='dev.mydomain.com'
    domains[4]='test.mydomain.com'
   ```

   Edit in your favourite editor, adjust this arrays to reflect your specific webhotel solution.

3. Adjust the logsize if you like.
   It's this part that handles logsize and logfile rotations - I won't go into details, find out yourself.

   ```shell
    # rotate log - maintain logsize at an acceptable limit
    LOGSIZE=$(cat $LOGDIR/$LOGFILE | wc -l)
    if [ $LOGSIZE -gt 1000 ]; then
        mv -f $LOGDIR/$LOGFILE $LOGDIR/$LOGFILE.1
    fi
   ```

4. Adjust the LOGDIR if you like - currently set to log into the script folder
5. Create a folder on your webhotel to hold and maintain custom made scripts - ex.: `/cronscripts`
6. Copy the adjusted `cleanup_orphans.sh` to the webhotel folder: `/cronscripts/cleanup_orphans.sh`
7. Add a cron job in cPanel - I suggest running this script on a regular basis like every 5-30 minutes
   (depending on the amount of traffic that causes orphaned processes)

   ex.: `*/5 * * * * /home/infoqrco/cronscripts/cleanup_orphans.sh`
8. Monitor the first execution, optionally play with the optional flags '-v' (verbose) and -d (dry-run).
   Watch the logfile being created and ensure that the cron job runs as expected

Done! Your NodeJs orphaned processes are now being taken care of.

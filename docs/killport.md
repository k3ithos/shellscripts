
# scripts/killport.sh

Usefull during development in VS Code.

Normally you don't kill processes - but sometimes a (terminal) process keeps running after VS Code is shut down.

Instead of first doing `ps -aux` to identify running processes, then pick the process Id and finally send a `kill <pid>` command to shut down the process that occupies your development port, this tool does it for you in a single command.

1. Identify pid from port number
2. Instead of using 'kill -9 \<pid>'', attempt 'kill -SIGTERM \<pid>'

```shell
killport.sh [options] portnumber

    Options:
    -v    Verbose
    -f    Force kill - use SIGKILL instead of SIGTERM
    -h    Help (this usage message)

ex.: killport.sh 3000
```

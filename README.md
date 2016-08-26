## clipmon.ps1
When you can not simply call meterpreter's *clipboard_monitor_start*, help yourself with [clipmon.ps1](https://github.com/cayee/ps/blob/master/clipmon.ps1) (a script taken from this [blog post](https://mnaoumov.wordpress.com/2013/08/31/cpowershell-clipboard-watcher/) and enhanced a bit including hiding it from Alt-Tab). It can be executed from Windows shell with:
```
powershell -executionpolicy bypass -noexit -command . .\clipmon.ps1 <logfilename>
```
The information is logged in the following format:
```
<pid> <timestamp> [<window title>] <text copied>
```
Once executed, the *powershell.exe* process will keep running as denoted by `-noexit` parameter, so to stop the monitoring just kill the process using `pid` displayed in the first column.

**NOTE:** the solution is based on WinAPI introduced in Vista, so the monitor will not work in previous Windows versions

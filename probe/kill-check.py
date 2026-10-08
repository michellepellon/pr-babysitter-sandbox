# ABOUTME: Task 9 probe (throwaway): mirrors prove.go's runAs: start a confined command in its own process group,
# ABOUTME: then kill the group as agent through the wrapper, and report whether it died.
import subprocess, sys, time
p = subprocess.Popen(["sudo", "/usr/local/sbin/as-agent", "sh", "-c", "sleep 300 & sleep 300"], process_group=0)
time.sleep(2)
ps = subprocess.run(["ps", "-o", "pid,pgid,user,args", "-g", str(p.pid)], capture_output=True, text=True).stdout
print("group before kill:\n" + ps)
subprocess.run(["sudo", "/usr/local/sbin/as-agent", "kill", "-KILL", "--", str(-p.pid)])
try:
    print("waited, returncode", p.wait(timeout=10))
except subprocess.TimeoutExpired:
    print("STILL RUNNING after kill"); sys.exit(1)
left = subprocess.run(["pgrep", "-g", str(p.pid)], capture_output=True, text=True).stdout
print("left in group:", left or "none")

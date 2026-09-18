# Lab 4
# Ezovskikh Dmitriy

### 1.2: Annotated trace

Full annotated capture: [lab4-trace.txt](lab4-trace.txt). I captured one `POST /notes` request with tcpdump on the loopback interface. In the trace you can see:

- TCP three-way handshake: SYN -> SYN/ACK -> ACK
- HTTP request `POST /notes HTTP/1.1` with the JSON body
- HTTP response `201 Created` with the created note
- Connection close: FIN from client, FIN from server, last ACK

### 1.3: Five debugging commands

```bash
thebruh@thebruh-PC:~$ ss -tlnp | grep :8080
LISTEN 0      4096                *:8080            *:*    users:(("quicknotes",pid=4577,fd=3))

thebruh@thebruh-PC:~$ ip route show
default via 172.21.176.1 dev eth0 proto kernel
172.21.176.0/20 dev eth0 proto kernel scope link src 172.21.188.171

thebruh@thebruh-PC:~$ mtr -rwc 5 localhost
Start: 2026-09-18T05:14:54+0300
HOST: thebruh-PC Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- localhost   0.0%     5    0.0   0.1   0.0   0.1   0.0

thebruh@thebruh-PC:~$ dig +short example.com @1.1.1.1
172.66.147.243
104.20.23.154

thebruh@thebruh-PC:~$ journalctl --user -u quicknotes -n 20 || true
-- No entries --
```

### 1.4: What would I check first if QuickNotes returned 502?

502 means the proxy in front of the app is working, but the app behind it did not answer properly. So I would check the app side first. I would look at the proxy error log - it usually says what exactly broken. Then I would check if the QuickNotes process is running and if it listens on the right port. Then I would try `curl -v http://localhost:8080/health` from the same machine to see if the app answers at all. Lastly ill check DNS and firewall.

---

## Task 2 — Outside-In Debugging on a Broken Deploy

### 2.1: Run a broken instance

One QuickNotes instance was already running on :8080 from Task 1. I started a second one on the same port:

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ ADDR=:8080 CGO_ENABLED=0 go run . 2>&1 | tee /tmp/qn-broken.log
2026/09/18 05:38:38 quicknotes listening on :8080 (notes loaded: 8)
2026/09/18 05:38:38 listen: listen tcp :8080: bind: address already in use
exit status 1
```

The second instance failed with `bind: address already in use`, as expected.

### 2.2: Outside-in chain

**1) Is it running?**

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ ps -ef | grep quicknotes | grep -v grep
thebruh     4577    4255  0 05:02 pts/0    00:00:00 /tmp/go-build2278162836/b001/exe/quicknotes
```

Decision: only one quicknotes process is running with pid 4577. The second one died after starting.

**2) Is it listening?**

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ ss -tlnp | grep 8080
LISTEN 0      4096                *:8080            *:*    users:(("quicknotes",pid=4577,fd=3))
```

Decision: port 8080 is taken by pid 4577. That is why the second instance could not bind.

**3) Reachable from host?**

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/health
200
```

Decision: the first instance works fine and answers requests. Only the second instance is broken.

**4) Firewall blocking?**

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ sudo iptables -L -n -v 2>/dev/null || sudo nft list ruleset 2>/dev/null || true
(no output - empty ruleset)
```

Decision: no firewall rules, so the firewall is not the problem.

**5) DNS?**

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ dig +short localhost
127.0.0.1
```

Decision: localhost resolves fine, DNS is not the problem too.

**Real cause:** `listen tcp :8080: bind: address already in use`. Two processes cannot listen on the same port, and the first instance with pid 4577 already took :8080.

### 2.3: Repair + re-verify

```bash
thebruh@thebruh-PC:~/DevOps-Intro/app$ kill 4577
thebruh@thebruh-PC:~/DevOps-Intro/app$ ADDR=:8080 CGO_ENABLED=0 go run . &
[1] 5086
2026/09/18 05:43:05 quicknotes listening on :8080 (notes loaded: 8)
thebruh@thebruh-PC:~/DevOps-Intro/app$ sleep 2 && curl -s http://localhost:8080/health
{"notes":8,"status":"ok"}
```

I killed the old process, started a new one, and the health check shows that the service works again.

### 2.4: Mini-postmortem

**What happened:** someone started a second QuickNotes on a port that was already taken. The OS refused to bind the port and the new process exited.

**Why this is a systemic problem:** nobody broke anything on purpose. A port is a shared resource, and nothing stops you from starting a second copy of a service. For example it can be deploy script run twice, an old running process, or two services with the same default port. This kind of failure will happen again unless the system prevents it.

**What tooling could prevent it:** add a check like `ss -tlnp | grep :8080` to the deploy script before starting or use Docker to isolate apps
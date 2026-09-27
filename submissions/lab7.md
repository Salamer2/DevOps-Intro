# Lab 7
## Task 1

### Ansible files
[Inventory](../ansible/inventory.ini) \
[Playbook](../ansible/playbook.yaml) \
[Quicknotes Template](../ansible/templates/quicknotes.service.j2)

### PLAY RECAP
```powershell
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml | tee ../Report7Run1.txt

PLAY [Deploy QuickNotes] ***************************************

TASK [Create the quicknotes system group] **************************************
changed: [lab5-vm]

TASK [Create the quicknotes system user] ***************************************
changed: [lab5-vm]

TASK [Ensure the data directory exists] ****************************************
changed: [lab5-vm]

TASK [Install the QuickNotes binary] *******************************************
changed: [lab5-vm]

TASK [Ship the seed data] ******************************************************
changed: [lab5-vm]

TASK [Render the systemd unit from template] ***********************************
changed: [lab5-vm]

TASK [Reload systemd, enable and start quicknotes] *****************************
changed: [lab5-vm]

RUNNING HANDLER [restart quicknotes] *******************************************
changed: [lab5-vm]

PLAY RECAP *********************************************************************
lab5-vm                    : ok=8    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Checking the service
```powershell
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ curl -s http://localhost:18080/health
{"notes":4,"status":"ok"}
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ curl -s http://localhost:18080/notes
[{"id":3,"title":"DevOps mantra","body":"If it hurts, do it more often.","created_at":"2026-01-15T10:10:00Z"},{"id":4,"title":"Endpoint cheat-sheet","body":"GET /notes  GET /notes/{id}  POST /notes  DELETE /notes/{id}  GET /health  GET /metrics","created_at":"2026-01-15T10:15:00Z"},{"id":1,"title":"Welcome to QuickNotes","body":"This is the project you'll containerize, deploy, monitor, and harden across all 10 labs.","created_at":"2026-01-15T10:00:00Z"},{"id":2,"title":"Read app/main.go first","body":"Start by understanding the entry point — env vars, signal handling, graceful shutdown.","created_at":"2026-01-15T10:05:00Z"}]
```

Additionally, i made a check specifically for quicknotes service. It has shown, that quicknotes, in fact, starts after system restart and is currently active.
```powershell
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ vagrant.exe ssh -c "systemctl is-enabled quicknotes && systemctl is-active quicknotes"


enabled
active
```

### Design questions
#### a) What's the difference between command: and the dedicated modules (apt, file, copy, systemd)? Which is idempotent, and why does it matter?
```command:``` just means that Ansible sends a command in a VM shell. It doesn't know and doesn't care what was before. So the command is called no matter what. Dedicated modules, however, do check the current state and compares it with the desired state, and does the command only if it's required. \
Therefore, dedicated modules are idempotent. It is important, because server will be the same no matter how much time you restart it. Even if some files/rules/users/gropus/e.t.c. are broken - they will be corrected during the next run.
#### b) notify: and handlers: when does a handler fire? When does it not fire? Why is that the right default?
Handler fires if at least one task with ```notify: restart quicknotes``` returned ```changed```. It does not fire if the task is not calling notify. One of the important things is that it fires only one time at the  end, even if many tasks called it. It is the right default, because restarting the service is expensive and it leads to the temporal service disruption. Some data might be lost too. So it should be restarted only if it is necessary.
#### c) Variable hierarchy: Ansible has at least 22 levels of variable precedence. List the top 3 places you'd put a variable for this lab (defaults, group_vars, playbook vars, …) and why.
First of all, I chosen one place for this lab - inside ```playbook.yaml``` in ```vars:``` block. It is simple and readable, for this lab that's perfect because I have only one playbook. If I had several hosts that require the same variables - I would use group_vars. In the end, I would use defaults to set up basic variables. They have much smaller priority and will be overridden by group_vars and playbook vars. However, basic variables are good just to make sure, that unspecified variables will be relatively adequate.
#### d) gather_facts: true is the default. Do you need it for this playbook? What does turning it off save you per run?
No, i don't need it. Nothing in this play uses system info. Disabling it saves a little CPU time during each run. 

## Task 2

### Reloading one more time
```powershell
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml | tee ../Report7Run2.txt

PLAY [Deploy QuickNotes] *******************************************************

TASK [Create the quicknotes system group] **************************************
ok: [lab5-vm]

TASK [Create the quicknotes system user] ***************************************
ok: [lab5-vm]

TASK [Ensure the data directory exists] ****************************************
ok: [lab5-vm]

TASK [Install the QuickNotes binary] *******************************************
ok: [lab5-vm]

TASK [Ship the seed data] ******************************************************
ok: [lab5-vm]

TASK [Render the systemd unit from template] ***********************************
ok: [lab5-vm]

TASK [Reload systemd, enable and start quicknotes] *****************************
ok: [lab5-vm]

PLAY RECAP *********************************************************************
lab5-vm                    : ok=7    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Everything as expected. Nothing changed, so all tasks reported ok. Therefore, handler also wasn't called

### Changing something
I changed ```quicknotes_listen_addr: ":8080"``` to ```quicknotes_listen_addr: ":9090"```
```powershell
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml | tee ../Report7Run3.txt

PLAY [Deploy QuickNotes] *******************************************************

TASK [Create the quicknotes system group] **************************************
ok: [lab5-vm]

TASK [Create the quicknotes system user] ***************************************
ok: [lab5-vm]

TASK [Ensure the data directory exists] ****************************************
ok: [lab5-vm]

TASK [Install the QuickNotes binary] *******************************************
ok: [lab5-vm]

TASK [Ship the seed data] ******************************************************
ok: [lab5-vm]

TASK [Render the systemd unit from template] ***********************************
changed: [lab5-vm]

TASK [Reload systemd, enable and start quicknotes] *****************************
ok: [lab5-vm]

RUNNING HANDLER [restart quicknotes] *******************************************
changed: [lab5-vm]

PLAY RECAP *********************************************************************
lab5-vm                    : ok=8    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Task ```Render the systemd unit from template``` detected a change and also called a ```restart quicknotes``` handler.

### --check --diff
Now let's return the 8080 port and change something, for example ```quicknotes_restart_sec```
```
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml --check --diff
```
```diff
--- before: /etc/systemd/system/quicknotes.service
+++ after: /home/thebruh/.ansible/tmp/ansible-local-41044vhhmvpa/tmp_212yjpn/quicknotes.service.j2
@@ -9,12 +9,12 @@
 User=quicknotes
 Group=quicknotes
 WorkingDirectory=/var/lib/quicknotes
-Environment=ADDR=:9090
+Environment=ADDR=:8080
 Environment=DATA_PATH=/var/lib/quicknotes/notes.json
 Environment=SEED_PATH=/var/lib/quicknotes/seed.json
 ExecStart=/usr/local/bin/quicknotes
 Restart=on-failure
-RestartSec=2s
+RestartSec=4s
 NoNewPrivileges=true
 PrivateTmp=true
```
Difference is correct. After that, to apply changes i again run ```ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml```, already without ```--check --diff```
### Design questions
#### e) Why does the second run report changed=0? What specifically does the file / template module check to decide?
Each module compares desired and the current state. For example, ```ansible.builtin.file``` checks if the file exists, checks the group, the owner, mode. ```ansible.builtin.template``` takes .j2 file and places the variables to make new .service file, then compares the resulted file to the .service file saved on VM. it reports changed=1 if they differ and changed=0 if they are the same. ```ansible.builtin.template``` also checks permissions, same as ```ansible.builtin.file``` and lastly it checks if the file exists at all.

#### f) What would happen if you used shell: 'echo "ADDR=..." > /etc/systemd/system/quicknotes.service' instead of the template: module? Trace the failure modes
That's a completely wrong thing to do, because it destroys the whole idea of a template. Instead of generating it, you will be manually making it, which is a wrong approach. Secondly, it also destroys the idea of idempotency, since ```shell:``` always returns ```changed=1```, moreover, it will force ```restart quicknotes``` each time. At third, this is not atomic. echo will firstly clear the file, and then write, it won't be making any copies, and if this process will be interrupted or crashed, that will result in a corrupted .service file. Lastly it overcomplicates the syntax, since writing a big file in one line can cause problems with some special symbols.

#### g) ansible-playbook --check is dry-run. --diff shows changes. What's the bug you'd catch by running --check --diff before a production deploy that you'd miss with plain --check?
The main problem is that ```--check``` doesn't tell whether the change is correct or not, it will just say that there was some change. With ```--diff``` you will be able to spot syntax errors or typos, by seeing what exactly has changed.
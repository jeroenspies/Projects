# Results

Run: https://github.com/jeroenspies/Projects/actions/runs/36409428008

Commit: `70e92e0711db85ec65f5a87d64df10515b9f4ff8`

UTC:

- Run created: 2026-09-28T10:23:35Z
- Run completed: 2026-09-28T10:27:14Z
- gitleaks: 2026-09-28T10:23:38Z – 2026-09-28T10:23:43Z
- shellcheck: 2026-09-28T10:23:38Z – 2026-09-28T10:23:47Z
- docker demos: 2026-09-28T10:23:38Z – 2026-09-28T10:24:27Z
- kind demos: 2026-09-28T10:23:38Z – 2026-09-28T10:27:13Z

Command and output below are copied from the artifacts of that run.

## pair1-chroot-privileged

## Pair 1: chroot and capabilities

### --cap-drop ALL

Command:

```
docker run --rm --cap-drop ALL unix-lessons-pair1:local /usr/local/bin/observe.sh
```

Output:

```
OBS ID=uid=0(root) gid=0(root) groups=0(root)
OBS CAPLINE CapInh:	0000000000000000
OBS CAPLINE CapPrm:	0000000000000000
OBS CAPLINE CapEff:	0000000000000000
OBS CAPLINE CapBnd:	0000000000000000
OBS CAPLINE CapAmb:	0000000000000000
OBS CAPEFF_HEX=0000000000000000
OBS CAPPRM_HEX=0000000000000000
OBS CAPBND_HEX=0000000000000000
OBS CAPAMB_HEX=0000000000000000
OBS CAPEFF_DECODED=0x0000000000000000=
OBS NONEWPRIVS=0
OBS DEV_COUNT=15
OBS MOUNT_COUNT=24
OBS UNPRIV_PORT_START=0
OBS APPARMOR=docker-default (enforce)
OBS ID_FILE_WRITTEN=/tmp/id-proof
```

### --cap-drop ALL --cap-add NET_BIND_SERVICE

Command:

```
docker run --rm --cap-drop ALL --cap-add NET_BIND_SERVICE unix-lessons-pair1:local /usr/local/bin/observe.sh
```

Output:

```
OBS ID=uid=0(root) gid=0(root) groups=0(root)
OBS CAPLINE CapInh:	0000000000000000
OBS CAPLINE CapPrm:	0000000000000400
OBS CAPLINE CapEff:	0000000000000400
OBS CAPLINE CapBnd:	0000000000000400
OBS CAPLINE CapAmb:	0000000000000000
OBS CAPEFF_HEX=0000000000000400
OBS CAPPRM_HEX=0000000000000400
OBS CAPBND_HEX=0000000000000400
OBS CAPAMB_HEX=0000000000000000
OBS CAPEFF_DECODED=0x0000000000000400=cap_net_bind_service
OBS NONEWPRIVS=0
OBS DEV_COUNT=15
OBS MOUNT_COUNT=24
OBS UNPRIV_PORT_START=0
OBS APPARMOR=docker-default (enforce)
OBS ID_FILE_WRITTEN=/tmp/id-proof
```

### --privileged

Command:

```
docker run --rm --privileged unix-lessons-pair1:local /usr/local/bin/observe.sh
```

Output:

```
OBS ID=uid=0(root) gid=0(root) groups=0(root)
OBS CAPLINE CapInh:	0000000000000000
OBS CAPLINE CapPrm:	000001ffffffffff
OBS CAPLINE CapEff:	000001ffffffffff
OBS CAPLINE CapBnd:	000001ffffffffff
OBS CAPLINE CapAmb:	0000000000000000
OBS CAPEFF_HEX=000001ffffffffff
OBS CAPPRM_HEX=000001ffffffffff
OBS CAPBND_HEX=000001ffffffffff
OBS CAPAMB_HEX=0000000000000000
OBS CAPEFF_DECODED=0x000001ffffffffff=cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_linux_immutable,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_module,cap_sys_rawio,cap_sys_chroot,cap_sys_ptrace,cap_sys_pacct,cap_sys_admin,cap_sys_boot,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_sys_tty_config,cap_mknod,cap_lease,cap_audit_write,cap_audit_control,cap_setfcap,cap_mac_override,cap_mac_admin,cap_syslog,cap_wake_alarm,cap_block_suspend,cap_audit_read,cap_perfmon,cap_bpf,cap_checkpoint_restore
OBS NONEWPRIVS=0
OBS DEV_COUNT=189
OBS MOUNT_COUNT=11
OBS UNPRIV_PORT_START=0
OBS APPARMOR=unconfined
OBS ID_FILE_WRITTEN=/tmp/id-proof
```

## pair2-sudoers-create-pods

## Pair 2: sudoers

### sudoers

Command:

```
docker run --rm unix-lessons-pair2:local /usr/local/bin/run-inside.sh
```

Output:

````
## Pair 2: sudoers

sudo version:
```
Sudo version 1.9.13p3
Configure options: --build=x86_64-linux-gnu --prefix=/usr --includedir=${prefix}/include --mandir=${prefix}/share/man --infodir=${prefix}/share/info --sysconfdir=/etc --localstatedir=/var --disable-option-checking --disable-silent-rules --libdir=${prefix}/lib/x86_64-linux-gnu --runstatedir=/run --disable-maintainer-mode --disable-dependency-tracking --with-all-insults --with-pam --with-pam-login --with-fqdn --with-logging=syslog --with-logfac=authpriv --with-env-editor --with-editor=/usr/bin/editor --with-timeout=15 --with-password-timeout=0 --with-passprompt=[sudo] password for %p:  --with-tty-tickets --without-lecture --disable-root-mailer --with-sendmail=/usr/sbin/sendmail --with-rundir=/run/sudo --with-sssd --with-sssd-lib=/usr/lib/x86_64-linux-gnu --enable-zlib=system --enable-admin-flag --with-selinux --with-linux-audit --enable-tmpfiles.d=/usr/lib/tmpfiles.d MVPROG=/bin/mv --with-exampledir=/usr/share/doc/sudo/examples
Sudoers policy plugin version 1.9.13p3
```

### sudo -l

```
Matching Defaults entries for testuser on db8cdbaa4dd3:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin, use_pty, !requiretty, !use_pty, !lecture, editor=/usr/local/bin/editor-id

User testuser may run the following commands on db8cdbaa4dd3:
    (root) NOPASSWD: /usr/bin/less
    (root) NOPASSWD: /usr/local/bin/try-exec
    (root) NOEXEC: NOPASSWD: /usr/local/bin/try-exec-noexec
    (root) NOPASSWD: sudoedit /etc/hostname
```

less is installed at /usr/bin/less and is not executed.
Shell escapes for that rule are documented at https://gtfobins.github.io/gtfobins/less/ and are not reproduced here.

### exec /bin/true via sudo

try-exec without NOEXEC: exit 0
try-exec with NOEXEC: exit 11
exec /bin/true failed: Permission denied (errno=13)
NOEXEC_RESULT=blocked execve with EACCES (errno 13), not EPERM (exit 11)

### sudoedit

Editor id (must be the invoking user, not root):
```
uid=1000(testuser) gid=1000(testuser) groups=1000(testuser)
```

sudoedit left /etc/hostname unchanged (d95854161731c428d199b490ab3605b386e81c88f63752b42c80322535d1d484  /etc/hostname).

| Check | Result |
| --- | --- |
| `sudo -l` lists `NOPASSWD: /usr/bin/less` | yes |
| `sudo -l` lists `NOEXEC: /usr/local/bin/try-exec-noexec` | yes |
| helper without NOEXEC execs `/bin/true` | exit 0 |
| helper with NOEXEC | blocked execve with EACCES (errno 13), not EPERM (exit 11) |
| sudoedit editor uid | 1000 |

Pair 2 sudo assertions passed.
````

## Pair 2: RBAC and admission

### Pod Security

Command:

```
kubectl apply -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/privileged-pod.yaml
```

Output:

```
Error from server (Forbidden): error when creating "/home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/privileged-pod.yaml": pods "privileged-rejected" is forbidden: violates PodSecurity "restricted:latest": privileged (container "app" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

### other-sa before the binding

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa.yaml --as=dev-user
```

Output:

```
pod/use-other-sa created
```

### other-sa before the binding, policy unbound

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa.yaml --as=dev-user
```

Output:

```
pod/use-other-sa created
```

### other-sa after the binding

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa.yaml --as=dev-user
```

Output:

```
The pods "use-other-sa" is invalid: : ValidatingAdmissionPolicy 'pods-only-own-serviceaccount' with binding 'pods-only-own-serviceaccount' denied request: Pods in this namespace may only use service account default or app.
```

## pair3-writable-script-mutable-config

## Pair 3: writable script

### writable script

Command:

```
docker run --rm unix-lessons-pair3:local /usr/local/bin/run-inside.sh
```

Output:

````
## Pair 3: writable script run by root

Non-root user: uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)
### Writable script

Mode of /opt/job.sh:
-rwxrwxrwx 1 root root 37 Sep 28 10:24 /opt/job.sh

Script contents after the non-root append:
```
#!/bin/sh
echo tick

id > /tmp/proof
```

Contents of /tmp/proof (written by the root loop):
```
uid=0(root) gid=0(root) groups=0(root)
```

### Fixed script

drwxr-xr-x 2 root root 4096 Sep 28 10:24 /opt/fixed
-rwxr-xr-x 1 root root 26 Sep 28 10:24 /opt/fixed/job.sh

Append exit 2:
sh: 1: cannot create /opt/fixed/job.sh: Permission denied
Create exit 1:
touch: cannot touch '/opt/fixed/evil.sh': Permission denied

| Setup | Non-root write | What ran |
| --- | --- | --- |
| `/opt/job.sh` mode 0777 | append succeeded | root loop wrote `uid=0(root)` to `/tmp/proof` |
| `/opt/fixed/job.sh` root:root 0755 in a root-only directory | permission denied | file unchanged |

Pair 3 container assertions passed.
````

## Pair 3: ConfigMap script and image reference

### SCRIPT_VERSION one

Command:

```
kubectl logs -n reports job/version-one
```

Output:

```
SCRIPT_VERSION=one
```

### SCRIPT_VERSION two

Command:

```
kubectl logs -n reports job/version-two
```

Output:

```
SCRIPT_VERSION=two
```

## pair4-docker-group-socket

## Pair 4: docker group and socket metadata

### ls

Command:

```
ls -l /var/run/docker.sock
```

Output:

```
srw-rw---- 1 root docker 0 Sep 28 10:21 /var/run/docker.sock
```

### stat

Command:

```
stat -c %A\ %a\ %U\ %G\ %F /var/run/docker.sock
```

Output:

```
srw-rw---- 660 root docker socket
```

### id

Command:

```
id
```

Output:

```
uid=1001(runner) gid=1001(runner) groups=1001(runner),4(adm),100(users),118(docker),999(systemd-journal)
```

### groups

Command:

```
id -nG
```

Output:

```
runner adm users docker systemd-journal
```

## Pair 4: socket hostPath admission

### Pod Security socket-baseline

Command:

```
kubectl apply --dry-run=server -n socket-baseline -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair4-docker-group-socket/manifests/socket-pod.yaml
```

Output:

```
Error from server (Forbidden): error when creating "/home/runner/work/Projects/Projects/unix-lessons-containers/pair4-docker-group-socket/manifests/socket-pod.yaml": pods "docker-socket" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "dockersock")
```

### Pod Security socket-restricted

Command:

```
kubectl apply --dry-run=server -n socket-restricted -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair4-docker-group-socket/manifests/socket-pod.yaml
```

Output:

```
Error from server (Forbidden): error when creating "/home/runner/work/Projects/Projects/unix-lessons-containers/pair4-docker-group-socket/manifests/socket-pod.yaml": pods "docker-socket" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), restricted volume types (volume "dockersock" uses restricted volume type "hostPath"), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```


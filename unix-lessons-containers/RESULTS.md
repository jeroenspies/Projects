# Results

Run: https://github.com/jeroenspies/Projects/actions/runs/36454642570

Commit: `aaae35e1a00fe560063f52a01a7719a6ae7e4c26`

UTC:

- Run created: 2026-09-28T16:56:39Z
- Run completed: 2026-09-28T17:00:27Z
- shellcheck: 2026-09-28T16:56:43Z – 2026-09-28T16:56:52Z
- gitleaks: 2026-09-28T16:56:42Z – 2026-09-28T16:56:48Z
- docker demos: 2026-09-28T16:56:42Z – 2026-09-28T16:57:23Z
- kind demos: 2026-09-28T16:56:42Z – 2026-09-28T17:00:27Z

Note, outside the transcripts: The /dev count under `--privileged` depends on the host. Run 36409428008 recorded `OBS DEV_COUNT=189`. Run 36412260734 recorded `OBS DEV_COUNT=188`. This run recorded `OBS DEV_COUNT=189`.

Command and output below are copied from the artifacts of that run.

## Environment

## Environment (docker)

### docker version

Command:

```
docker version
```

Output:

```
Client: Docker Engine - Community
 Version:           28.0.4
 API version:       1.48
 Go version:        go1.23.7
 Git commit:        b8034c0
 Built:             Tue Mar 25 15:07:16 2025
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          28.0.4
  API version:      1.48 (minimum version 1.24)
  Go version:       go1.23.7
  Git commit:       6430e49
  Built:            Tue Mar 25 15:07:16 2025
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v2.3.5
  GitCommit:        1294c24a7da8e5a793ed378161673abe94118892
 runc:
  Version:          1.5.1
  GitCommit:        v1.5.1-0-g8f2685a4
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

Exit 0.

## Environment (kind)

### docker version

Command:

```
docker version
```

Output:

```
Client: Docker Engine - Community
 Version:           28.0.4
 API version:       1.48
 Go version:        go1.23.7
 Git commit:        b8034c0
 Built:             Tue Mar 25 15:07:16 2025
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          28.0.4
  API version:      1.48 (minimum version 1.24)
  Go version:       go1.23.7
  Git commit:       6430e49
  Built:            Tue Mar 25 15:07:16 2025
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v2.3.5
  GitCommit:        1294c24a7da8e5a793ed378161673abe94118892
 runc:
  Version:          1.5.1
  GitCommit:        v1.5.1-0-g8f2685a4
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

Exit 0.

### kind version

Command:

```
kind version
```

Output:

```
kind v0.33.0 go1.26.7 linux/amd64
```

Exit 0.

### kind node image

Command:

```
docker inspect unix-lessons-control-plane --format \{\{.Config.Image\}\}
```

Output:

```
kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d
```

Exit 0.

### kind node image digests

Command:

```
docker image inspect kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d --format \{\{json\ .RepoTags\}\}\{\{\"\\n\"\}\}\{\{json\ .RepoDigests\}\}
```

Output:

```
[]
["kindest/node@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d"]
```

Exit 0.

### kubectl version

Command:

```
kubectl version
```

Output:

```
Client Version: v1.34.11
Kustomize Version: v5.7.1
Server Version: v1.34.11
```

Exit 0.

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

Exit 0.

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

Exit 0.

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

Exit 0.

### --cap-drop ALL --security-opt no-new-privileges

Command:

```
docker run --rm --cap-drop ALL --security-opt no-new-privileges unix-lessons-pair1:local /usr/local/bin/observe.sh
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
OBS NONEWPRIVS=1
OBS DEV_COUNT=15
OBS MOUNT_COUNT=24
OBS UNPRIV_PORT_START=0
OBS APPARMOR=docker-default (enforce)
OBS ID_FILE_WRITTEN=/tmp/id-proof
```

Exit 0.

### default capability set

Command:

```
docker run --rm unix-lessons-pair1:local /usr/local/bin/observe.sh
```

Output:

```
OBS ID=uid=0(root) gid=0(root) groups=0(root)
OBS CAPLINE CapInh:	0000000000000000
OBS CAPLINE CapPrm:	00000000a80425fb
OBS CAPLINE CapEff:	00000000a80425fb
OBS CAPLINE CapBnd:	00000000a80425fb
OBS CAPLINE CapAmb:	0000000000000000
OBS CAPEFF_HEX=00000000a80425fb
OBS CAPPRM_HEX=00000000a80425fb
OBS CAPBND_HEX=00000000a80425fb
OBS CAPAMB_HEX=0000000000000000
OBS CAPEFF_DECODED=0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
OBS NONEWPRIVS=0
OBS DEV_COUNT=15
OBS MOUNT_COUNT=24
OBS UNPRIV_PORT_START=0
OBS APPARMOR=docker-default (enforce)
OBS ID_FILE_WRITTEN=/tmp/id-proof
```

Exit 0.

### non-root bind80

Command:

```
docker run --rm --user 1000:1000 unix-lessons-pair1:local /usr/local/bin/bind80
```

Output:

```
bind 127.0.0.1:80: ok
```

Exit 0.

### root bind80 --cap-drop NET_BIND_SERVICE

Command:

```
docker run --rm --cap-drop NET_BIND_SERVICE --sysctl net.ipv4.ip_unprivileged_port_start=1024 unix-lessons-pair1:local /usr/local/bin/bind80
```

Output:

```
bind: Permission denied (errno=13)
```

Exit 10.

### root bind80 default capabilities

Command:

```
docker run --rm --sysctl net.ipv4.ip_unprivileged_port_start=1024 unix-lessons-pair1:local /usr/local/bin/bind80
```

Output:

```
bind 127.0.0.1:80: ok
```

Exit 0.

### chroot --cap-drop ALL

Command:

```
docker run --rm --cap-drop ALL unix-lessons-pair1:local /usr/local/bin/try-chroot
```

Output:

```
chroot: Operation not permitted (errno=1)
```

Exit 10.

### chroot --cap-drop ALL --cap-add SYS_CHROOT

Command:

```
docker run --rm --cap-drop ALL --cap-add SYS_CHROOT unix-lessons-pair1:local /usr/local/bin/try-chroot
```

Output:

```
chroot: ok
```

Exit 0.

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
Matching Defaults entries for testuser on 1a2b9a1cd150:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin, use_pty, !requiretty, !use_pty, !lecture, editor=/usr/local/bin/editor-id

User testuser may run the following commands on 1a2b9a1cd150:
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

sudoedit left /etc/hostname unchanged (1dc6cc4bb204e8fa6a36ada050779f0d3fe32de57e3a69aac9e87705549a68f9  /etc/hostname).

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

### create pods as dev-user

| Check | Before RoleBinding | After RoleBinding |
| --- | --- | --- |
| `create pods` as dev-user | no | yes |
| `get secrets` as dev-user | no | no |
| `get pods` as dev-user | no | no |

### can-i get pods as reader

Command:

```
kubectl auth can-i get pods -n team-a --as=reader
```

Output:

```
yes
```

Exit 0.

### can-i list deployments as reader

Command:

```
kubectl auth can-i list deployments -n team-a --as=reader
```

Output:

```
yes
```

Exit 0.

### can-i get pods/log as reader

Command:

```
kubectl auth can-i get pods/log -n team-a --as=reader
```

Output:

```
yes
```

Exit 0.

### can-i create pods as reader

Command:

```
kubectl auth can-i create pods -n team-a --as=reader
```

Output:

```
no
```

Exit 1.

### can-i get secrets as reader

Command:

```
kubectl auth can-i get secrets -n team-a --as=reader
```

Output:

```
no
```

Exit 1.

### can-i patch configmaps as reader

Command:

```
kubectl auth can-i patch configmaps -n team-a --as=reader
```

Output:

```
no
```

Exit 1.

### can-i create pods/exec as reader

Command:

```
kubectl auth can-i create pods/exec -n team-a --as=reader
```

Output:

```
no
```

Exit 1.

### noncompliant Deployment

Command:

```
kubectl apply -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/deployment-noncompliant.yaml
```

Output:

```
Warning: would violate PodSecurity "restricted:latest": privileged (container "app" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
deployment.apps/noncompliant created
```

Exit 0.

### ReplicaSet event

Command:

```
kubectl get events -n team-a --field-selector reason=FailedCreate\,involvedObject.kind=ReplicaSet -o jsonpath=\{range\ .items\[\*\]\}\{.involvedObject.kind\}\{\"\ \"\}\{.involvedObject.name\}\{\"\ \"\}\{.reason\}\{\"\ \"\}\{.message\}\{\"\\n\"\}\{end\} | grep '^ReplicaSet noncompliant-'
```

Output:

```
ReplicaSet noncompliant-759949554b FailedCreate Error creating: pods "noncompliant-759949554b-h2rnr" is forbidden: violates PodSecurity "restricted:latest": privileged (container "app" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
ReplicaSet noncompliant-759949554b FailedCreate Error creating: pods "noncompliant-759949554b-zczzp" is forbidden: violates PodSecurity "restricted:latest": privileged (container "app" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
ReplicaSet noncompliant-759949554b FailedCreate Error creating: pods "noncompliant-759949554b-v6l5f" is forbidden: violates PodSecurity "restricted:latest": privileged (container "app" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
ReplicaSet noncompliant-759949554b FailedCreate Error creating: pods "noncompliant-759949554b-zwhhm" is forbidden: violates PodSecurity "restricted:latest": privileged (container "app" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

Exit 0.

### noncompliant pods

Command:

```
kubectl get pods -n team-a -l app=noncompliant --no-headers
```

Output:

```
No resources found in team-a namespace.
```

Exit 0.

### readyReplicas

Command:

```
kubectl get deploy -n team-a noncompliant -o jsonpath=\{.status.readyReplicas\}
```

Output:

```
```

Exit 0.

### other-sa before the binding

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa.yaml --as=dev-user
```

Output:

```
pod/use-other-sa created
```

Exit 0.

### other-sa before the binding, policy unbound

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa.yaml --as=dev-user
```

Output:

```
pod/use-other-sa created
```

Exit 0.

### other-sa after the binding

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa.yaml --as=dev-user
```

Output:

```
The pods "use-other-sa" is invalid: : ValidatingAdmissionPolicy 'pods-only-own-serviceaccount' with binding 'pods-only-own-serviceaccount' denied request: Pods in this namespace may only use service account default or app.
```

Exit 1.

### app service account pod

Command:

```
kubectl create -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-app-sa.yaml --as=dev-user
```

Output:

```
pod/use-app-sa created
```

Exit 0.

### serviceAccountName of the accepted pod

Command:

```
kubectl get pod -n team-a use-app-sa -o jsonpath=\{.spec.serviceAccountName\}
```

Output:

```
app
```

Exit 0.

### can-i create pods in team-b as dev-user

Command:

```
kubectl auth can-i create pods -n team-b --as=dev-user
```

Output:

```
no
```

Exit 1.

### admin creates other-sa pod in team-b

Command:

```
kubectl apply -f /home/runner/work/Projects/Projects/unix-lessons-containers/pair2-sudoers-create-pods/manifests/pod-other-sa-team-b.yaml
```

Output:

```
pod/use-other-sa created
```

Exit 0.

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
-rwxrwxrwx 1 root root 37 Sep 28 16:57 /opt/job.sh

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

drwxr-xr-x 2 root root 4096 Sep 28 16:57 /opt/fixed
-rwxr-xr-x 1 root root 26 Sep 28 16:57 /opt/fixed/job.sh

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

### can-i as cm-editor

| cm-editor | Result |
| --- | --- |
| patch configmaps | yes |
| get configmaps | no |
| update configmaps | no |

### SCRIPT_VERSION one

Command:

```
kubectl logs -n reports job/version-one
```

Output:

```
SCRIPT_VERSION=one
```

### kubectl patch --as=cm-editor

Command:

```
kubectl patch configmap report-script -n reports --as=cm-editor --type=merge --patch \{\"data\":\{\"run.sh\":\"#\!/bin/sh\\necho\ SCRIPT_VERSION=cli\\n\"\}\}
```

Output:

```
Error from server (Forbidden): configmaps "report-script" is forbidden: User "cm-editor" cannot get resource "configmaps" in API group "" in the namespace "reports"
```

Exit 1.

### API merge-patch as cm-editor

Command:

```
curl -sS -o /tmp/tmp.VsSIq1Em8F -w %\{http_code\} -X PATCH -H Content-Type:\ application/merge-patch+json -H Impersonate-User:\ cm-editor --data-binary @/tmp/tmp.XGWiHvjnv3 http://127.0.0.1:60273/api/v1/namespaces/reports/configmaps/report-script
```

Output:

```
{
  "kind": "ConfigMap",
  "apiVersion": "v1",
  "metadata": {
    "name": "report-script",
    "namespace": "reports",
    "uid": "91e4243a-a3db-46dd-a472-39bd250ad25a",
    "resourceVersion": "846",
    "creationTimestamp": "2026-09-28T17:00:07Z",
    "annotations": {
      "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"data\":{\"run.sh\":\"#!/bin/sh\\necho SCRIPT_VERSION=one\\n\"},\"kind\":\"ConfigMap\",\"metadata\":{\"annotations\":{},\"name\":\"report-script\",\"namespace\":\"reports\"}}\n"
    },
    "managedFields": [
      {
        "manager": "kubectl-client-side-apply",
        "operation": "Update",
        "apiVersion": "v1",
        "time": "2026-09-28T17:00:07Z",
        "fieldsType": "FieldsV1",
        "fieldsV1": {
          "f:data": {},
          "f:metadata": {
            "f:annotations": {
              ".": {},
              "f:kubectl.kubernetes.io/last-applied-configuration": {}
            }
          }
        }
      },
      {
        "manager": "curl",
        "operation": "Update",
        "apiVersion": "v1",
        "time": "2026-09-28T17:00:13Z",
        "fieldsType": "FieldsV1",
        "fieldsV1": {
          "f:data": {
            "f:run.sh": {}
          }
        }
      }
    ]
  },
  "data": {
    "run.sh": "#!/bin/sh\necho SCRIPT_VERSION=two\n"
  }
}
```

HTTP 200.

### SCRIPT_VERSION two

Command:

```
kubectl logs -n reports job/version-two
```

Output:

```
SCRIPT_VERSION=two
```

### admin patch of immutable ConfigMap

Command:

```
kubectl patch configmap report-script-v7 -n reports --type=merge --patch-file /tmp/tmp.LYRTCn5BWy
```

Output:

```
The ConfigMap "report-script-v7" is invalid: data: Forbidden: field is immutable when `immutable` is set
```

Exit 1.

### cm-editor API patch of immutable ConfigMap

Command:

```
curl -sS -o /tmp/tmp.e9fD1GSAKm -w %\{http_code\} -X PATCH -H Content-Type:\ application/merge-patch+json -H Impersonate-User:\ cm-editor --data-binary @/tmp/tmp.LYRTCn5BWy http://127.0.0.1:33311/api/v1/namespaces/reports/configmaps/report-script-v7
```

Output:

```
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "ConfigMap \"report-script-v7\" is invalid: data: Forbidden: field is immutable when `immutable` is set",
  "reason": "Invalid",
  "details": {
    "name": "report-script-v7",
    "kind": "ConfigMap",
    "causes": [
      {
        "reason": "FieldValueForbidden",
        "message": "Forbidden: field is immutable when `immutable` is set",
        "field": "data"
      }
    ]
  },
  "code": 422
}
```

HTTP 422.

### version-seven image

Command:

```
kubectl get cronjob -n reports nightly-report-fixed -o jsonpath=\{.spec.jobTemplate.spec.template.spec.containers\[0\].image\}
```

Output:

```
docker.io/library/busybox@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e
```

### automountServiceAccountToken

Command:

```
kubectl get cronjob -n reports nightly-report-fixed -o jsonpath=\{.spec.jobTemplate.spec.template.spec.automountServiceAccountToken\}
```

Output:

```
false
```

Exit 0.

### nightly-report-fixed securityContext

Command:

```
kubectl get cronjob -n reports nightly-report-fixed -o jsonpath=runAsUser=\{.spec.jobTemplate.spec.template.spec.containers\[0\].securityContext.runAsUser\}\{\"\\n\"\}readOnlyRootFilesystem=\{.spec.jobTemplate.spec.template.spec.containers\[0\].securityContext.readOnlyRootFilesystem\}\{\"\\n\"\}allowPrivilegeEscalation=\{.spec.jobTemplate.spec.template.spec.containers\[0\].securityContext.allowPrivilegeEscalation\}\{\"\\n\"\}drop=\{.spec.jobTemplate.spec.template.spec.containers\[0\].securityContext.capabilities.drop\[0\]\}\{\"\\n\"\}
```

Output:

```
runAsUser=65534
readOnlyRootFilesystem=true
allowPrivilegeEscalation=false
drop=ALL
```

Exit 0.

### SCRIPT_VERSION seven

Command:

```
kubectl logs -n reports job/version-seven
```

Output:

```
SCRIPT_VERSION=seven
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
srw-rw---- 1 root docker 0 Sep 28 16:55 /var/run/docker.sock
```

Exit 0.

### stat

Command:

```
stat -c %A\ %a\ %U\ %G\ %F /var/run/docker.sock
```

Output:

```
srw-rw---- 660 root docker socket
```

Exit 0.

### id

Command:

```
id
```

Output:

```
uid=1001(runner) gid=1001(runner) groups=1001(runner),4(adm),100(users),118(docker),999(systemd-journal)
```

Exit 0.

### groups

Command:

```
id -nG
```

Output:

```
runner adm users docker systemd-journal
```

Exit 0.

### sudo -n true

Command:

```
sudo -n true
```

Output:

```
```

Exit 0.

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

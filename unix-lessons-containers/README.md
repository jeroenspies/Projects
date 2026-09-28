# Unix lessons, checked in containers

Four small demos. Each one shows a **difference in privileges**: what is allowed, what is denied, and which fix narrows the permission. They do not escape a container, mount a runtime socket, scan a network, or write a payload.

Background research and demos built with AI assistants, designed and reviewed by me.

GitHub Actions runs them. The workflow is [`../.github/workflows/unix-lessons-containers.yml`](../.github/workflows/unix-lessons-containers.yml). It runs on a push to `main` that changes this directory or that workflow file, and when started manually. The job summary for each run keeps the before/after table. Each pair also writes a short transcript: the command that ran, in a code block, and the output that command printed, in a code block. The same transcript is saved as `summaries/<pair>.md` and uploaded as a workflow artifact. RESULTS.md in this directory keeps the transcripts captured from a completed run. Workflow logs and uploaded artifacts are removed after their retention period.

Captured transcripts from the recorded run: [RESULTS.md](RESULTS.md).

## Running locally

Run these demos only in CI or on a disposable VM. The Docker pair starts a `--privileged` container; the Kubernetes pairs expect a throw-away kind cluster and use its admin kubeconfig. Do not point them at a cluster you care about. Provided as-is, for education.

Each Kubernetes script calls `require_kind_context` in [`scripts/lib.sh`](scripts/lib.sh) before its first `kubectl apply`, `create`, or `patch`. The function reads `kubectl config current-context` and stops with an error unless that context is `kind-unix-lessons`, the context kind assigns to the cluster the workflow creates (`cluster_name: unix-lessons`).

## What a run never does

- No `release_agent` write, no mount breakout, and no chroot jail escape. `try-chroot` calls `chroot("/tmp")` and exits. A GitHub-hosted runner is an ephemeral VM, and its user already has passwordless sudo, so breaking out of a container there would not be an escape from GitHub's infrastructure. It would prove nothing, and it is the kind of action the GitHub terms exclude.
- No editor or pager escape. `sudo -l` lists a `NOPASSWD: /usr/bin/less` rule. The technique is cited by URL only: <https://gtfobins.github.io/gtfobins/less/>.
- No container receives `/var/run/docker.sock`. The socket pod is sent with `--dry-run=server` and must be rejected.
- No hostPath volume is created on the cluster. The kind nodes themselves run as privileged containers; that is how kind works, and the workflow records it. It is not a pattern to copy.
- Proof files (`id`, `/tmp/proof`) are written inside the demo container.

## Pair 1 — chroot and `privileged`

**Unix lesson.** `chroot(2)` changes one ingredient of pathname lookup. It is not a security boundary. Only a process with `CAP_SYS_CHROOT` may call it. `CAP_SYS_ADMIN` is the overloaded "new root" capability (it includes `mount(2)`).

**Kubernetes counterpart.** `privileged: true` drops the restrictions (capabilities, seccomp, AppArmor, devices) that make a container a boundary. Pod Security Standards Baseline forbids privileged containers, host namespaces, and hostPath. Restricted also requires `drop: ["ALL"]`, `allowPrivilegeEscalation: false`, `runAsNonRoot: true`, and an explicit seccomp profile. `allowPrivilegeEscalation` defaults to true. The value `false` cannot be combined with `privileged` or `CAP_SYS_ADMIN`, so such containers can always escalate. `false` sets the kernel `no_new_privs` flag, which also blocks file capabilities on a later exec.

**What the demo proves.** As root, three runs print `grep ^Cap /proc/self/status` and decode `CapEff` with `capsh --decode`. The three masks differ:

| Run | What is asserted |
| --- | --- |
| `--cap-drop ALL` | `CapEff` decodes to no named capability. `chroot(2)` returns EPERM. |
| `--cap-drop ALL --cap-add NET_BIND_SERVICE` | `CapEff` contains `cap_net_bind_service` and not `cap_sys_admin`. Device and mount counts stay the same as the dropped run. |
| `--privileged` | `CapEff` contains `cap_sys_admin`. `/dev` has more entries. The mount count changes: the default runtime's masked `/proc` and `/sys` mounts are absent, so the count is often lower. |
| `--security-opt no-new-privileges` | `NoNewPrivs` in `/proc/self/status` is `1` (it is `0` without the flag). |

Port 80 is a separate fact. Since Docker 20.10, a container with its own network namespace gets `net.ipv4.ip_unprivileged_port_start=0` ([moby PR 41030](https://github.com/moby/moby/pull/41030)). The demo prints that sysctl inside a default container and asserts it is `0`. A non-root bind of `127.0.0.1:80` then **succeeds** with no capability. `--cap-add NET_BIND_SERVICE` does not change that: uid 1000 still has `CapEff` 0 and an empty ambient set, because `--cap-add` does not install ambient capabilities.

The comparison that still needs the capability is a **root** process after `--sysctl net.ipv4.ip_unprivileged_port_start=1024`. `--cap-drop NET_BIND_SERVICE` makes `bind` fail. Leaving the default capability set makes it succeed. On this kernel the failure is EACCES (errno 13, `Permission denied`), not EPERM (errno 1). The job summary prints the line. A denied bind below 1024 means the capability is missing **or** the runtime did not set `ip_unprivileged_port_start=0`. Check both.

`id` is written to `/tmp/id-proof` inside the container. The bind is to loopback only, and the socket is closed immediately.

**Fix.** Drop all capabilities and add back only the one a failing syscall needs, and only for a process that will actually receive it. For a non-root listener, prefer a port above 1024 and map the Service to 80 or 443. Do not add `NET_BIND_SERVICE` and expect a non-root process to gain it. Set `allowPrivilegeEscalation: false` where it is legal. Do not reach for `privileged: true` because one call was denied.

**Limitations.** The runner's Docker daemon applies its default seccomp and AppArmor profiles (`docker-default` unless the run is `--privileged`). Those profiles can deny a syscall that a capability would otherwise allow. The workflow records the runner OS, kernel, Docker version, AppArmor state, and the profile observed inside each container. kind is not used for this pair.

## Pair 2 — sudoers and `create pods`

**Unix lesson.** After sudo runs a program, that program can run other programs. A rule that names only `/usr/bin/less` is still a broad grant. sudoers offers `NOEXEC` (on Linux, a seccomp filter or the `sudo_noexec` preload, depending on the build) and `sudoedit` (the editor runs as the invoking user on a temporary copy). `NOEXEC` is not a complete answer: a root process can still rewrite files. Never point `sudoedit` at a file in a directory the user can write.

**Kubernetes counterpart.** Permission to create pods in a namespace is permission to use the ServiceAccounts, Secrets, and ConfigMaps in that namespace. Pod Security Admission `enforce` applies to pod objects, not to the Deployment that creates them, so a bad template is stored and the pods are refused. A ValidatingAdmissionPolicy needs a binding; the policy object alone matches nothing.

**What the demo proves.**

Docker, as `testuser` (uid 1000):

- `sudo -l` lists `NOPASSWD: /usr/bin/less`, a `NOEXEC` tag on `/usr/local/bin/try-exec-noexec` (sudo prints it as `NOEXEC: NOPASSWD: ...`), and `sudoedit /etc/hostname`. `less` is not executed.
- `/usr/local/bin/try-exec` is a small program that `exec`s `/bin/true`. Without `NOEXEC` the exec succeeds.
- The same program, selected by the `NOEXEC` rule, must report whether exec was blocked. The container prints `NOEXEC_RESULT=...`. Debian bookworm's sudo 1.9.13 fails that `execve` with EACCES (errno 13, `Permission denied`), not with EPERM (errno 1). The helper's exit 10 is reserved for EPERM, so this build reports the EACCES result and the demo still passes. If a sudo build does not block the exec at all, the log says so. The result is not forced.
- `sudoedit` runs `/usr/local/bin/editor-id`, which writes `id` to `/tmp/sudoedit-id`. The demo asserts uid 1000 and that `/etc/hostname` is unchanged.

kind (Kubernetes 1.34.11 node image, kind v0.33.0), namespace `team-a` labeled `pod-security.kubernetes.io/enforce=restricted`:

- A pod with `privileged: true` is rejected. The pod object is not stored. No permissive namespace is given a privileged pod.
- `kubectl auth can-i create pods --as=dev-user` is `no` before a RoleBinding and `yes` after a Role that allows only `create` on pods. `get secrets` stays `no`.
- The `developer-readonly` Role allows get/list/watch of pods, logs, deployments, jobs, cronjobs, and configmaps. ConfigMaps and `pods/log` can contain sensitive data; consider omitting them. The Role does not allow create, secrets, patch, or `pods/exec`.
- A Deployment whose template sets `privileged: true` is accepted with a PodSecurity warning. Its pods are not created. The ReplicaSet event is copied into the job summary.
- `dev-user` can create a restricted pod that sets `serviceAccountName: other-sa`. That still works after the ValidatingAdmissionPolicy object exists and before its binding exists.
- The policy does nothing until this binding is applied (`snippets/vap-binding.yaml`). `validationActions` is `Deny`. The namespace selector is `kubernetes.io/metadata.name=team-a`. The same pod is then rejected. A pod that uses ServiceAccount `app` is still accepted. The same shape in namespace `team-b` is not selected.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: pods-only-own-serviceaccount
spec:
  policyName: pods-only-own-serviceaccount
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: team-a
```

**Fix.** Do not grant people `create` or `patch` on pods. Give them a read-only Role and ship changes through review. Enforce restricted Pod Security on the namespace. Bind an admission policy when the question is "which ServiceAccount may this pod use?" — Pod Security does not answer that. Set `automountServiceAccountToken: false` when the process does not call the API.

**Limitations.** `NOEXEC` depends on the sudo build inside the image (Debian bookworm's `sudo` package), which the log prints. kind's node container is privileged on the runner; the demo pods are not. Impersonation (`--as`) uses the kind admin kubeconfig; the users `dev-user` and `reader` are not cluster identities beyond RBAC.

## Pair 3 — a writable script that a stronger identity runs

**Unix lesson.** The dangerous part is not the scheduler. It is a file that a stronger identity executes and a weaker identity can change. Mode `0777` on a root-run script is that pattern. The fix on a single host is `root:root` mode `0755` in a directory only root can write.

**Kubernetes counterpart.** A CronJob that runs `image: something:latest`, or that mounts a ConfigMap other people can `patch`, is the same trust boundary: the writer is not the runner. hostPath is a different problem (the pod writes the node) and is not demonstrated. Tags move; digests do not. A ConfigMap can be marked `immutable: true`; the next version is a new name.

**What the demo proves.**

Docker: a root loop runs `/opt/job.sh` once a second. The file is mode `0777`. `appuser` (uid 1000) appends `id > /tmp/proof`. The proof file, still inside the container, contains `uid=0(root)`. The fixed file is `root:root` `0755` under `/opt/fixed` (`0755`, root-owned). The same append and a `touch` in that directory are denied, and the script bytes do not change.

kind, namespace `reports` with `enforce=restricted`:

- CronJob `nightly-report` uses the tag `docker.io/library/busybox:1.37.0` and ConfigMap `report-script`. A Job created with `kubectl create job --from=cronjob/nightly-report` prints `SCRIPT_VERSION=one`. The schedule is not waited on.
- User `cm-editor` has only the `patch` verb on configmaps (`get` and `update` are `no`). `kubectl patch` as that user is recorded separately: the kubectl client GETs the object before it PATCHes, so a get-less user is rejected by the client. The demo then sends `PATCH` with `Impersonate-User: cm-editor` and no GET. That request succeeds. The next Job prints `SCRIPT_VERSION=two`.
- ConfigMap `report-script-v7` is `immutable: true`. A patch is rejected, including a patch from `cm-editor`. CronJob `nightly-report-fixed` pins `docker.io/library/busybox@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e`, uses that ConfigMap, runs as uid 65534, drops all capabilities, sets `allowPrivilegeEscalation: false` and `readOnlyRootFilesystem: true`, and sets `automountServiceAccountToken: false` on ServiceAccount `report-runner`. Its Job prints `SCRIPT_VERSION=seven`.

The tag is not retargeted in a registry. The digest in the fixed spec is the property under test.

**Fix.** `immutable: true` and a new ConfigMap name per version. Pin images by digest. Run the namespace at restricted Pod Security, with its own ServiceAccount and no API token unless the process calls the API. On a host, root-owned mode `0755` in a root-owned directory.

**Limitations.** A ConfigMap mounted into an already running pod updates eventually (kubelet sync). These Jobs are new pods, so they read the current object. busybox's image user is root, so `runAsNonRoot: true` without a numeric `runAsUser` is not enough to start the container; the working CronJobs set `runAsUser: 65534`. See [YAML_VALIDATION.md](YAML_VALIDATION.md).

## Pair 4 — the docker group and the socket

**Unix lesson.** Membership of the `docker` group is root-level control of the daemon.

**Kubernetes counterpart.** A pod that mounts the runtime socket, or any hostPath, is the same reflex: "permission denied on the socket, so mount the socket." Baseline and Restricted both forbid hostPath.

**What the demo proves.** On the runner it prints `ls -l /var/run/docker.sock`, `id`, and whether that user is in group `docker`. It also runs `sudo -n true` and records the exit code. The runner user can already become root via sudo: GitHub-hosted runners use passwordless sudo ([GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)). Group membership in `docker` is recorded from `id`, not assumed. In kind, a pod whose only extra is `hostPath: /var/run/docker.sock` is rejected by baseline and by restricted. The request is `--dry-run=server`. The pod is never stored, and the socket is never mounted.

**Fix.** Do not mount a runtime socket into a workload. Treat the `docker` group like sudo. Enforce Baseline or Restricted on the namespace.

**Limitations.** Passwordless sudo on the runner means a container breakout on that VM would not show a new privilege. The job summary records the actual `id` line and the `sudo -n true` result. The socket is not mounted, and sudo is not used for anything except `true`.

## Snippets

[YAML_VALIDATION.md](YAML_VALIDATION.md) lists each snippet, what had to change before it could be applied, and what the cluster did with it. Only behaviors seen in CI belong in that file.

## Sources

- <https://man7.org/linux/man-pages/man2/chroot.2.html>
- <https://man7.org/linux/man-pages/man7/capabilities.7.html>
- <https://man7.org/linux/man-pages/man5/proc_pid_status.5.html>
- <https://man7.org/linux/man-pages/man1/capsh.1.html>
- <https://man7.org/linux/man-pages/man5/crontab.5.html>
- <https://www.kernel.org/doc/html/latest/userspace-api/no_new_privs.html>
- <https://www.sudo.ws/docs/man/sudoers.man/>
- <https://gtfobins.github.io/gtfobins/less/>
- <https://kubernetes.io/docs/concepts/security/pod-security-standards/>
- <https://kubernetes.io/docs/concepts/security/pod-security-admission/>
- <https://kubernetes.io/docs/concepts/security/rbac-good-practices/>
- <https://kubernetes.io/docs/reference/access-authn-authz/authorization/>
- <https://kubernetes.io/docs/tasks/configure-pod-container/security-context/>
- <https://kubernetes.io/docs/concepts/storage/volumes/#hostpath>
- <https://kubernetes.io/docs/concepts/containers/images/>
- <https://kubernetes.io/docs/concepts/configuration/configmap/>
- <https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/>
- <https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/>
- <https://docs.docker.com/engine/security/>
- <https://docs.docker.com/engine/install/linux-postinstall/>
- <https://github.com/moby/moby/pull/41030>
- <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>
- <https://attack.mitre.org/techniques/T1053/003/>
- <https://github.com/helm/kind-action>

Pinned in CI: kind v0.33.0, `kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d`, kubectl v1.34.11, busybox `1.37.0` / `sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e`, Debian bookworm-slim `sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251`. Actions are pinned by commit SHA in the workflow file.

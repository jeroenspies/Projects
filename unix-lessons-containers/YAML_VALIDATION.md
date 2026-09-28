# YAML snippet validation

The files in [`snippets/`](snippets/) are the manifests exercised on the kind cluster. `validate-snippets.sh` applies them and prints the API and kubelet output to the workflow job summary. This page records what changed before apply, and the cluster behavior once a run has been observed.

The kind job uses kind v0.33.0 and `kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d`.

## Before the first apply

These edits are in the files themselves. They are not cluster results.

| Snippet | File | Change | Why |
| --- | --- | --- | --- |
| Namespace labels | `snippets/namespace-team-a.yaml` | Wording of the inline comment only. Labels and name are unchanged. | Keep the tree in English. |
| `developer-readonly` Role | `snippets/role-developer-readonly.yaml` | The comment under the rule is in English. A line notes that configmaps and pods/log can contain sensitive data. The rule body is unchanged. | Keep the tree in English, and record that those two resources are optional. |
| Restricted `securityContext` | `snippets/restricted-pod.yaml` | Wrapped in a Pod (`restricted-snippet` / `team-a`). Image `registry.example/app@sha256:...` replaced with `docker.io/library/busybox@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e`. No command was added. `add: ["NET_BIND_SERVICE"]` was removed. The comment now says a non-root port below 1024 does not need that capability when `ip_unprivileged_port_start=0`, and that adding a capability does not reach a non-root effective set. | The sketch was a fragment. The placeholder image is not a registry reference. The capability add does not do what the old comment implied. |
| ValidatingAdmissionPolicy | `snippets/vap.yaml` and `snippets/vap-binding.yaml` | The denial message is English. The CEL expression is unchanged. The binding (`validationActions: [Deny]`, namespace selector `kubernetes.io/metadata.name=team-a`) is the companion file. | The sketch had no binding, so the policy matched nothing. |
| CronJob | `snippets/cronjob.yaml` | Image `registry.example/report@sha256:<digest>` replaced with the busybox digest above. Comments translated. No command, `runAsUser`, or ConfigMap object was added. | The placeholder cannot be pulled. `immutable: true` in the source was a comment on the volume, not a ConfigMap field. |

## Observed on the cluster

Recorded from kind v0.33.0 with node `v1.34.11` (the image pin above). Pod Security Admission accepted every object below; the failures are from the job controller or the kubelet.

| Snippet | What the cluster did |
| --- | --- |
| Namespace `team-a` | Accepted. Labels `enforce` / `warn` / `audit` = `restricted` and `enforce-version=latest` were stored. |
| Role `developer-readonly` | Accepted. Pair 2 then bound it to user `reader`: `get pods`, `list deployments`, and `get pods/log` were `yes`; `create pods`, `get secrets`, `patch configmaps`, and `create pods/exec` were `no`. |
| Pod `restricted-snippet` | After `add: ["NET_BIND_SERVICE"]` was removed, the API still accepted the pod. The kubelet stayed in `CreateContainerConfigError`: `container has runAsNonRoot and image will run as root`. `runAsUser` is unset and that image's user is root. The container never started, so `readOnlyRootFilesystem` was not exercised and no emptyDir was required for `/tmp`. An earlier run, while the add line was still present, failed the same way (restricted allows that one added capability). Pair 1 shows `--cap-add NET_BIND_SERVICE` leaves a non-root `CapEff` at 0. |
| ValidatingAdmissionPolicy `pods-only-own-serviceaccount` | The policy object was accepted with no binding. A later create of a pod with `serviceAccountName: other-sa` in `team-a` succeeded while the policy was unbound. After `snippets/vap-binding.yaml` (`validationActions: [Deny]`, namespace selector `kubernetes.io/metadata.name=team-a`), the same create was denied with that policy and binding name. A pod using ServiceAccount `app` was still accepted. The same shape in namespace `team-b` was not selected by the binding. |
| CronJob `nightly-report` | The CronJob object was accepted. Pod Security does not enforce on CronJobs. `kubectl create job --from=cronjob/nightly-report` also succeeded before ServiceAccount `report-runner` or ConfigMap `report-script-v7` existed. The Job then had no pods. Its event was `FailedCreate`: `pods "snippet-cron-" is forbidden: error looking up service account team-a/report-runner: serviceaccount "report-runner" not found`. After those two objects existed, the pod was scheduled and failed the same way as the restricted pod: `CreateContainerConfigError`, `runAsNonRoot` and image user root. There is no container command, so the mounted script never ran. Pod logs were `BadRequest` because the container was still waiting to start. |

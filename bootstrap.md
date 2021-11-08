
## Cluster Bootstrapping

1. Install ubuntu 64 bit on at least 2 rpis.
2. First prep nodes by running through https://vladimir.varank.in/notes/2020/01/raspi-ubuntu-arm64-k3s/. Mainly make sure ips are set (I do it with router reservations), hostnames are correct, and cgroup settings are enabled. Reboot.

3. k3sup install --host k3s-01 --user ubuntu --context home --no-extras

4. k3sup join --host k3s-02 --server-host k3s-01 --user ubuntu

5. Install flux per [instructions](https://fluxcd.io/docs/get-started/). Or I do it the manual way with `flux install --export >> manifests/flux.yaml` and `kubectl apply -f manifests/flux.yaml`

6. Add git repo to manifests and kubectl apply

7. Add kustomize controller to sync manifests.

8. You are now autodeploying anything you push to `./manifests` !!!
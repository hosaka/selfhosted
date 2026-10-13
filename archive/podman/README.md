## Kustomize Pods

- Copy default.env to .env inside the pod directory.
- Edit .env to adjust the settings for each required pod.

From the pods/ directory, generate kubernetes yaml for each pod:
```
kustomize build proxy/ > proxy.yml
kustomize build media/ > media.yml
```

Setup networks to allow pods to communicate with each other:
```
podman network create proxy
podman network create media
```

Run generated pod yaml files with correct networks attached
```
podman kube play --network media media.yml
podman kube play --network proxy --network media proxy.yml
```

## Podman Quirks
Trying to run a DNS servier in a container and binding it to host port 53 causes issues with netavark/aardvark-dns, failing to resolve inter-container names. Binding the container to PUBLIC_IP:53 instead o 0.0.0.0:53 is a workaround.
# Example of PowerShell based Kubernetes CRD
## About
Kubernetes [Custom Resource Definitions (CRDs)](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) can be used to extend its API to support any resources you want control with it.

Because Kubernetes is built with Go programming language most of the examples are made for it but there is also working examples for [Rusty](https://github.com/kube-rs/controller-rs) and [C#](https://github.com/engineerd/kubecontroller-csharp/) too.

This example explains how you can use CRDs with my favorite scripting language PowerShell.


As a example we extend Kubernetes support VLAN provisioning with YAML files like these where description is only mandatory value.
```yaml
apiVersion: "example.com/v1alpha1"
kind: "Vlan"
metadata:
  name: "example"
  namespace: "vlans"
spec:
  description: "Example"
```
Then with PowerShell we fetch those VLAN definitions from API and fill unique VLAN IDs to them from range 2000-2999.

## Preparation
- Clone this GIT repo
- Add support for VLAN resources:
```bash
kubectl apply -f crd.yaml
```
- Add namespace (vlans) and service account (vlan-provisioning) with minimum needed access rights.
```bash
kubectl apply -f nsRoleUser.yaml
```
- Fetch service account token
```bash
kubectl -n vlans describe secret vlan-provisioning-token-<tab>
```
- Create some test VLANs
```bash
kubectl apply -f vlans/vlanMarketing.yaml
kubectl apply -f vlans/vlanSales.yaml
```

## Processing with PowerShell
- Update Kubernetes API URL and service account token to script below and run it
```powershell
$KubernetesUrl="https://<IP>:6443"
$token="<token>"
./provisioning.ps1 -KubernetesUrl $KubernetesUrl -Token $token
```
- Check that VLAN IDs was included
```bash
kubectl -n vlans get vlans -o yaml
```
**NOTE!** Because actual VLAN provisioning is not included example their status will be set to "provisioned = false".

## Hosting on container
Currently this example does not contain webhook type of realtime triggering like those official examples does but you can set it running as cron job inside of Kubernestes cluster.

- Create config map from PowerShell script
```bash
kubectl -n vlans create configmap vlan-provisioning.ps1 --from-file=./provisioning.ps1
```

- Create cron job (**NOTE!** You need replace `<IP>` with Kubernetes API IP)
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vlan-provisioning
  namespace: vlans
spec:
  schedule: "*/10 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          serviceAccountName: vlan-provisioning
          automountServiceAccountToken: true
          containers:
          - name: vlanprov
            image: mcr.microsoft.com/powershell:lts-debian-buster-slim
            imagePullPolicy: IfNotPresent
            command:
            - pwsh
            - -c
            - /provisioning.ps1 -KubernetesUrl https://<IP>:6443
            volumeMounts:
            - name: provisioning
              mountPath: /provisioning.ps1
              subPath: provisioning.ps1
              readOnly: true
          volumes:
          - name: provisioning
            configMap:
              name: vlan-provisioning.ps1
```

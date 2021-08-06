param(
    [string]$KubernetesUrl,
    [string]$Token
)

if (Test-Path -Path "/var/run/secrets/kubernetes.io/serviceaccount/token") {
    $Token = Get-Content -Path "/var/run/secrets/kubernetes.io/serviceaccount/token"
}

$KubernetesAuthenticationHeaders = @{ Authorization = "Bearer $Token" }

$vlans = Invoke-RestMethod -Uri "$KubernetesUrl/apis/example.com/v1alpha1/vlans/" -Method GET -Headers $KubernetesAuthenticationHeaders -SkipCertificateCheck
[array]$usedVlanIDs = $vlans.items.status.vlanID

$nonProvisionedVLANs = $vlans.items | Where-Object {$_.status -eq  $null}
forEach($vlan in $nonProvisionedVLANs) {
    $vlanDetails = Invoke-RestMethod -Uri "$KubernetesUrl/apis/example.com/v1alpha1/namespaces/$($vlan.metadata.namespace)/vlans/$($vlan.metadata.name)" -Method GET -Headers $KubernetesAuthenticationHeaders -SkipCertificateCheck

    # Get next free VLAN ID
    for($i=2000;$i -lt 3000; $i++) {
        if ($usedVlanIDs -contains $i) {
            continue
        }
        $vlanID = $i
        $usedVlanIDs += $vlanID
        break
    }

    # Update status
    $status = @{
        "provisioned" = $false
        "vlanID" = $vlanID
    }
    $vlanDetails | Add-Member -Name status -Value $status -MemberType NoteProperty
    $vlanDetailsJSON = $vlanDetails | ConvertTo-JSON -Depth 100
    Invoke-RestMethod -Uri "$KubernetesUrl/apis/example.com/v1alpha1/namespaces/$($vlan.metadata.namespace)/vlans/$($vlan.metadata.name)" -Method PUT -Body $vlanDetailsJSON -Headers $KubernetesAuthenticationHeaders -SkipCertificateCheck -ContentType "application/json"
}

if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
. “C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1”
}

if ( !(Get-Module -Name Hyper-V -ErrorAction SilentlyContinue) ) {
    Remove-Module -Name Hyper-V -ErrorAction SilentlyContinue
}

$priorityLevels = @{High=4;Medium=2;Low=1}

if($firsttime -ne 1)
{
    $serverName = Read-Host "Enter vCenter Server Name:"
    Connect-VIServer -Server $serverName
    $firsttime = 1
}

$CPUSUM = 0
((Get-ResourcePool -Location Resources).NumCpuShares) | ForEach-Object{$CPUSUM += $_}

$resPools = Get-ResourcePool -Location Resources
$resPoolObjects = @()
$MaxRequiredShare = 0

foreach ($resPool in $resPools)
{
    $resPoolObject = @{}
    $resPoolObject.Name = $resPool.Name

    $titleString = "Select required share level for $($resPool.Name)"
    $resPoolObject.RequiredLevel = ($priorityLevels | Out-GridView -PassThru -Title $titleString).value

    [int]$resPoolObject.CPUNumber = 0
    $VMs = $respool | get-vm | ?{$_.PowerState -eq "PoweredOn"}
    foreach ($VM in $VMs)
    {
        $resPoolObject.CPUNumber += $VM.NumCpu
    }
    
        $resPoolObject.CPUShares = $resPool.NumCpuShares

    if($resPoolObject.CPUNumber -eq 0)
    {
        $resPoolObject.SharePerCPU = 0
    }
    else
    {
        $resPoolObject.SharePerCPU = [math]::Round($resPool.NumCpuShares/$resPoolObject.CPUNumber,1)
    }

    $resPoolObject.RequiredShare = $resPoolObject.CPUNumber * $resPoolObject.requiredLevel
    if($resPoolObject.RequiredShare -gt $MaxRequiredShare)
    {
        $MaxRequiredShare = $resPoolObject.RequiredShare
    }
    
    $NewResPoolObject = New-Object -TypeName PSObject -Property $resPoolObject
    $resPoolObjects += $NewResPoolObject
}

foreach($resPoolObject in $resPoolObjects)
{
    $resPoolObject.RequiredShare = $resPoolObject.RequiredShare * 8000 / $MaxRequiredShare
    $resPoolObject.RequiredShare = ([system.math]::round($resPoolObject.RequiredShare/10))*10
}

$resPoolObjects | Sort-Object SharePerCPU -Descending |  ft Name,CPUShares,CPUNumber,SharePerCPU,RequiredLevel,RequiredShare




<#

###### Before #####

Name                         CPUNumber SharePerCPU
----                         --------- -----------
Production - High Priority          12       666.7
UAT                                 50          40
Production - Normal Priority       140        28.6
Dev                                 71        28.2
LOAD                               160        12.5

###### After #####

Name                         CPUNumber SharePerCPU
----                         --------- -----------
Production - High Priority          12       333.3
Production - Normal Priority       140        57.1
UAT                                 50          40
Dev                                 71        28.2
LOAD                               160        12.5

#>


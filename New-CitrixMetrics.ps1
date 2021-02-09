
$ErrorActionPreference = "Stop"

$Config = Import-PowerShellDataFile "$PSScriptRoot\Configuration\Config.psd1"

Add-PSSnapIn Citrix.*

$Pfx = $Config.PrometheusCollectorPrefix
$MSPrefix = "${Pfx}_machine_status"
$PfxDuration = "${Pfx}_collector_duration_ms"


function Write-Performance {
    param (
        # the collector's name, e.g. "licenses"
        [Parameter(Mandatory=$True)]
        [string]
        $Name,

        # the collector's command, e.g. "Get-BrokerSite"
        [Parameter(Mandatory=$True)]
        [string]
        $Command,

        # the stopwatch instance used to measure the collector's performance
        [Parameter(Mandatory=$True)]
        [Diagnostics.Stopwatch]
        $StopWatch
    )
    if ($StopWatch.IsRunning) {
        $StopWatch.Stop()
    }
    $Message = "${PfxDuration}{collector=`"$Name`", command=`"$Command`"} "
    $Message += $($StopWatch.ElapsedMilliseconds)
    Write-Output $Message

}


$StopWatch = [Diagnostics.Stopwatch]::StartNew()
$BrokerSite = Get-BrokerSite
Write-Performance -Name "licenses" -Command "Get-BrokerSite" -StopWatch $StopWatch
Write-Output "${Pfx}_licenses_sessions_active{} $($BrokerSite.LicensedSessionsActive)"
Write-Output "${Pfx}_licenses_peak_concurrent_users{} $($BrokerSite.PeakConcurrentLicenseUsers)"

# Get-BrokerCatalog
# Get-BrokerController
# Get-BrokerDesktopGroup

$StopWatch = [Diagnostics.Stopwatch]::StartNew()
$MachineStatus = Get-BrokerMachine -AdminAddress $Config.CitrixDC
Write-Performance -Name "machine_status" -Command "Get-BrokerMachine" -StopWatch $StopWatch

foreach ($Machine in $MachineStatus) {
    $MachineName = $Machine.MachineName.split("\")[1]
    $Catalog = $Machine.CatalogName
    if ($Config.StripCatalogPrefix.Length -gt 0) {
        $Catalog = $Catalog.Replace($Config.StripCatalogPrefix, "")
    }
    
    $Status = $Machine.SummaryState
    $Maintenance = 0
    if ($Machine.InMaintenanceMode -eq $True) {
        $Maintenance = 1
    }
    $Username = $Machine.SessionUserName
    if ($null -ne $Username) {
        $Username = $Username.split("\")[1]
    }
    $Name = $Machine.AssociatedUserFullNames
    $Email= $Machine.AssociatedUserUPNs
    $Session_Start = $Machine.SessionStartTime
    $Session_Change = $Machine.SessionStateChangeTime
    
    $Entry = "$MSPrefix{"
    $Entry += "machine_name=`"$MachineName`", "
    # $Entry += "catalog=`"$Catalog`", "
    $Entry += "status=`"$Status`", "
    $Entry += "maintenance=`"$Maintenance`", "
    $Entry += "username=`"$Username`", "
    $Entry += "name=`"$Name`", "
    $Entry += "email=`"$Email`", "
    $Entry += "session_start=`"$Session_Start`", "
    $Entry += "session_change=`"$Session_Change`""
    $Entry += "} 1"
    Write-Output $Entry
}

<#
.SYNOPSIS
    Collect Citrix XenDesktop metrics and format them for Prometheus.
.DESCRIPTION
    Collect metrics from a Citrix Delivery Controller (license usage, machine status,
    ...) and formats them such that they are to be digested by the "windows_exporter"
    Prometheus service using the `textfile` collector.
#>

$ErrorActionPreference = "Stop"

$Config = Import-PowerShellDataFile "$PSScriptRoot\Configuration\Config.psd1"

Add-PSSnapIn Citrix.*

$Global:Pfx = $Config.PrometheusCollectorPrefix
$MSPrefix = "${Pfx}_machine_status"
$PfxDuration = "${Pfx}_collector_duration_ms"



function New-MetricHeader {
    param (
        # the metric name (prefix will be added automatically)
        [Parameter(Mandatory=$True)]
        [string]
        $Name,

        # the metric type
        [Parameter(Mandatory=$True)]
        [ValidateSet('gauge', 'counter')]
        [string]
        $Type,

        # a string that will be used for the "HELP" entry in the prometheus output
        [Parameter(Mandatory=$False)]
        [string]
        $Description="Metric without additional description from citrix_collector."
    )
    $MetricName = "${Pfx}_${Name}"
    return "# HELP $MetricName $Description`n# TYPE $MetricName $Type"
}


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
    Write-Gauge -Name "collector_duration_ms" `
        -Properties "collector=`"$Name`", command=`"$Command`"" `
        -Value $StopWatch.ElapsedMilliseconds `
        -Header $False
}


function Write-Gauge {
    param (
        # the name that will be used for the metric (prefix will be added automatically)
        [Parameter(Mandatory=$True)]
        [string]
        $Name,

        # the gauge value
        [Parameter(Mandatory=$True)]
        [int]
        $Value,
        
        # properties to be added to the metric inside the curly brackets {}
        [Parameter(Mandatory=$False)]
        [string]
        $Properties="",
        
        # a string that will be used for the "HELP" entry in the prometheus output
        [Parameter(Mandatory=$False)]
        [string]
        $Description="Metric without additional description from citrix_collector.",

        # flag to disable the "HELP" and "TYPE" header for this metric
        [Parameter(Mandatory=$False)]
        [bool]
        $Header=$True
    )
    $MetricName = "${Pfx}_${Name}"
    if ($Header) {
        New-MetricHeader -Name $Name -Description $Description -Type "gauge"
    }
    return "$MetricName{$Properties} $Value"
}


$StopWatch = [Diagnostics.Stopwatch]::StartNew()
$BrokerSite = Get-BrokerSite
Write-Performance -Name "licenses" -Command "Get-BrokerSite" -StopWatch $StopWatch
Write-Gauge -Name "licenses_sessions_active" -Value $BrokerSite.LicensedSessionsActive `
    -Description "Current number of licenses in use (LicensedSessionsActive)."
Write-Gauge -Name "licenses_peak_concurrent_users" `
    -Value $BrokerSite.PeakConcurrentLicenseUsers `
    -Description "Peak number of concurrent license users (PeakConcurrentLicenseUsers)."

# Get-BrokerCatalog
# Get-BrokerController
# Get-BrokerDesktopGroup

$StopWatch = [Diagnostics.Stopwatch]::StartNew()
$MachineStatus = Get-BrokerMachine -AdminAddress $Config.CitrixDC
Write-Performance -Name "machine_status" -Command "Get-BrokerMachine" -StopWatch $StopWatch

foreach ($Machine in $MachineStatus) {
    $MachineName = $Machine.MachineName.split("\")[1].ToLower()
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

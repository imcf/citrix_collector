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


class PerformanceMetric {
    [string] $Collector
    [string] $Command
    [Diagnostics.Stopwatch] $StopWatch
    
    PerformanceMetric(
        [string] $Collector,
        [string] $Command
    ) {
        $this.StopWatch = [Diagnostics.Stopwatch]::StartNew()
        $this.Collector = $Collector
        $this.Command = $Command
    }

    [void] Measure() {
        if ($this.StopWatch.IsRunning) {
            $this.StopWatch.Stop()
        }
    }

    [int] Milliseconds() {
        if ($this.StopWatch.IsRunning) {
            return -1
        }
        return $this.StopWatch.ElapsedMilliseconds
    }

    [string] ToString() {
        $Pfx = $Global:Pfx
        $Properties = "collector=`""+$this.Collector+"`", command=`""+$this.Command+"`""
        return "${Pfx}_collector_duration_ms{$Properties} $($this.Milliseconds())"
    }
}


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
        # the PerformanceMetric object
        [Parameter(Mandatory=$True)]
        [PerformanceMetric]
        $Metric
    )
    $Metric.Measure()
    return $Metric.ToString()
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


$Metric = [PerformanceMetric]::new("licenses", "Get-BrokerSite")
$BrokerSite = Get-BrokerSite -AdminAddress $Config.CitrixDC
Write-Performance $Metric
Write-Gauge -Name "licenses_sessions_active" -Value $BrokerSite.LicensedSessionsActive `
    -Description "Current number of licenses in use (LicensedSessionsActive)."
Write-Gauge -Name "licenses_peak_concurrent_users" `
    -Value $BrokerSite.PeakConcurrentLicenseUsers `
    -Description "Peak number of concurrent license users (PeakConcurrentLicenseUsers)."

# Get-BrokerCatalog
# Get-BrokerController
# Get-BrokerDesktopGroup

$Metric = [PerformanceMetric]::new("machine_status", "Get-BrokerMachine")
$MachineStatus = Get-BrokerMachine -AdminAddress $Config.CitrixDC
Write-Performance $Metric


foreach ($Machine in $MachineStatus) {
    $MachineName = $Machine.MachineName.split("\")[1].ToLower()
    $Catalog = $Machine.DesktopGroupName
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
    $Entry += "catalog=`"$Catalog`", "
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

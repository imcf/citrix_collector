
$Config = Import-PowerShellDataFile "$PSScriptRoot\Configuration\Config.psd1"
$FileName = "$($Config.PrometheusCollectorDir)\$($Config.PrometheusCollectorFile)"

Write-Output "Starting the Citrix Prometheus collector..."

while ($True) {
    & $PSScriptRoot\New-CitrixMetrics.ps1 | Out-File $FileName -Encoding "UTF8"
    Start-Sleep -Seconds 30
}

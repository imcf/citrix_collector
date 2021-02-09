
$Config = Import-PowerShellDataFile "$PSScriptRoot\Configuration\Config.psd1"
$FileName = "$($Config.PrometheusCollectorDir)\$($Config.PrometheusCollectorFile)"

while ($True) {
    & .\New-CitrixMetrics.ps1 | Out-File $FileName -Encoding "UTF8"
    Start-Sleep -Seconds 30
}

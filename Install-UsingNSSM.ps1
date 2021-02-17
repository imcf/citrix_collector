$ServiceName = "citrix_collector"
# $ServiceName = "grafana"
$NSSMExecutable = "C:\Tools\NSSM\nssm-2.24-101-g897c7ad\win64\nssm.exe"

$PSExecutable = (Get-Command Powershell).Source
$BaseDir = $PSScriptRoot

try {
    $Service = Get-Service -Name $ServiceName -ErrorAction Stop
}
catch {
    Write-Host "Service $ServiceName not found, installing..."
}

if ($null -ne $Service) {
    Write-Host "Service $ServiceName is already installed! Doing nothing."
    exit
}


# required arguments, including the path to the script
$Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$BaseDir\citrix_collector.ps1`""

# install the service
& $NSSMExecutable install $ServiceName $PSExecutable $Arguments

# set a log file for stdout and stderr
& $NSSMExecutable set $ServiceName AppStdout $BaseDir\citrix_collector.log
& $NSSMExecutable set $ServiceName AppStderr $BaseDir\citrix_collector.log
& $NSSMExecutable set $ServiceName AppTimestampLog 1

# Prometheus collector for Citrix XenDesktop metrics

A PowerShell based collector to get metrics from a Citrix XenDesktop instance and format
them in a way they can be digested by the [windows_exporter][1] for Prometheus using its
`textfile` collector.

## Installation

1. Copy the entire directory to a suitable place. In this example we'll be using
   `C:\Tools\citrix-collector\` as the location.
1. Make sure to have the *Citrix Broker* PowerShell snap-in installed. You can find it
   in the *CVAD* installation ISO in the `\x64\Citrix Desktop Delivery Controller\`
   folder. Just extract `Broker_PowerShellSnapIn_x64.msi` from the ISO (the other
   snap-ins are not required) and install it via `msiexec.exe /i`.
1. Download the [WinSW][2] executable and place it inside the `citrix-collector` folder,
   rename it to `winsw.exe`.
1. Copy `winsw-example.xml` to `winsw.xml` and adjust if necessary. Most likely you will
   want to uncomment the `<serviceaccount>` section and set the account the service will
   be running as.
   NOTE: it needs to have appropriate permissions to query the Delivery Controller for
   collecting the metrics.
1. Run `.\winsw.exe install` in the collector directory to register the service.
1. Make sure the target location (`textfile_inputs`) has its permission set in a way so
   the account used to run the service is allowed to write there (or at least the
   configured output file).
1. Issue `Start-Service citrix_collector` to start it.
1. Watch the log files and / or the generated Prometheus textfile.

[1]: https://github.com/prometheus-community/windows_exporter
[2]: https://github.com/winsw/winsw/releases

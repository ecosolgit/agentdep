if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}

$fusionUninstaller = "C:\Program Files\FusionInventory-Agent\Uninstall.exe"

$software = "GLPI Agent"
$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -match $software }) -ne $null

If(-Not $installed) {
    
    if(Test-Path $fusionUninstaller -PathType Leaf){
        Start-Process -NoNewWindow -FilePath $fusionUninstaller -ArgumentList "/S" -Wait
    }

    Invoke-WebRequest -Uri "https://github.com/glpi-project/glpi-agent/releases/download/1.12/GLPI-Agent-1.12-x64.msi" -OutFile "$HOME\Downloads\glpi_agent.msi"

    Write-Host "Installing..."

    $arguments = @(
        "/i"
        "$HOME\Downloads\glpi_agent.msi"
        "/quiet"
        "RUNNOW=1"
        "SERVER=https://glpi.ecomedis.ch:4443/front/inventory.php,https://glpi.ecomedis.ch/front/inventory.php"
    )
    Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $arguments -wait
}

Write-Host "$software is installed."

pause

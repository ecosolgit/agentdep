function Install-GlpiAgent {
    $fusionUninstaller = "C:\Program Files\FusionInventory-Agent\Uninstall.exe"
    $software = "GLPI Agent"
    $glpiRegistryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"

    # Récupération dynamique de la dernière version
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/glpi-project/glpi-agent/releases/latest"
        $latestVersion = $release.tag_name.TrimStart("v")
        $asset = $release.assets | Where-Object { $_.name -like "*.msi" -and $_.name -like "*x64*" }
        $url = $asset.browser_download_url
        $output = "$HOME\Downloads\glpi_agent_$($latestVersion)_x64.msi"
    }
    catch {
        Write-Error "Erreur lors de la récupération de la dernière version GLPI Agent depuis GitHub."
        return
    }

    # Version installée ?
    $installedVersion = Get-ItemProperty $glpiRegistryPath |
        Where-Object { $_.DisplayName -match $software } |
        Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue

    $needsInstall = $false

    if (-not $installedVersion) {
        Write-Host "GLPI Agent n’est pas installé."
        $needsInstall = $true
    }
    elseif ($installedVersion -ne $latestVersion) {
        Write-Host "GLPI Agent installé : version $installedVersion → mise à jour vers $latestVersion nécessaire."
        $needsInstall = $true
    }
    else {
        Write-Host "GLPI Agent est déjà à jour (version $installedVersion)."
    }

    if ($needsInstall) {
        if (Test-Path $fusionUninstaller -PathType Leaf) {
            Write-Host "Désinstallation de FusionInventory Agent..."
            Start-Process -NoNewWindow -FilePath $fusionUninstaller -ArgumentList "/S" -Wait
        }

        Write-Host "Téléchargement de GLPI Agent $latestVersion depuis GitHub..."
        Invoke-WebRequest -Uri $url -OutFile $output

        Write-Host "Installation en cours..."
        $arguments = @(
            "/i"
            "`"$output`""
            "/quiet"
            "RUNNOW=1"
            "SERVER=https://glpi.ecomedis.ch:4443/front/inventory.php,https://glpi.ecomedis.ch/front/inventory.php"
        )

        Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $arguments -Wait
        Write-Host "Installation terminée."

        # Ouvrir le navigateur vers GLPI
        Start-Process "http://127.0.0.1:62354/"
    }

    pause
}

# Vérifie si on est en admin
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $admin) {
    # Si pas admin, se relancer en admin avec le code encodé
    $scriptContent = @"
`$( ${function:Install-GlpiAgent} )
Install-GlpiAgent
"@

    $bytes = [System.Text.Encoding]::Unicode.GetBytes($scriptContent)
    $encoded = [Convert]::ToBase64String($bytes)

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    exit
}

# Déjà admin : exécution directe
Install-GlpiAgent

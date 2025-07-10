# List of built-in apps to remove
$UninstallPackages = @(
    "AD2F1837.HPJumpStarts",
    "AD2F1837.HPPCHardwareDiagnosticsWindows",
    "AD2F1837.HPPowerManager",
    "AD2F1837.HPPrivacySettings",
    "AD2F1837.HPSupportAssistant",
    "AD2F1837.HPSureShieldAI",
    "AD2F1837.HPSystemInformation",
    "AD2F1837.HPQuickDrop",
    "AD2F1837.HPWorkWell",
    "AD2F1837.myHP",
    "AD2F1837.HPDesktopSupportUtilities",
    "AD2F1837.HPQuickTouch",
    "AD2F1837.HPEasyClean",
    "AD2F1837.HPSystemInformation"
)

# List of Win32 programs to uninstall
$UninstallPrograms = @(
    "HP Client Security Manager",
    "HP Documentation",
    "HP Wolf Security - Console",
    "HP Sure Run Module",
    "HP Security Update Service",
    "HP Connection Optimizer",
    "HP Notifications",
    "HP Sure Recover",
    "HP Wolf Security"
)

$HPidentifier = "AD2F1837"

$InstalledPackages = Get-AppxPackage -AllUsers |
    Where-Object { ($UninstallPackages -contains $_.Name) -or ($_.Name -match "^$HPidentifier") }

$ProvisionedPackages = Get-AppxProvisionedPackage -Online |
    Where-Object { ($UninstallPackages -contains $_.DisplayName) -or ($_.DisplayName -match "^$HPidentifier") }

$InstalledPrograms = Get-Package | Where-Object { $UninstallPrograms -contains $_.Name }

# Remove provisioned Appx packages
foreach ($ProvPackage in $ProvisionedPackages) {
    Write-Host "Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]..."
    try {
        Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
        Write-Host "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]"
    } catch {
        Write-Warning "Failed to remove provisioned package: [$($ProvPackage.DisplayName)]"
    }
}

# Remove installed Appx packages
foreach ($AppxPackage in $InstalledPackages) {
    Write-Host "Attempting to remove Appx package: [$($AppxPackage.Name)]..."
    try {
        Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host "Successfully removed Appx package: [$($AppxPackage.Name)]"
    } catch {
        Write-Warning "Failed to remove Appx package: [$($AppxPackage.Name)]"
    }
}

# Uninstall Win32 apps except HP Connection Optimizer
foreach ($program in $InstalledPrograms) {
    if ($program.Name -ne "HP Connection Optimizer") {
        Write-Host "Attempting to uninstall: [$($program.Name)]..."
        try {
            $program | Uninstall-Package -AllVersions -Force -ErrorAction Stop
            Write-Host "Successfully uninstalled: [$($program.Name)]"
        } catch {
            Write-Warning "Failed to uninstall: [$($program.Name)]"
        }
    }
}

# Uninstall HP Documentation manually
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\HP_Documentation" /f
Remove-Item -Path "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\HP Documentation.lnk" -ErrorAction SilentlyContinue -Force
Remove-Item -Path "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\HP\HP Documentation.lnk" -ErrorAction SilentlyContinue -Force
Remove-Item -Path "C:\Program Files\HP\Documentation" -Recurse -Force -ErrorAction SilentlyContinue

# Create InstallShield silent response file for HP Connection Optimizer
$responseFilePath = "C:\Windows\Temp\HPConnectionOptimizerUninstall.iss"
$responseFileContent = @"
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{6468C4A5-E47E-405F-B675-A70A70983EA6}-DlgOrder]
Dlg0={6468C4A5-E47E-405F-B675-A70A70983EA6}-SdWelcomeMaint-0
Count=3
Dlg1={6468C4A5-E47E-405F-B675-A70A70983EA6}-MessageBox-0
Dlg2={6468C4A5-E47E-405F-B675-A70A70983EA6}-SdFinishReboot-0
[{6468C4A5-E47E-405F-B675-A70A70983EA6}-SdWelcomeMaint-0]
Result=303
[{6468C4A5-E47E-405F-B675-A70A70983EA6}-MessageBox-0]
Result=6
[Application]
Name=HP Connection Optimizer
Version=2.0.18.0
Company=HP Inc.
[{6468C4A5-E47E-405F-B675-A70A70983EA6}-SdFinishReboot-0]
Result=1
BootOption=0
"@
$responseFileContent | Out-File -FilePath $responseFilePath -Encoding ASCII -Force

# Locate uninstall string from registry for HP Connection Optimizer
$uninstallRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$hpConnOptUninstall = $null
foreach ($path in $uninstallRegPaths) {
    Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if ($props.DisplayName -like "HP Connection Optimizer*") {
            $hpConnOptUninstall = $props.UninstallString
        }
    }
}

if ($hpConnOptUninstall) {
    $exePath = if ($hpConnOptUninstall.StartsWith('"')) {
        if ($hpConnOptUninstall -match '^"([^"]+)"') { $matches[1] }
    } else {
        $hpConnOptUninstall.Split(' ')[0]
    }

    if (Test-Path $exePath) {
        Write-Host "Running silent uninstall of HP Connection Optimizer..."
        Start-Process -FilePath $exePath -ArgumentList "-s -f1`"$responseFilePath`"" -Wait
    } else {
        Write-Warning "Uninstall executable not found: $exePath"
    }
} else {
    Write-Warning "HP Connection Optimizer uninstall string not found"
}

# Retry function for stubborn apps
function Retry-UninstallApp {
    param (
        [string]$DisplayName
    )
    $uninstallRegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($path in $uninstallRegPaths) {
        Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -eq $DisplayName -and $props.UninstallString) {
                $uninstallCmd = $props.UninstallString
                if ($uninstallCmd.StartsWith('"') -and $uninstallCmd -match '^"([^"]+)"') {
                    $exePath = $matches[1]
                    $args = $uninstallCmd.Substring($exePath.Length + 2).Trim()
                } else {
                    $split = $uninstallCmd.Split(' ', 2)
                    $exePath = $split[0]
                    $args = if ($split.Length -gt 1) { $split[1] } else { "" }
                }

                if (Test-Path $exePath) {
                    Write-Host "Waiting 30 seconds before retrying uninstall of $DisplayName..."
                    Start-Sleep -Seconds 30
                    Write-Host "Retrying uninstall: $DisplayName"
                    Start-Process -FilePath $exePath -ArgumentList "$args /quiet /norestart" -Wait
                }
            }
        }
    }
}

# Retry uninstall for apps that might fail on first run
Retry-UninstallApp "HP Documentation"
Retry-UninstallApp "HP Notifications"
Retry-UninstallApp "HP Security Update Service"
Retry-UninstallApp "HP Sure Recover"
Retry-UninstallApp "HP Wolf Security"
Retry-UninstallApp "HP Wolf Security - Console"

# Fallback uninstall using known MSI product codes (optional)
Try {
    Start-Process msiexec.exe -ArgumentList '/x {0E2E04B0-9EDD-11EB-B38C-10604B96B11E} /qn /norestart' -Wait
    Write-Host "Fallback to MSI uninstall for HP Wolf Security initiated"
} Catch {
    Write-Warning "Failed to uninstall HP Wolf Security via MSI: $($_.Exception.Message)"
}

Try {
    Start-Process msiexec.exe -ArgumentList '/x {4DA839F0-72CF-11EC-B247-3863BB3CB5A8} /qn /norestart' -Wait
    Write-Host "Fallback to MSI uninstall for HP Wolf Security 2 initiated"
} Catch {
    Write-Warning "Failed to uninstall HP Wolf Security 2 via MSI: $($_.Exception.Message)"
}

# Final check and conditional retry for HP Security Update Service (up to 3 retries)
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$maxRetries = 3
$retryCount = 0

do {
    $hpSecurityService = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq "HP Security Update Service" }

    if ($hpSecurityService) {
        if ($retryCount -eq 0) {
            Write-Host "`n[Post-Check] HP Security Update Service still detected. Starting retry logic..."
        }

        Write-Host "Attempt $($retryCount + 1): Waiting 30 seconds before retry..."
        Start-Sleep -Seconds 30

        $uninstallCmd = $hpSecurityService.UninstallString
        if ($uninstallCmd) {
            if ($uninstallCmd.StartsWith('"') -and $uninstallCmd -match '^"([^"]+)"') {
                $exePath = $matches[1]
                $args = $uninstallCmd.Substring($exePath.Length + 2).Trim()
            } else {
                $split = $uninstallCmd.Split(' ', 2)
                $exePath = $split[0]
                $args = if ($split.Length -gt 1) { $split[1] } else { "" }
            }

            # Skip Test-Path if it's a known command like MsiExec
            if ($exePath -ieq "MsiExec.exe" -or $exePath -ieq "msiexec") {
                Write-Host "Retrying uninstall of HP Security Update Service using MsiExec..."
                try {
                    Start-Process -FilePath "MsiExec.exe" -ArgumentList "$args /quiet /norestart" -Wait
                    Write-Host "Uninstall retry attempt $($retryCount + 1) completed."
                } catch {
                    Write-Warning "Retry attempt $($retryCount + 1) failed: $($_.Exception.Message)"
                }
            }
            elseif (Test-Path $exePath) {
                Write-Host "Retrying uninstall of HP Security Update Service..."
                try {
                    Start-Process -FilePath $exePath -ArgumentList "$args /quiet /norestart" -Wait
                    Write-Host "Uninstall retry attempt $($retryCount + 1) completed."
                } catch {
                    Write-Warning "Uninstall attempt $($retryCount + 1) failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Retry failed: uninstall executable not found at path: $exePath"
                break
            }
        }
    }

    $retryCount++
} while ($hpSecurityService -and $retryCount -lt $maxRetries)

if ($retryCount -eq $maxRetries -and $hpSecurityService) {
    Write-Warning "HP Security Update Service could not be uninstalled after $maxRetries attempts."
} elseif (-not $hpSecurityService) {
    Write-Host "HP Security Update Service is no longer present. No further retries needed."
}

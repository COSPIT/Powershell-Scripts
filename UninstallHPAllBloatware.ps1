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

# List of programs to uninstall
$UninstallPrograms = @(
    "HP Client Security Manager",
    "HP Documentation",
    "HP Wolf Security - Console",
    "HP Sure Run Module",
    "HP Security Update Service",
    "HP Connection Optimizer"
)

$HPidentifier = "AD2F1837"

$InstalledPackages = Get-AppxPackage -AllUsers |
    Where-Object { ($UninstallPackages -contains $_.Name) -or ($_.Name -match "^$HPidentifier") }

$ProvisionedPackages = Get-AppxProvisionedPackage -Online |
    Where-Object { ($UninstallPackages -contains $_.DisplayName) -or ($_.DisplayName -match "^$HPidentifier") }

$InstalledPrograms = Get-Package | Where-Object { $UninstallPrograms -contains $_.Name }

# Remove appx provisioned packages
foreach ($ProvPackage in $ProvisionedPackages) {
    Write-Host "Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]..."
    try {
        Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
        Write-Host "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]"
    }
    catch {
        Write-Warning "Failed to remove provisioned package: [$($ProvPackage.DisplayName)]"
    }
}

# Remove appx packages
foreach ($AppxPackage in $InstalledPackages) {
    Write-Host "Attempting to remove Appx package: [$($AppxPackage.Name)]..."
    try {
        Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host "Successfully removed Appx package: [$($AppxPackage.Name)]"
    }
    catch {
        Write-Warning "Failed to remove Appx package: [$($AppxPackage.Name)]"
    }
}

# Remove installed programs except HP Connection Optimizer
foreach ($program in $InstalledPrograms) {
    if ($program.Name -ne "HP Connection Optimizer") {
        Write-Host "Attempting to uninstall: [$($program.Name)]..."
        try {
            $program | Uninstall-Package -AllVersions -Force -ErrorAction Stop
            Write-Host "Successfully uninstalled: [$($program.Name)]"
        }
        catch {
            Write-Warning "Failed to uninstall: [$($program.Name)]"
        }
    }
}

# Special uninstall for HP Connection Optimizer using InstallShield silent uninstall

# Create InstallShield silent uninstall response file
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

# Find uninstall executable path for HP Connection Optimizer from registry
$uninstallRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$hpConnOptUninstall = $null
foreach ($path in $uninstallRegPaths) {
    $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
    foreach ($key in $keys) {
        $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
        if ($props.DisplayName -and $props.DisplayName -like "HP Connection Optimizer*") {
            $hpConnOptUninstall = $props.UninstallString
            break
        }
    }
    if ($hpConnOptUninstall) { break }
}

if ($hpConnOptUninstall) {
    # Extract executable path from UninstallString, handle quotes and spaces
    if ($hpConnOptUninstall.StartsWith('"')) {
        if ($hpConnOptUninstall -match '^"([^"]+)"') {
            $exePath = $matches[1]
        }
    } else {
        $exePath = $hpConnOptUninstall.Split(' ')[0]
    }

    Write-Host "Extracted uninstall exe path: '$exePath'"

    if (Test-Path $exePath) {
        Write-Host "Running silent uninstall of HP Connection Optimizer using response file..."
        try {
            Start-Process -FilePath $exePath -ArgumentList "-s -f1`"$responseFilePath`"" -Wait
            Write-Host "HP Connection Optimizer uninstall completed."
        }
        catch {
            Write-Warning "Failed to run silent uninstall for HP Connection Optimizer: $_"
        }
    }
    else {
        Write-Warning "Uninstall executable not found at path: $exePath"
    }
}
else {
    Write-Warning "Uninstall string for HP Connection Optimizer not found in registry."
}

# Fallback attempts to remove HP Wolf Security using msiexec
Try {
    MsiExec /x "{0E2E04B0-9EDD-11EB-B38C-10604B96B11E}" /qn /norestart
    Write-Host "Fallback to MSI uninstall for HP Wolf Security initiated"
}
Catch {
    Write-Warning "Failed to uninstall HP Wolf Security using MSI - Error: $($_.Exception.Message)"
}

Try {
    MsiExec /x "{4DA839F0-72CF-11EC-B247-3863BB3CB5A8}" /qn /norestart
    Write-Host "Fallback to MSI uninstall for HP Wolf Security 2 initiated"
}
Catch {
    Write-Warning "Failed to uninstall HP Wolf Security 2 using MSI - Error: $($_.Exception.Message)"
}

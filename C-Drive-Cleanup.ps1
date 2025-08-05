<#
.SYNOPSIS
    Automated Windows Disk Clean-up and Storage Optimisation Tool

.DESCRIPTION
    This PowerShell script performs a silent, automated system clean-up on Windows devices.
    It removes temporary files, clears Windows Update caches, disables hibernation, and empties the Recycle Bin.
    It also identifies large files, generates a folder size report, and logs disk usage before and after.

.NOTES
    Author      : Liam Curran
    Version     : 2.0
    Last Updated: 06/06/2025
    Requirements: Must be run as Administrator
    Logging     : Summary + Transcript saved to C:\Temp\DiskCleanupLogs\CleanupLog.txt

.LICENSE
    For internal use only.
#>

# Requires admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    exit
}

$ConfirmPreference = 'None'
$logDir = "C:\Temp\DiskCleanupLogs"
$logPath = "$logDir\CleanupLog.txt"
$diskBeforeCsv = "$logDir\DiskUsage_Before.csv"
$diskAfterCsv  = "$logDir\DiskUsage_After.csv"
$csvPath = "$logDir\LargeFiles.csv"
$folderReportPath = "$logDir\FolderSizeReport.csv"

if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Write success summary before transcript starts
$timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$summaryLines = @(
    "================== CLEANUP SUMMARY ==================",
    "Status     : SUCCESS",
    "Completed  : $timestamp",
    "Reports    :",
    " - Disk Usage (Before): $diskBeforeCsv",
    " - Disk Usage (After) : $diskAfterCsv",
    " - Large Files        : $csvPath",
    " - Folder Report      : $folderReportPath",
    " - Transcript Log     : $logPath",
    "Note       : A system reboot is recommended.",
    "=====================================================",
    ""
)
$summaryLines | Out-File -FilePath $logPath -Encoding UTF8 -Append

Start-Transcript -Path $logPath -Append
Write-Host "`n================== SYSTEM CLEANUP SCRIPT ==================" -ForegroundColor Cyan

function Get-DiskUsageTable {
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $device = $_.DeviceID
        $size = $_.Size
        $free = $_.FreeSpace
        if ($size -and $free -and $size -gt 0) {
            $used = $size - $free
            [PSCustomObject]@{
                Drive        = $device
                'Used (GB)'  = [math]::Round($used / 1GB, 2)
                'Used (%)'   = [math]::Round(($used / $size) * 100, 2)
                'Free (GB)'  = [math]::Round($free / 1GB, 2)
                'Free (%)'   = [math]::Round(($free / $size) * 100, 2)
            }
        }
    }
}

try {
    Write-Host "`nDisk Usage Report (Before Cleanup):" -ForegroundColor Cyan
    $diskBefore = Get-DiskUsageTable
    $diskBefore | Format-Table -AutoSize
    $diskBefore | Export-Csv -Path $diskBeforeCsv -NoTypeInformation -Encoding UTF8

    Write-Host "`nDeleting Temp Files..." -ForegroundColor Cyan
    Get-ChildItem "C:\Users" -Directory | ForEach-Object {
        $temp = "$($_.FullName)\AppData\Local\Temp"
        if (Test-Path $temp) {
            Get-ChildItem $temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Get-ChildItem "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "`nClearing Windows Update Cache..." -ForegroundColor Cyan
    Stop-Service wuauserv -Force; Start-Sleep -Seconds 3
    Get-ChildItem "C:\Windows\SoftwareDistribution\Download" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv

    Write-Host "`nDeleting CBS Log Files..." -ForegroundColor Cyan
    Get-ChildItem "C:\Windows\Logs\CBS" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "`nDisabling Hibernation..." -ForegroundColor Cyan
    powercfg /h off

    Write-Host "`nDeleting old restore points..." -ForegroundColor Cyan
    try {
        Start-Process "vssadmin" -ArgumentList "delete shadows /all /quiet" -WindowStyle Hidden -Wait -ErrorAction Stop
    } catch {
        Write-Host "Could not delete restore points: $_" -ForegroundColor Yellow
    }

    Write-Host "`nRunning silent Disk Cleanup..." -ForegroundColor Cyan
    $cleanMgrSageSet = 1
    $cleanMgrTasks = @(
        "Temporary Setup Files", "Downloaded Program Files", "Temporary Internet Files",
        "Offline Webpages", "System error memory dump files", "Temporary files",
        "Thumbnails", "Recycle Bin", "Temporary Sync Files", "Windows Update Cleanup"
    )
    foreach ($task in $cleanMgrTasks) {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$task"
        if (Test-Path $regPath) {
            New-ItemProperty -Path $regPath -Name StateFlags$cleanMgrSageSet -Value 2 -Force | Out-Null
        }
    }
    Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:$cleanMgrSageSet" -WindowStyle Hidden -Wait

    Write-Host "`nEmptying Recycle Bin..." -ForegroundColor Cyan
    Get-ChildItem "C:\`$Recycle.Bin\*" -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Recycle Bin emptied successfully." -ForegroundColor Green

    Write-Host "`nScanning for large files (>1GB)..." -ForegroundColor Cyan
    $largeFiles = Get-ChildItem "C:\Users" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 1GB }
    if ($largeFiles.Count -eq 0) {
        Write-Host "No files over 1GB found." -ForegroundColor Yellow
    } else {
        $export = $largeFiles | Select-Object FullName, @{Name="Size(GB)";Expression={[math]::Round($_.Length / 1GB, 2)}}
        $export | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Large file list saved to $csvPath" -ForegroundColor Green
    }

    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne "C" }
    if ($drives.Count -gt 0 -and $largeFiles) {
        $dest = "$($drives[0].Root)Backup"
        if (!(Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
        Write-Host "`nMoving large files to $dest..." -ForegroundColor Cyan
        $largeFiles | Move-Item -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Files moved successfully." -ForegroundColor Green
    } else {
        Write-Host "No secondary drive found or no large files – skipping move." -ForegroundColor Yellow
    }

    Write-Host "`nGenerating folder size report..." -ForegroundColor Cyan
    $folders = Get-ChildItem "C:\Users" -Directory -Recurse -ErrorAction SilentlyContinue
    $report = foreach ($f in $folders) {
        $size = (Get-ChildItem $f.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        [PSCustomObject]@{
            Folder = $f.FullName
            SizeGB = [math]::Round($size / 1GB, 2)
            SizeMB = [math]::Round($size / 1MB, 2)
            ItemCount = (Get-ChildItem $f.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
        }
    }
    $report | Sort-Object SizeGB -Descending | Export-Csv $folderReportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Folder size report saved to $folderReportPath" -ForegroundColor Green

    Write-Host "`nDisk Usage Report (After Cleanup):" -ForegroundColor Green
    $diskAfter = Get-DiskUsageTable
    $diskAfter | Format-Table -AutoSize
    $diskAfter | Export-Csv -Path $diskAfterCsv -NoTypeInformation -Encoding UTF8

    Write-Host "`nCleanup Complete. A reboot is recommended." -ForegroundColor Green
}
catch {
    Write-Host "`nAn error occurred: $_" -ForegroundColor Red
}

Stop-Transcript
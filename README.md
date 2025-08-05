## C-Drive Cleanup Tool
**Author:** [That Bearded IT Guy](https://thatbeardeditguy.com)
<p align="center"> <img src="Logo.png" alt="That Bearded IT Guy Logo" width="150"/> </p>

### Overview
This PowerShell tool automates a safe and thorough cleanup of Windows C: drives.
It is designed for IT support engineers, lab environments, and anyone who needs a reliable way to reclaim disk space without touching user data.

The script targets the real causes of low disk space - temp folders, Windows Update leftovers, log files, and caches - areas that built‑in cleanup tools often miss.

### Features
- Clear temp folders and caches from both user and system directories.
- Remove Windows Update leftovers (SoftwareDistribution, Catroot2).
- Clean CBS and DISM logs to free space and reduce troubleshooting noise.
- Disable hibernation to reclaim large hiberfil.sys files.
- Delete old restore points (optional, includes caution in script).
- Generate before/after disk usage reports for visibility on reclaimed space.
- Identify large files and folders for further review.
- Safe for end-user and lab environments – personal files are untouched.

### Usage
- Download the script from this repository.
- Open PowerShell as Administrator.

### Execute the script:
`.\C-Drive-Cleanup.ps1`
Review generated logs and reports in:
'C:\Temp\DiskCleanupLogs'

### Example Outputs
Disk Usage Before/After - CSV reports show how much space was reclaimed.
Large Files Report - Flags files over 1 GB for review or relocation.
Folder Size Report - Identifies the largest directories under `C:\Users`.

### Requirements
- Windows 10 or later
- PowerShell 5.1+ (or newer)
- Administrator privileges
- Basic familiarity with running PowerShell scripts

### Notes
- A reboot is recommended after running the script.
- Review the script before use if deploying to production or end‑user systems.
- Deleting restore points is permanent - ensure no rollback is required.

### Learn More
This script is part of my write-up:
https://thatbeardeditguy.com/c-drive-cleanup-clearing-the-bloat-without-nuking-the-system

The article explains why these areas fill up, when to go deeper, and how to automate the process for your own toolkit.


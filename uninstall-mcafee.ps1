# Source: https://github.com/andrew-s-taylor/public/blob/main/De-Bloat/RemoveBloat.ps1

if (Get-Package | Where-Object Name -Like "*McAfee*") {
    Write-Host "Uninstalling McAfee products..."
    # Download MCPR from here, upload to your hosting provider https://www.mcafee.com/support/s/article/000001616?language=en_US
    # $url = "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe"
    # newer version's don't work silently, there are added checks 
    $url = "https://github.com/Advanced-Technology-AU/uninstall-mcafee/raw/refs/heads/main/mcafeeclean.zip"
    $zip = "C:\temp\MCPR.zip"
    New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath "C:\temp\MCPR" -Force
    $binary = "C:\temp\MCPR\Mccleanup.exe"
    $arguments = "-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUE -v -s"
    # Run the tool silently
    Start-Process -FilePath $binary -ArgumentList $arguments -Wait

    # Remove the downloaded zip and extracted tool
    Remove-Item -Path $zip, "C:\temp\MCPR" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "McAfee Removal Tool has been run"


    $InstalledPrograms = (Get-Package | Where-Object Name -like "*McAfee*")
    $InstalledPrograms | ForEach-Object {

        $name = $_.Name
        write-output "Attempting to uninstall: [$name]..."
        # Get-Package has no .String property; uninstall strings live in Meta attributes
        $uninstallcommand = $_.Meta.Attributes["QuietUninstallString"]
        if (-not $uninstallcommand) { $uninstallcommand = $_.Meta.Attributes["UninstallString"] }
        if (-not $uninstallcommand) {
            Write-Warning -Message "No uninstall string found for: [$name]"
            return
        }

        Try {
            if ($uninstallcommand -match "^msiexec*") {
                #Remove msiexec as we need to split for the uninstall
                $uninstallcommand = $uninstallcommand -replace "msiexec.exe", ""
                $uninstallcommand = $uninstallcommand + " /quiet /norestart"
                $uninstallcommand = $uninstallcommand -replace "/I", "/X "
                #Uninstall with string2 params
                Start-Process 'msiexec.exe' -ArgumentList $uninstallcommand -NoNewWindow -Wait -ErrorAction Stop
            }
            else {
                #Exe installer, split executable path from its arguments
                if ($uninstallcommand -match '^\s*"([^"]+)"\s*(.*)$' -or $uninstallcommand -match '^\s*(.+?\.exe)\s*(.*)$') {
                    $exe = $Matches[1]
                    $exeArgs = $Matches[2]
                }
                else {
                    $exe = $uninstallcommand
                    $exeArgs = ""
                }
                if ($exeArgs) {
                    Start-Process -FilePath $exe -ArgumentList $exeArgs -Wait -ErrorAction Stop
                }
                else {
                    Start-Process -FilePath $exe -Wait -ErrorAction Stop
                }
            }

            write-output "Successfully uninstalled: [$name]"
        }
        Catch { Write-Warning -Message "Failed to uninstall: [$name] - $($_.Exception.Message)" }
    }

    ##Remove Safeconnect
    $safeconnects = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -match "McAfee Safe Connect" } | Select-Object -Property UninstallString

    ForEach ($sc in $safeconnects) {
        If ($sc.UninstallString) {
            cmd.exe /c $sc.UninstallString /quiet /norestart
        }
    }

    ##
    ##remove some extra leftover Mcafee items from StartMenu-AllApps and uninstall registry keys
    ##
    if (Test-Path -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\McAfee") {
        Remove-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\McAfee" -Recurse -Force
    }
    if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\McAfee.WPS") {
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\McAfee.WPS" -Recurse -Force
    }
    #Interesting emough, this producese an error, but still deletes the package anyway
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq "McAfeeWPSSparsePackage" | Remove-AppxProvisionedPackage -Online -AllUsers

    Write-Host "Uninstall completed, please reboot"
}

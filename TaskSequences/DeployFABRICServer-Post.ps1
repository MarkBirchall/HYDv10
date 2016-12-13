﻿[cmdletbinding(SupportsShouldProcess=$true)]
Param
(
    [parameter(position=0,mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path -Path $_})]
    [string]
    $SettingsFile = "C:\Setup\FABuilds\FASettings.xml",

    [parameter(Position=1,mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path -Path $_})]
    [String]
    $VHDImage = "C:\Setup\VHD\WS2016-DCE_UEFI.vhdx",
    
    [parameter(Position=2,mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path -Path $_})]
    [String]
    $VMlocation = "D:\VMs",

    [parameter(Position=3,mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]
    $LogPath = $LogPath,

    [parameter(Position=4,mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Roles,

    [parameter(Position=5,mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Server,

    [parameter(Position=6,mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]
    $FinishAction,

    [parameter(Position=7,mandatory=$False)]
    [Switch]
    $KeepMountedMedia
)

##############

#Init
$Server = "SCVM01"
$ROle = "SCVM"
$Global:LogPath= "$env:TEMP\log.txt"

#Set start time
$StartTime = Get-Date

#Step Step
$Step = 0

#Import Modules
Import-Module C:\setup\Functions\VIAHypervModule.psm1 -Force
Import-Module C:\setup\Functions\VIADeployModule.psm1 -Force
Import-Module C:\Setup\Functions\VIAUtilityModule.psm1 -Force

#Set Values
$ServerName = $Server
$DomainName = "Fabric"

#Action
$Step = 1 + $step
$Action = "Notify start"
$Data = "Server:$ServerName" + "," + "Step:$Step" + "," + "Action:$Action"
Update-VIALog -Data $Data
Start-VIASoundNotify

#Read data from XML
$Step = 1 + $step
$Action = "Reading $SettingsFile"
$Data = "Server:$ServerName" + "," + "Step:$Step" + "," + "Action:$Action"
Update-VIALog -Data $Data
[xml]$Settings = Get-Content $SettingsFile -ErrorAction Stop
$CustomerData = $Settings.FABRIC.Customers.Customer
$CommonSettingData = $Settings.FABRIC.CommonSettings.CommonSetting
$ProductKeysData = $Settings.FABRIC.ProductKeys.ProductKey
$NetworksData = $Settings.FABRIC.Networks.Network
$ServicesData = $Settings.FABRIC.Services.Service
$DomainData = $Settings.FABRIC.Domains.Domain | Where-Object -Property Name -EQ -Value $DomainName
$ServerData = $Settings.FABRIC.Servers.Server | Where-Object -Property Name -EQ -Value $ServerName

$NIC01 = $ServerData.Networkadapters.Networkadapter | Where-Object -Property Name -EQ -Value NIC01
$NIC01RelatedData = $NetworksData | Where-Object -Property ID -EQ -Value $NIC01.ConnectedToNetwork

$AdminPassword = $CommonSettingData.LocalPassword
$DomainInstaller = $DomainData.DomainAdmin
$DomainName = $DomainData.DomainAdminDomain
$DNSDomain = $DomainData.DNSDomain
$DomainAdminPassword = $DomainData.DomainAdminPassword
$domainCred = new-object -typename System.Management.Automation.PSCredential -argumentlist "$($domainName)\Administrator", (ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force)

#Sample 1

#Action
$Action = "Sample 1"
Update-VIALog -Data "Action: $Action"

($ServicesData | Where-Object Name -EQ SCVMM2016).config
$SQLINSTANCENAME = ($ServicesData | Where-Object Name -EQ SCVMM2016).config.SQLINSTANCENAME
$SQLINSTANCEDIR = ($ServicesData | Where-Object Name -EQ SCVMM2016).config.SQLINSTANCEDIR

Invoke-Command -VMName $($ServerData.ComputerName) -ScriptBlock {
    Param($SQLINSTANCENAME,$SQLINSTANCEDIR)
        Write-Host "First Param is $SQLINSTANCENAME"
        Write-Host "Second Param is $SQLINSTANCEDIR"
} -Credential $domainCred -ArgumentList $SQLINSTANCENAME,$SQLINSTANCEDIR

#Sample 2

#Action
$Action = "Sample 2"
Update-VIALog -Data "Action: $Action"

($ServicesData | Where-Object Name -EQ SCVMM2016).config
$SQLINSTANCENAME = ($ServicesData | Where-Object Name -EQ SCVMM2016).config.SQLINSTANCENAME
$SQLINSTANCEDIR = ($ServicesData | Where-Object Name -EQ SCVMM2016).config.SQLINSTANCEDIR

Invoke-Command -VMName $($ServerData.ComputerName) -ScriptBlock {
    Param($SQLINSTANCENAME,$SQLINSTANCEDIR)
        Write-Host "First Param is $SQLINSTANCENAME"
        Write-Host "Second Param is $SQLINSTANCEDIR"
        Import-Module C:\Setup\Functions\VIAUtilityModule.psm1
        Get-VIAOSVersion
} -Credential $domainCred -ArgumentList $SQLINSTANCENAME,$SQLINSTANCEDIR


#Sample 3

#Action
$Action = "Sample 3"
Update-VIALog -Data "Action: $Action"
$Role = "NONE"
Invoke-Command -VMName $($ServerData.ComputerName) -ScriptBlock {
    Param($role)
        Import-Module C:\Setup\Functions\VIAUtilityModule.psm1
        C:\Setup\HYDv10\Scripts\Invoke-VIAInstallRoles.ps1 -Role $role
} -Credential $domainCred -ArgumentList $Role


#Sample 4

#Action
$Action = "Sample 4"
Update-VIALog -Data "Action: $Action"
$Param1 = "Administrators"
$Param2 = "Administrator"
Invoke-Command -VMName $($ServerData.ComputerName) -FilePath C:\Setup\HYDv10\Scripts\Add-VIADomainuserToLocalgroup.ps1 -ErrorAction Stop -Credential $domainCred -ArgumentList $Param1,$Param2

#Sample 5

#Action
$Action = "Sample 5"
Update-VIALog -Data "Action: $Action"

$FileItem = "C:\HydData.txt"
Get-VM -Name $($ServerData.ComputerName) | Enable-VMIntegrationService -Name "Guest Service Interface"
Copy-VMFile -VM (Get-VM -Name $($ServerData.ComputerName)) -SourcePath $FileItem -DestinationPath $FileItem -FileSource Host -CreateFullPath -Force
Invoke-Command -VMName $($ServerData.ComputerName) -ScriptBlock {
    Param($role,$FileItem)
        Write-Host "Role is $Role"
        Get-Content -Path $FileItem
} -Credential $domainCred -ArgumentList $Role,$FileItem


﻿<#
.SYNOPSIS
  
.DESCRIPTION
  
.EXAMPLE
  
#>
Param (
    [Parameter(Mandatory=$true,Position=0)]
    $SCVMSetup,

    [Parameter(Mandatory=$true,Position=1)]
    [ValidateSet("Full","Client","Agent")]
    $SCVMRole = "Full",

    [Parameter(Mandatory=$true,Position=2)]
    $SCVMMDomain,

    [Parameter(Mandatory=$true,Position=3)]
    $SCVMMSAccount,

    [Parameter(Mandatory=$true,Position=4)]
    $SCVMMSAccountPW,

    [Parameter(Mandatory=$true,Position=5)]
    $SCVMMProductKey,

    [Parameter(Mandatory=$true,Position=6)]
    $SCVMMUserName,
    
    [Parameter(Mandatory=$true,Position=7)]
    $SCVMMCompanyName,

    [Parameter(Mandatory=$true,Position=8)]
    $SCVMMBitsTcpPort,

    [Parameter(Mandatory=$true,Position=9)]
    $SCVMMVmmServiceLocalAccount,

    [Parameter(Mandatory=$true,Position=10)]
    $SCVMMTopContainerName,

    [Parameter(Mandatory=$true,Position=11)]
    $SCVMMLibraryDrive
)

Function Get-VIAOSVersion([ref]$OSv){
    $OS = Get-WmiObject -Class Win32_OperatingSystem
    Switch -Regex ($OS.Version)
    {
    "6.1"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 7 SP1"}
                Else
            {$OSv.value = "Windows Server 2008 R2"}
        }
    "6.2"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 8"}
                Else
            {$OSv.value = "Windows Server 2012"}
        }
    "6.3"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 8.1"}
                Else
            {$OSv.value = "Windows Server 2012 R2"}
        }
    "10"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 10"}
                Else
            {$OSv.value = "Windows Server 2016"}
        }
    DEFAULT { "Version not listed" }
    } 
}
Function Import-VIASMSTSENV{
    try{
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        Write-Output "$ScriptName - tsenv is $tsenv "
        $MDTIntegration = $true
        
        #$tsenv.GetVariables() | % { Write-Output "$ScriptName - $_ = $($tsenv.Value($_))" }
    }
    catch{
        Write-Output "$ScriptName - Unable to load Microsoft.SMS.TSEnvironment"
        Write-Output "$ScriptName - Running in standalonemode"
        $MDTIntegration = $false
    }
    Finally{
        if ($MDTIntegration -eq $true){
            $Logpath = $tsenv.Value("LogPath")
            $LogFile = $Logpath + "\" + "$ScriptName.txt"
        }
    Else{
            $Logpath = $env:TEMP
            $LogFile = $Logpath + "\" + "$ScriptName.txt"
        }
    }
    Return $MDTIntegration
}
Function Start-VIALogging{
    Start-Transcript -path $LogFile -Force
}
Function Stop-VIALogging{
    Stop-Transcript
}
Function Invoke-VIAExe{
    [CmdletBinding(SupportsShouldProcess=$true)]

    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory=$false,position=1)]
        [string]
        $Arguments
    )

    if($Arguments -eq "")
    {
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
    }else{
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    }
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}
Function Invoke-VIAMsi{
    [CmdletBinding(SupportsShouldProcess=$true)]

    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MSI,

        [parameter(mandatory=$false,position=1)]
        [string]
        $Arguments
    )

    #Set MSIArgs
    $MSIArgs = "/i " + $MSI + " " + $Arguments

    if($Arguments -eq "")
    {
        $MSIArgs = "/i " + $MSI

        
    }
    else
    {
        $MSIArgs = "/i " + $MSI + " " + $Arguments
    
    }
    Write-Verbose "Running Start-Process -FilePath msiexec.exe -ArgumentList $MSIArgs -NoNewWindow -Wait -Passthru"
    $ReturnFromEXE = Start-Process -FilePath msiexec.exe -ArgumentList $MSIArgs -NoNewWindow -Wait -Passthru
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}
Function Invoke-VIAMsu{
    [CmdletBinding(SupportsShouldProcess=$true)]

    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MSU,

        [parameter(mandatory=$false,position=1)]
        [string]
        $Arguments
    )

        #Set MSIArgs
    $MSUArgs = $MSU + " " + $Arguments

    if($Arguments -eq "")
    {
        $MSUArgs = $MSU

        
    }
    else
    {
        $MSUArgs = $MSU + " " + $Arguments
    
    }

    Write-Verbose "Running Start-Process -FilePath wusa.exe -ArgumentList $MSUArgs -NoNewWindow -Wait -Passthru"
    $ReturnFromEXE = Start-Process -FilePath wusa.exe -ArgumentList $MSUArgs -NoNewWindow -Wait -Passthru
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}

# Set Vars
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptName = Split-Path -Leaf $MyInvocation.MyCommand.Path
$SOURCEROOT = "$SCRIPTDIR\Source"
$LANG = (Get-Culture).Name
$OSV = $Null
$ARCHITECTURE = $env:PROCESSOR_ARCHITECTURE

#Try to Import SMSTSEnv
. Import-VIASMSTSENV

#Start Transcript Logging
. Start-VIALogging

#Detect current OS Version
. Get-VIAOSVersion -osv ([ref]$osv) 

#Output base info
Write-Output ""
Write-Output "$ScriptName - ScriptDir: $ScriptDir"
Write-Output "$ScriptName - SourceRoot: $SOURCEROOT"
Write-Output "$ScriptName - ScriptName: $ScriptName"
Write-Output "$ScriptName - OS Name: $osv"
Write-Output "$ScriptName - OS Architecture: $ARCHITECTURE"
Write-Output "$ScriptName - Current Culture: $LANG"
Write-Output "$ScriptName - Integration with MDT(LTI/ZTI): $MDTIntegration"
Write-Output "$ScriptName - Log: $LogFile"

#Generate more info
if($MDTIntegration -eq "YES"){
    $TSMake = $tsenv.Value("Make")
    $TSModel = $tsenv.Value("Model")
    $TSMakeAlias = $tsenv.Value("MakeAlias")
    $TSModelAlias = $tsenv.Value("ModelAlias")
    $TSOSDComputerName = $tsenv.Value("OSDComputerName")
    Write-Output "$ScriptName - Make:: $TSMake"
    Write-Output "$ScriptName - Model: $TSModel"
    Write-Output "$ScriptName - MakeAlias: $TSMakeAlias"
    Write-Output "$ScriptName - ModelAlias: $TSModelAlias"
    Write-Output "$ScriptName - OSDComputername: $TSOSDComputerName"
}

#Custom Code Starts--------------------------------------

switch ($SCVMRole)
{
    Full
    {
        #Create IniFile
        $unattendFilePath = "$env:TEMP\VMServer.ini"
        Write-Host "Unattendfile is $unattendFilePath"
        $unattendFile = New-Item $unattendFilePath -type File -Force
        set-Content $unattendFile "[OPTIONS]"
        if(!($SCVMMProductKey -eq "NONE"))
        {
            add-Content $unattendFile "ProductKey=$SCVMMProductKey"
        }
        add-Content $unattendFile "UserName=$SCVMMUserName"
        add-Content $unattendFile "CompanyName=$SCVMMCompanyName"
        add-Content $unattendFile "BitsTcpPort=$SCVMMBitsTcpPort"
        add-Content $unattendFile "VmmServiceLocalAccount=$SCVMMVmmServiceLocalAccount"
        add-Content $unattendFile "TopContainerName=$SCVMMTopContainerName"
        add-Content $unattendFile "VmmServiceDomain=$SCVMMDomain"
        add-Content $unattendFile "VmmServiceUserName=$SCVMMSAccount"
        add-Content $unattendFile "VmmServiceUserPassword=$SCVMMSAccountPW"
        add-Content $unattendFile "CreateNewLibraryShare=1"
        add-Content $unattendFile "LibraryShareName=MSSCVMMLibrary"
        add-Content $unattendFile "LibrarySharePath=$SCVMMLibraryDrive\ProgramData\Virtual Machine Manager Library Files"
        add-Content $unattendFile "LibraryShareDescription=VMM Library Share"
        add-Content $unattendFile "SqlMachineName=$env:COMPUTERNAME"
        add-Content $unattendFile "SqlInstanceName=MSSQLSERVER"
        Get-Content $unattendFile
    
        $Setup = $SCVMSetup
        $sArgument = "/server /i /f $unattendFile /VmmServiceDomain=$SCVMMDomain /VmmServiceUserName=$SCVMMSAccount /VmmServiceUserPassword=$SCVMMSAccountPW /IACCEPTSCEULA"
        Invoke-VIAExe -Executable $setup -Arguments $sArgument -Verbose
        #Get-Item -Path $unattendFile | Remove-Item -Force -Verbose
    }
    Client
    {
    }
    Agent
    {
    }
    Default
    {
    }
}


#Custom Code Ends--------------------------------------

. Stop-VIALogging

    param(
        [ValidateRange(1,128)]
        [int]$TotalPlots = 12,

        [ValidateRange(0,[int]::MaxValue)]
        [Alias("Delay")]
        [int]$DelayInSeconds = 60,

        [ValidateRange(3390,[int]::MaxValue)]
        [int]$Buffer = 3390,
        [ValidateRange(1,128)]
        [int]$Threads = 2,

        [Parameter(Mandatory)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [string]$TempDirectoryPath,
        [Parameter(Mandatory)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [string]$FinalDirectoryPath,
        [Parameter(Mandatory)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [string]$LogDirectoryPath = "$ENV:USERPROFILE\.chia\mainnet\plotter",

        [switch]$NoExit,

        [ValidateNotNullOrEmpty()]
        [string]$WindowTitle
    )

    if ($PSBoundParameters.ContainsKey("WindowTitle")){
        $AddTitle = "-WindowTitle $WindowTitle"
    }

    for ($Queue = 1; $Queue -le $TotalPlots;$Queue++){
        if ($NoExit){
            $NoExitFlag = "-NoExit"
        }
        $LogName = (Get-Date -Format yyyy_MM_dd_hh-mm-ss-tt_) + "plotlog-" + $Queue + ".log"
        $LogPath = Join-Path $LogDirectoryPath $LogName
        $processParam = @{
            FilePath = "powershell.exe"
            ArgumentList = "$NoExitFlag -Command .\Start-ChiaPlotting.ps1 -Buffer $Buffer -Threads $Threads -TempDirectoryPath $TempDirectoryPath -FinalDirectoryPath $FinalDirectoryPath -LogDirectoryPath $LogDirectoryPath -Auto -LogName $LogName -QueueName Queue_$Queue $AddTitle"
        }
        $thisPlot = Start-Process @processParam -PassThru
        Start-Sleep -Seconds 10
        $LogFile = Get-Content -Path $LogPath
        $line_count = $LogFile.Count
        while (!$thisPlot.HasExited -and $line_count -le 801){
            Start-Sleep -Seconds $DelayInSeconds
            $LogFile = Get-Content -Path $LogPath
            $line_count = $LogFile.Count
        }
    } #for
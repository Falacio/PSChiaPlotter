function New-UIRunspace{
    [powershell]::Create().AddScript{
        $ErrorActionPreference = "Stop"
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName System.Windows.Forms
        #[System.Windows.Forms.MessageBox]::Show("Hello")
        #Import required assemblies and private functions
        
        Try{
            Get-childItem -Path $DataHash.PrivateFunctions -File | ForEach-Object {Import-Module $_.FullName}
            Get-childItem -Path $DataHash.Classes -File | ForEach-Object {Import-Module $_.FullName}

            Import-Module -Name PSChiaPLotter
    
            $XAMLPath = Join-Path -Path $DataHash.WPF -ChildPath MainWindow.xaml
            $MainWindow = Import-Xaml -Path $XAMLPath

            #Assign GUI Controls To Variables
            $UIHash.MainWindow = $MainWindow
            $UIHash.Jobs_DataGrid = $MainWindow.FindName("Jobs_DataGrid")
            $UIHash.Queues_DataGrid = $MainWindow.FindName("Queues_DataGrid")
            $UIHash.Runs_DataGrid = $MainWindow.FindName("Runs_DataGrid")
            $UIHash.CompletedRuns_DataGrid = $MainWindow.FindName("CompletedRuns_DataGrid")
            $UIHash.Refreshdrives_Button = $MainWindow.FindName("RefreshdrivesButton")
            #$UIHash.LogLevel_Combobox = $MainWindow.FindName("LogLevelCombobox")
            $UIHash.CheckForUpdate_Button = $MainWindow.FindName("CheckForUpateButton")
            $UIHash.OpenLog_Button = $MainWindow.FindName("OpenLogButton")
            $DataHash.RefreshingDrives = $false

            $UIHash.NewJob_Button = $MainWindow.FindName("AddJob_Button")

            $DataHash.MainViewModel = [PSChiaPlotter.MainViewModel]::new()
            $DataHash.MainViewModel.Version = (Get-Module -Name PSChiaPlotter).Version.ToString()
            $DataHash.MainViewModel.LogPath = $DataHash.LogPath
            $DataHash.MainViewModel.LogLevel = "Info"
            #$UIHash.LogLevel_Combobox.SelectedIndex = 0
            $UIHash.MainWindow.DataContext = $DataHash.MainViewModel

            #Add Master Copy of volumes to MainViewModel these are used to keep track of
            # all jobs that are running on the drives
            Get-ChiaVolume | foreach {
                $DataHash.MainViewModel.AllVolumes.Add($_)
            }

            #ButtonClick
            $UIHash.NewJob_Button.add_Click({
                try{
                    #Get-childItem -Path $DataHash.Classes -File | ForEach-Object {Import-Module $_.FullName}
                    $XAMLPath = Join-Path -Path $DataHash.WPF -ChildPath NewJobWindow.xaml
                    $UIHash.NewJob_Window = Import-Xaml -Path $XAMLPath
                    $jobNumber = $DataHash.MainViewModel.AllJobs.Count + 1
                    $newJob = [PSChiaPlotter.ChiaJob]::new()
                    $newJob.JobNumber = $jobNumber
                    $newJob.JobName = "Job $jobNumber"
                    $NewJobViewModel = [PSChiaPlotter.NewJobViewModel]::new($newJob)

                    #need to run get-chiavolume twice or the temp and final drives will be the same object in the application and will update each other...
                    Get-ChiaVolume | foreach {
                        $NewJobViewModel.TempAvailableVolumes.Add($_)
                    }
                    Get-ChiaVolume | foreach {
                        $NewJobViewModel.FinalAvailableVolumes.Add($_)
                    }

                    $newJob.Status = "Waiting"
                    $UIHash.NewJob_Window.DataContext = $NewJobViewModel
                    $CreateJob_Button = $UIHash.NewJob_Window.FindName("CreateJob_Button")
                    $CreateJob_Button.add_Click({
                        try{
                            $Results = Test-ChiaParameters $newJob
                            if ($NewJob.DelayInMinutes -eq 60){
                                $response = Show-Messagebox -Text "You left the default delay time of 60 Minutes, continue?" -Button YesNo
                                if ($response -eq [System.Windows.MessageBoxResult]::No){
                                    return
                                }
                            }
                            if ($Results -ne $true){
                                Show-Messagebox -Text $Results -Title "Invalid Parameters" -Icon Warning
                                return
                            }
                            $DataHash.MainViewModel.AllJobs.Add($newJob)
                            $newJobRunSpace = New-ChiaJobRunspace -Job $newJob
                            $newJobRunSpace.Runspacepool = $ScriptsHash.RunspacePool
                            [void]$newJobRunSpace.BeginInvoke()
                            $DataHash.Runspaces.Add($newJobRunSpace)
                            $UIHash.NewJob_Window.Close()
                        }
                        catch{
                            Show-Messagebox -Text $_.Exception.Message -Title "Create New Job Error" -Icon Error
                        }
                    })

                    $CancelJobCreation_Button = $UIHash.NewJob_Window.FindName("CancelJobCreation_Button")
                    $CancelJobCreation_Button.Add_Click({
                        try{
                            $UIHash.NewJob_Window.Close()
                        }
                        catch{
                            Show-Messagebox -Text $_.Exception.Message -Title "Exit New Job Window Error" -Icon Error
                        }
                    })
    
                    $UIHash.NewJob_Window.ShowDialog()
                }
                catch{
                    Show-Messagebox -Text $_.Exception.Message -Title "Create New Job Error" -Icon Error
                }
            })

            $UIHash.Refreshdrives_Button.Add_Click({
                try{
                    if ($DataHash.RefreshingDrives){
                        Show-Messagebox -Text "A drive refresh is currently in progress" -Icon Information
                        return
                    }
                    $DataHash.RefreshingDrives = $true
                    Update-ChiaVolume -ErrorAction Stop
                    $DataHash.RefreshingDrives = $false
                }
                catch{
                    $DataHash.RefreshingDrives = $false
                    Show-Messagebox -Text $_.Exception.Message -Title "Refresh Drives" -Icon Error
                }
            })

            $UIHash.CheckForUpdate_Button.Add_Click({
                try{
                    Update-PSChiaPlotter
                }
                catch{
                    Write-PSChiaPlotterLog -LogType ERROR -LineNumber $_.InvocationInfo.ScriptLineNumber -Message $_.Exception.Message
                    Show-Messagebox "Unable to check for updates... check logs for more info" | Out-Null
                }
            })

            $UIHash.OpenLog_Button.Add_Click({
                try{
                    Invoke-Item -Path $DataHash.MainViewModel.LogPath -ErrorAction Stop
                }
                catch{
                    Write-PSChiaPlotterLog -LogType ERROR -LineNumber $_.InvocationInfo.ScriptLineNumber -Message $_.Exception.Message
                    Show-Messagebox "Unable to open log file, check the path '$($DataHash.MainViewModel.LogPath)'" | Out-Null
                }
            })

            #$ScriptsHash.QueueHandle = $ScriptsHash.QueueRunspace.BeginInvoke()

            $UIHash.MainWindow.add_Closing({
                Get-childItem -Path $DataHash.PrivateFunctions -File | ForEach-Object {Import-Module $_.FullName}
                # end session and close runspace on window exit
                $DialogResult = Show-Messagebox -Text "Closing this window will end all Chia processes" -Title "Warning!" -Icon Warning -Buttons OKCancel
                if ($DialogResult -eq [System.Windows.MessageBoxResult]::Cancel) {
                    $PSItem.Cancel = $true
                }
                else{
                    #$ScriptsHash.QueueHandle.EndInvoke($QueueHandle)
                    Stop-PSChiaPlotter
                }
            })

            $MainWindow.ShowDialog()


        }
        catch{
            $Message = "$($_.Exception.Message)"
            $Message += "`nLine # -$($_.InvocationInfo.ScriptLineNumber )"
            $Message += "`nLine - $($_.InvocationInfo.Line)"
            Show-Messagebox -Text $Message -Title "UI Runspace Error" -Icon Error
        }
    }
}
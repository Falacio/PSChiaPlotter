Star-ChiaAutoPlotting Help

-params (default value):

	TotalPlots (12)
	Delay (60)
	Buffer (3390)
	Threads (2)
	TempDirectoryPath [MANDATORY]
	FinalDirectoryPath [MANDATORY]
	LogDirectoryPath ("$ENV:USERPROFILE\.chia\mainnet\plotter)
	NoExit(False)



The script creates a plotting queue without temporal delays or staggering. After the first plot is kicked, it waits for it to end phase 1 (or stop) and after that, kicks another plot. When this one finishes phase 1 or stops, kicks another and so on, until $TotalPlots have been made.

Delay in seconds is the interval time to check if last process has finished phase 1.

Examples
 - Basic Automode (will do 12 plots, with standard settings and 60 seconds refresh window. Logs in default chia logs folder)
	.\Get-ChiaAutoPlotting.ps1 -TempDirectoryPath D:\MyTempPath -FinalDirectoryPath D:\MyPlotsPath

 - Custom mode 
	.\Get-ChiaAutoPlotting.ps1 -TotalPlots 24 -Delay 30 -Buffer 4000 -Threads 4 -TempDirectoryPath D:\MyTempPath FinalDirectoryPath D:\MyPlotsPath -LogDirectoryPath D:\MyLogPath
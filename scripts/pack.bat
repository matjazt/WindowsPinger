@SET SVCWATCHDOGFOLDER=..\..\SvcWatchDog\dist
@SET OUTPUTFOLDER=..\dist

@echo Folder %OUTPUTFOLDER% will be deleted and recreated. If you don't want this, press ctrl-c.

pause

if exist %OUTPUTFOLDER% rd /s /q %OUTPUTFOLDER%

mkdir %OUTPUTFOLDER%\scripts
mkdir %OUTPUTFOLDER%\service
mkdir %OUTPUTFOLDER%\doc\SvcWatchDog

copy /y %SVCWATCHDOGFOLDER%\SvcWatchDog\SvcWatchDog.exe %OUTPUTFOLDER%\Service\WindowsPingerService.exe
copy /y %SVCWATCHDOGFOLDER%\Doc\* %OUTPUTFOLDER%\Doc\SvcWatchDog

copy /y ..\scripts\*.ps1 %OUTPUTFOLDER%\scripts
copy /y ..\README.md %OUTPUTFOLDER%\doc

copy /y ..\Etc\WindowsPingerService.json %OUTPUTFOLDER%\Service

pause
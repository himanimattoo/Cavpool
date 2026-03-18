# run_flutter.ps1
# Automatically start emulator and run Flutter app

# Name of your emulator (from emulator -list-avds)
$emulatorName = "Pixel_6"

# Path to emulator.exe
$emulatorPath = "$env:USERPROFILE\AppData\Local\Android\Sdk\emulator\emulator.exe"

# Check if any emulator is running
$emulatorRunning = (& "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices) -match "emulator-"

if (-not $emulatorRunning) {
    Write-Host "Starting Android emulator $emulatorName..."
    Start-Process -NoNewWindow -FilePath $emulatorPath -ArgumentList "-avd $emulatorName" 
    Write-Host "Waiting for emulator to fully boot..."
    & "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe" wait-for-device
    Start-Sleep -Seconds 15
}

Write-Host "Running Flutter app..."
flutter run
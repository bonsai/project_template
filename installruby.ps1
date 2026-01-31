# PowerShell Script to Install Ruby and Required Gems
# Enhanced version with self-elevation and better user experience

# Self-elevation function
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Elevation {
    if (-not (Test-Administrator)) {
        Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Attempting to restart with elevated privileges..." -ForegroundColor Yellow
        
        $scriptPath = $MyInvocation.MyCommand.Path
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        
        try {
            Start-Process powershell -ArgumentList $arguments -Verb RunAs -Wait
            exit 0
        } catch {
            Write-Host "Failed to elevate privileges. Please run this script as Administrator manually." -ForegroundColor Red
            Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Cyan
            pause
            exit 1
        }
    }
}

# Request elevation if not running as admin
Request-Elevation

# Now we're running as administrator
Write-Host "=== Ruby Installation Script ===" -ForegroundColor Green
Write-Host "Running with Administrator privileges ✓" -ForegroundColor Green

# Function to test if a command exists
function Test-Command {
    param($Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to show progress
function Show-Progress {
    param($Activity, $Status)
    Write-Host "[$Activity] $Status" -ForegroundColor Cyan
}

# Check if Ruby is already installed
if (Test-Command "ruby") {
    $rubyVersion = ruby --version
    Write-Host "Ruby is already installed: $rubyVersion" -ForegroundColor Green
    
    # Ask if user wants to reinstall
    $response = Read-Host "Do you want to reinstall/update Ruby? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping Ruby installation. Proceeding with gem check..." -ForegroundColor Yellow
        $skipRubyInstall = $true
    }
}

if (-not $skipRubyInstall) {
    Show-Progress "Ruby" "Starting Ruby installation..."
    
    # Download RubyInstaller
    $rubyInstallerUrl = "https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.2.2-1/rubyinstaller-devkit-3.2.2-1-x64.exe"
    $installerPath = "$env:TEMP\rubyinstaller.exe"
    
    Show-Progress "Download" "Downloading RubyInstaller (this may take a while)..."
    try {
        # Show download progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFileAsync($rubyInstallerUrl, $installerPath)
        
        # Wait for download to complete
        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 100
        }
        
        Write-Host "Download completed successfully!" -ForegroundColor Green
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Failed to download RubyInstaller: $errorMsg" -ForegroundColor Red
        Write-Host "You can manually download from: https://rubyinstaller.org/" -ForegroundColor Yellow
        pause
        exit 1
    }
    
    # Install Ruby silently
    Show-Progress "Installation" "Installing Ruby (this may take a few minutes)..."
    try {
        $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/silent", "/tasks=assocfiles,modpath" -PassThru -Wait
        
        if ($installProcess.ExitCode -eq 0) {
            Write-Host "Ruby installation completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Ruby installation failed with exit code: $($installProcess.ExitCode)" -ForegroundColor Red
            pause
            exit 1
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Failed to install Ruby: $errorMsg" -ForegroundColor Red
        pause
        exit 1
    }
    
    # Clean up installer
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    
    # Refresh PATH environment variable
    Show-Progress "Environment" "Refreshing environment variables..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Verify installation
    if (Test-Command "ruby") {
        $rubyVersion = ruby --version
        Write-Host "Ruby installed successfully: $rubyVersion" -ForegroundColor Green
    } else {
        Write-Host "Ruby installation verification failed." -ForegroundColor Red
        Write-Host "Please restart PowerShell and try again." -ForegroundColor Yellow
        pause
        exit 1
    }
}

# Check if gem command is available
if (Test-Command "gem") {
    Write-Host "Gem command is available ✓" -ForegroundColor Green
} else {
    Write-Host "Gem command not found. There might be an issue with Ruby installation." -ForegroundColor Red
    pause
    exit 1
}

# Install required gems
Show-Progress "Gems" "Installing required gems..."

# Update RubyGems first
Show-Progress "RubyGems" "Updating RubyGems system..."
try {
    gem update --system --no-document
    Write-Host "RubyGems updated successfully!" -ForegroundColor Green
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "Warning: Could not update RubyGems: $errorMsg" -ForegroundColor Yellow
}

# Install bundler
Show-Progress "Bundler" "Installing bundler..."
try {
    gem install bundler --no-document
    Write-Host "Bundler installed successfully!" -ForegroundColor Green
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "Warning: Could not install bundler: $errorMsg" -ForegroundColor Yellow
}

# Install gems from Gemfile if it exists
$gemfilePath = "Gemfile"
if (Test-Path $gemfilePath) {
    Show-Progress "Gemfile" "Found Gemfile. Installing gems using bundler..."
    try {
        bundle install
        Write-Host "Gems from Gemfile installed successfully!" -ForegroundColor Green
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Warning: Bundle install failed: $errorMsg" -ForegroundColor Yellow
        Write-Host "Falling back to individual gem installation..." -ForegroundColor Yellow
    }
} else {
    Write-Host "No Gemfile found. Installing individual gems..." -ForegroundColor Yellow
}

# Install individual gems as fallback
$requiredGems = @("webrick", "chunky_png")
foreach ($gem in $requiredGems) {
    Show-Progress "Gem" "Installing $gem..."
    try {
        gem install $gem --no-document
        Write-Host "$gem installed successfully!" -ForegroundColor Green
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("Failed to install {0}: {1}" -f $gem, $errorMessage) -ForegroundColor Red
    }
}

# Verify gem installations
Show-Progress "Verification" "Verifying gem installations..."
$verificationFailed = $false
foreach ($gem in $requiredGems) {
    try {
        $installed = gem list $gem | Out-String
        if ($installed -match $gem) {
            Write-Host "$gem is installed ✓" -ForegroundColor Green
        } else {
            Write-Host "$gem is NOT installed ✗" -ForegroundColor Red
            $verificationFailed = $true
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host ("Could not verify {0}: {1}" -f $gem, $errorMsg) -ForegroundColor Red
        $verificationFailed = $true
    }
}

# Test CGI script
Show-Progress "Testing" "Testing CGI script syntax..."
$cgiscript = "cgi-bin\ruby.cgi"
if (Test-Path $cgiscript) {
    try {
        $syntaxCheck = ruby -c $cgiscript 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "CGI script syntax is valid ✓" -ForegroundColor Green
        } else {
            Write-Host "CGI script has syntax errors ✗" -ForegroundColor Red
            Write-Host "Error: $syntaxCheck" -ForegroundColor Red
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Error testing CGI script: $errorMsg" -ForegroundColor Red
    }
} else {
    Write-Host "CGI script not found at $cgiscript" -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "=== Installation Summary ===" -ForegroundColor Green

if (Test-Command "ruby") {
    $rubyVersion = ruby --version
    Write-Host "Ruby: $rubyVersion ✓" -ForegroundColor Green
} else {
    Write-Host "Ruby: NOT INSTALLED ✗" -ForegroundColor Red
}

foreach ($gem in $requiredGems) {
    try {
        $installed = gem list $gem | Out-String
        if ($installed -match $gem) {
            Write-Host ("{0}: Installed ✓" -f $gem) -ForegroundColor Green
        } else {
            Write-Host ("{0}: Not installed ✗" -f $gem) -ForegroundColor Red
        }
    } catch {
        Write-Host ("{0}: Unknown status" -f $gem) -ForegroundColor Yellow
    }
}

Write-Host ""
if ($verificationFailed) {
    Write-Host "Some components failed to install. Please check the error messages above." -ForegroundColor Red
} else {
    Write-Host "All components installed successfully!" -ForegroundColor Green
    Write-Host "You can now run your Ruby CGI script!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Test your CGI script: ruby cgi-bin\ruby.cgi" -ForegroundColor White
Write-Host "2. Set up a web server to serve the CGI script" -ForegroundColor White
Write-Host "3. Configure your web server to execute CGI scripts" -ForegroundColor White

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

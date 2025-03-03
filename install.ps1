# Apache Kafka Installation Script for Windows
# Author: DanSP
# Version: 1.6
# Description: Installs Kafka in KRaft mode (without Zookeeper), checks disk space and installs Java (JDK) if needed.
#             Everything is installed on the system root drive (Example: C:\).

# Author URL: https://github.com/dansp89
# Project URL: https://github.com/dansp89/kafka-for-windows

# Function to create an interactive paginated list
function Show-InteractiveMenu {
    param (
        [string[]]$Options,
        [string]$Title = "Select an option"
    )
    $selectedIndex = 0
    $optionsCount = $Options.Length
    $pageSize = 5  # Number of items displayed at a time
    $pageStart = 0  # Initial index of the current page

    # Configure CTRL + C handling
    $originalCtrlC = [Console]::TreatControlCAsInput
    [Console]::TreatControlCAsInput = $true

    try {
        # Loop to display the interactive menu
        while ($true) {
            Clear-Host
            Write-Host "=== $Title ===" -ForegroundColor Cyan

            # Display items on the current page
            for ($i = $pageStart; $i -lt ($pageStart + $pageSize); $i++) {
                if ($i -ge $optionsCount) { break }  # Avoid exceeding the number of items
                if ($i -eq $selectedIndex) {
                    Write-Host "> $($Options[$i])" -ForegroundColor Green
                }
                else {
                    Write-Host "  $($Options[$i])"
                }
            }

            # Display instructions
            Write-Host "`nUse the arrows to navigate, PgUp/PgDn to scroll, Enter to select or CTRL + C to exit." -ForegroundColor Yellow

            # Capture the pressed key
            $keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            $key = $keyInfo.VirtualKeyCode
            $ctrlPressed = ($keyInfo.ControlKeyState -band [System.ConsoleModifiers]::Control) -ne 0

            # Check if CTRL + C was pressed
            if ($ctrlPressed -and $key -eq 67) {
                # 67 is the code for the 'C' key
                Write-Host "`nApplication terminated by user (CTRL + C)." -ForegroundColor Red
                exit
            }

            # Navigate through options
            switch ($key) {
                38 {
                    # Up arrow key
                    $selectedIndex = ($selectedIndex - 1) % $optionsCount
                    if ($selectedIndex -lt 0) { $selectedIndex = $optionsCount - 1 }

                    # Adjust the page if necessary
                    if ($selectedIndex -lt $pageStart) {
                        $pageStart = $selectedIndex
                    }
                }
                40 {
                    # Down arrow key
                    $selectedIndex = ($selectedIndex + 1) % $optionsCount

                    # Adjust the page if necessary
                    if ($selectedIndex -ge ($pageStart + $pageSize)) {
                        $pageStart = $selectedIndex - $pageSize + 1
                    }
                }
                33 {
                    # PgUp (Page Up) key
                    $pageStart = [math]::Max(0, $pageStart - $pageSize)
                    $selectedIndex = [math]::Max(0, $selectedIndex - $pageSize)
                }
                34 {
                    # PgDn (Page Down) key
                    $pageStart = [math]::Min($optionsCount - $pageSize, $pageStart + $pageSize)
                    $selectedIndex = [math]::Min($optionsCount - 1, $selectedIndex + $pageSize)
                }
                13 {
                    # Enter key
                    return $Options[$selectedIndex]
                }
            }
        }
    }
    finally {
        # Restore original CTRL + C behavior
        [Console]::TreatControlCAsInput = $originalCtrlC
    }
}

# Function to check disk space
function Get-DiskSpace {
    $requiredSpace = 1GB  # Space required for Kafka and Java (JDK) (adjust as needed)
    $disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq "C:\" }

    # Display free disk space in GB
    $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
    Write-Host "Free disk space (C:): $freeSpaceGB GB" -ForegroundColor Cyan

    if ($disk.Free -lt $requiredSpace) {
        Write-Host "Error: Insufficient disk space. At least 1 GB of free space is required." -ForegroundColor Red
        exit
    }
    else {
        Write-Host "Sufficient disk space found." -ForegroundColor Green
    }
}

# Function to get available Java (JDK) versions
function Get-JavaVersions {
    Write-Host "Getting available Java (OpenJDK) versions..." -ForegroundColor Yellow
    $url = "https://jdk.java.net/archive/"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $versions = $response.Links | Where-Object { $_.outerHTML -match "jdk-\d+\.\d+\.\d+" } | ForEach-Object {
        if ($_.outerHTML -match "jdk-(\d+\.\d+\.\d+)") {
            $matches[1]
        }
    } | Sort-Object { [System.Version]$_ } -Descending | Select-Object -Unique

    return $versions
}

# Function to get the download link for the selected Java version
function Get-JavaDownloadUrl {
    param ([string]$javaVersion)

    $url = "https://jdk.java.net/archive/"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing

    # Corrected regex to find the correct download link
    $pattern = "https://download.java.net/java/GA/jdk$javaVersion/[^/]+/[^/]+/GPL/openjdk-$javaVersion.*?_windows-x64_bin\.zip"

    # Search for the download link in the response content
    $match = [regex]::Match($response.Content, $pattern)
    Write-Host $match.Success

    if ($match.Success) {
        Write-Host "Download link found: $($match.Value)"
    }
    else {
        Write-Host "Error: Unable to find the download link for JDK $javaVersion"
    }

    return $match.Value
}

# Function to install Java (JDK)
function Install-Java {
    param (
        [string]$javaVersion = $null
    )

    # If the version is not provided, get the version from the user
    if (-not $javaVersion) {
        $javaVersion = Get-JavaVersion
    }

    # Try to get the download link for the specified version
    $javaUrl = Get-JavaDownloadUrl -javaVersion $javaVersion

    if (-not $javaUrl) {
        Write-Host "Error: Unable to find the download link for JDK $javaVersion." -ForegroundColor Red

        # Show list of available versions
        Write-Host "Available Java (OpenJDK) versions:" -ForegroundColor Yellow
        $javaVersions = Get-JavaVersions
        $selectedVersion = Show-InteractiveMenu -Options $javaVersions -Title "Select a Java (JDK) version"
        if ($selectedVersion) {
            $javaVersion = $selectedVersion -replace " \(.*\)", ""  # Remove the date from the selected version
            Write-Host "Installing the selected version: $javaVersion" -ForegroundColor Green
            Install-Java -javaVersion $javaVersion
        }
        else {
            Write-Host "Installation cancelled by user." -ForegroundColor Red
            return
        }
    }
    else {
        # Proceed with installing the specified version
        $javaZip = "$env:TEMP\openjdk.zip"
        $javaExtractPath = "C:\Java\jdk-$javaVersion-temp"
        $javaDir = "C:\Java\jdk-$javaVersion"

        # Remove temporary directory if it already exists
        if (Test-Path $javaExtractPath) {
            Remove-Item -Recurse -Force $javaExtractPath
        }

        # Create temporary directory
        New-Item -ItemType Directory -Path $javaExtractPath | Out-Null

        # Download and extract OpenJDK
        Write-Host "Downloading OpenJDK $javaVersion..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $javaUrl -OutFile $javaZip
            Expand-Archive -Path $javaZip -DestinationPath $javaExtractPath -Force
            Remove-Item -Path $javaZip -Force
        }
        catch {
            Write-Host "Error: Failed to download or extract JDK $javaVersion." -ForegroundColor Red
            Write-Host "Error details: $_" -ForegroundColor Red
            return
        }

        # Find the actual extracted JDK folder
        $jdkFolder = Get-ChildItem -Path $javaExtractPath | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty FullName

        if (-not $jdkFolder) {
            Write-Host "Error: Unable to find the extracted JDK folder." -ForegroundColor Red
            return
        }

        Write-Host "Extracted JDK folder: $jdkFolder" -ForegroundColor Green

        # Remove destination directory if it already exists
        if (Test-Path $javaDir) {
            Write-Host "Removing existing destination directory: $javaDir" -ForegroundColor Yellow
            Remove-Item -Recurse -Force $javaDir
        }

        # Create destination directory
        New-Item -ItemType Directory -Path $javaDir | Out-Null

        # Move the entire JDK structure to the destination directory
        Write-Host "Moving the entire JDK structure..." -ForegroundColor Yellow
        Move-Item -Path "$jdkFolder\*" -Destination $javaDir -Force

        # Remove temporary directory
        Remove-Item -Recurse -Force $javaExtractPath

        # Configure environment variables
        $javaBin = "$javaDir\bin"

        # Remove references to previous Java versions from the PATH
        try {
            # Remove old JAVA_HOME
            $oldJavaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", [System.EnvironmentVariableTarget]::Machine)
            if ($oldJavaHome) {
                [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $null, [System.EnvironmentVariableTarget]::Machine)
                Write-Host "Old JAVA_HOME variable removed: $oldJavaHome" -ForegroundColor Yellow
            }

            # Remove old Java (JDK) references from the PATH
            $envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
            $newEnvPath = ($envPath -split ';' | Where-Object { $_ -notmatch "Java|jdk" }) -join ';'
            [System.Environment]::SetEnvironmentVariable("Path", $newEnvPath, [System.EnvironmentVariableTarget]::Machine)
            Write-Host "Old Java references removed from the PATH." -ForegroundColor Yellow

            # Add the new Java version to the PATH
            [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaDir, [System.EnvironmentVariableTarget]::Machine)
            [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$javaBin", [System.EnvironmentVariableTarget]::Machine)
            Write-Host "JAVA_HOME and PATH variables configured in the Machine scope." -ForegroundColor Green
        }
        catch {
            # If failed, try in the User scope
            $oldJavaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", [System.EnvironmentVariableTarget]::User)
            if ($oldJavaHome) {
                [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $null, [System.EnvironmentVariableTarget]::User)
                Write-Host "Old JAVA_HOME variable removed: $oldJavaHome" -ForegroundColor Yellow
            }

            $envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
            $newEnvPath = ($envPath -split ';' | Where-Object { $_ -notmatch "Java|jdk" }) -join ';'
            [System.Environment]::SetEnvironmentVariable("Path", $newEnvPath, [System.EnvironmentVariableTarget]::User)
            Write-Host "Old Java references removed from the PATH." -ForegroundColor Yellow

            [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaDir, [System.EnvironmentVariableTarget]::User)
            [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$javaBin", [System.EnvironmentVariableTarget]::User)
            Write-Host "JAVA_HOME and PATH variables configured in the User scope (running without administrator privileges)." -ForegroundColor Yellow
        }

        # Update the environment variable in the current session
        $env:JAVA_HOME = $javaDir
        $env:Path = ($env:Path -split ';' | Where-Object { $_ -notmatch "Java|jdk" }) -join ';'
        $env:Path += ";$javaBin"

        Write-Host "Java (JDK) $javaVersion installed successfully in $javaDir." -ForegroundColor Green
    }
}

# Function to get available Kafka versions
function Get-KafkaVersions {
    Write-Host "Getting available Kafka versions..." -ForegroundColor Yellow
    $url = "https://downloads.apache.org/kafka/"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $versions = $response.Links | Where-Object { $_.outerHTML -match "\d+\.\d+\.\d+" } | ForEach-Object {
        if ($_.outerHTML -match "(\d+\.\d+\.\d+)") {
            $matches[1]
        }
    } | Sort-Object -Descending

    return $versions
}

# Function to choose the Kafka version using an interactive menu
function Get-KafkaVersion {
    $versions = Get-KafkaVersions
    Write-Host "Select the Kafka version (use the arrows to navigate, PgUp/PgDn to scroll and Enter to select):" -ForegroundColor Cyan
    return Show-InteractiveMenu -Options $versions -Title "Kafka versions"
}

# Function to install Kafka
function Install-Kafka {
    param (
        [string]$kafkaVersion = $null
    )

    # If the version is not provided, get the version from the user
    if (-not $kafkaVersion) {
        $kafkaVersion = Get-KafkaVersion
    }

    $kafkaUrl = "https://downloads.apache.org/kafka/$kafkaVersion/kafka_2.13-$kafkaVersion.tgz"
    $kafkaTar = "$env:TEMP\kafka.tgz"
    $kafkaDir = "C:\kafka"

    # Remove old installation, if exists
    if (Test-Path $kafkaDir) {
        Write-Host "Removing old Kafka installation in $kafkaDir..." -ForegroundColor Yellow
        try {
            Remove-Item -Recurse -Force $kafkaDir -ErrorAction Stop
            Write-Host "Old installation removed successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Error: Unable to remove the old installation. Check permissions or if Kafka is running." -ForegroundColor Red
            Write-Host "Error details: $_" -ForegroundColor Red
            return
        }
    }

    # Create directory for Kafka
    Write-Host "Creating directory for Kafka in $kafkaDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $kafkaDir | Out-Null

    # Download Kafka
    Write-Host "Downloading Apache Kafka $kafkaVersion..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $kafkaUrl -OutFile $kafkaTar
    }
    catch {
        Write-Host "Error: Failed to download Kafka. Check your internet connection." -ForegroundColor Red
        return
    }

    # Check if the tar command is available
    if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
        Write-Host "Error: The tar command is not available on the system. Please install tar or use Windows 10 or later." -ForegroundColor Red
        return
    }

    # Extract Kafka using tar
    Write-Host "Extracting Kafka..." -ForegroundColor Yellow
    tar -xzf $kafkaTar -C $kafkaDir --strip-components=1

    # =======================================
    # KRAFT MODE CONFIGURATION (WITHOUT ZOOKEEPER)
    # =======================================

    Write-Host "Configuring Kafka in KRaft mode (without Zookeeper)..." -ForegroundColor Yellow

    # Generate a unique cluster ID
    $clusterId = & "$kafkaDir\bin\windows\kafka-storage.bat" random-uuid
    $clusterId = $clusterId.Trim()
    Write-Host "Cluster ID generated: $clusterId" -ForegroundColor Cyan

    # Configure server.properties for KRaft mode
    $serverConfig = "$kafkaDir\config\server.properties"
    $kafkaLogsDir = "$kafkaDir\kafka-logs"  # Correct path to the logs directory

    # Use double backslashes in the path to avoid escape issues
    $kafkaLogsDirEscaped = $kafkaLogsDir -replace "\\", "\\"

    Set-Content -Path $serverConfig -Value @"
# KRaft mode configurations
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093
listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093
controller.listener.names=CONTROLLER
log.dirs=$kafkaLogsDirEscaped
"@

    # Clear the logs directory, if exists
    if (Test-Path $kafkaLogsDir) {
        Write-Host "Removing old logs directory: $kafkaLogsDir" -ForegroundColor Yellow
        try {
            # Force removal of the logs directory
            Remove-Item -Recurse -Force $kafkaLogsDir -ErrorAction Stop
            Write-Host "Logs directory removed successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Error: Unable to remove the logs directory. Check permissions or if Kafka is running." -ForegroundColor Red
            Write-Host "Error details: $_" -ForegroundColor Red
            return
        }
    }

    # Format Kafka storage
    Write-Host "Formatting Kafka storage..." -ForegroundColor Yellow
    try {
        # Run the format command
        & "$kafkaDir\bin\windows\kafka-storage.bat" format --config "$serverConfig" --cluster-id $clusterId

        # Check if the meta.properties file was created correctly
        $metaPropertiesPath = "$kafkaLogsDir\meta.properties"
        if (Test-Path $metaPropertiesPath) {
            $metaPropertiesContent = Get-Content -Path $metaPropertiesPath -Raw
            Write-Host "Content of meta.properties file:" -ForegroundColor Cyan
            Write-Host $metaPropertiesContent -ForegroundColor Green
            $metas = $metaPropertiesContent -match "cluster\.id=([^\n]+)"
            Write-Host "Cluster METAS:\n" $metas

            # Check if the cluster.id in meta.properties matches the generated one
            if ($metaPropertiesContent -match "cluster\.id=([^\n]+)") {
                $foundClusterId = $matches[1].Trim()
                if ($foundClusterId -eq $clusterId) {
                    Write-Host "Cluster ID in meta.properties is correct." -ForegroundColor Green
                }
                else {
                    Write-Host "Error: Cluster ID in meta.properties does not match the generated one." -ForegroundColor Red
                    Write-Host "Expected: $clusterId" -ForegroundColor Red
                    Write-Host "Found: $foundClusterId" -ForegroundColor Red
                    return
                }
            }
            else {
                Write-Host "Error: Unable to find the cluster.id in meta.properties." -ForegroundColor Red
                return
            }
        }
        else {
            Write-Host "Error: meta.properties file was not created." -ForegroundColor Red
            return
        }

        Write-Host "Storage formatted successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error formatting Kafka storage." -ForegroundColor Red
        Write-Host "Error details: $_" -ForegroundColor Red
        return
    }

    # Remove the downloaded .tgz file
    Remove-Item -Path $kafkaTar -Force

    Write-Host "Kafka $kafkaVersion installed and configured successfully in $kafkaDir." -ForegroundColor Green

    # Ask the user if they want to run a demo/example
    $runDemo = Read-Host "Do you want to run a Kafka demo/example? (Y/N)"

    if ($runDemo -eq "Y" -or $runDemo -eq "y") {
        # Check if Kafka was installed correctly
        if (Test-Path "C:\kafka") {
            # Run the test
            Test-ExampleKafka -kafkaDir $kafkaDir
        }
        else {
            Write-Host "Kafka was not installed correctly. Check the installation." -ForegroundColor Red
        }
    }
    else {
        Write-Host "Installation completed. You can start Kafka manually when needed." -ForegroundColor Green
    }
}

# Function to test the basic Kafka example
function Test-ExampleKafka {
    param (
        [string]$kafkaDir
    )

    Write-Host "`nStarting basic Kafka example..." -ForegroundColor Cyan

    # Check if Kafka is already running
    $kafkaProcess = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*kafka*"
    }

    if ($kafkaProcess) {
        Write-Host "Kafka is already running. Stopping the process..." -ForegroundColor Yellow
        Stop-Process -Id $kafkaProcess.Id -Force
    }

    # Start Kafka
    Write-Host "Starting Kafka..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start cmd.exe /k `"$kafkaDir\bin\windows\kafka-server-start.bat $kafkaDir\config\server.properties`""
    Start-Sleep -Seconds 10  # Wait for Kafka to start

    # Check if Kafka was started correctly
    $kafkaProcess = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*kafka*"
    }

    if (-not $kafkaProcess) {
        Write-Host "Error: Kafka was not started correctly." -ForegroundColor Red
        return
    }

    # Check if the topic already exists and delete it if necessary
    $topicExists = & "$kafkaDir\bin\windows\kafka-topics.bat" --list --bootstrap-server localhost:9092 | Select-String -Pattern "test-topic"
    if ($topicExists) {
        Write-Host "The 'test-topic' topic already exists. Deleting..." -ForegroundColor Yellow
        & "$kafkaDir\bin\windows\kafka-topics.bat" --delete --topic test-topic --bootstrap-server localhost:9092
    }

    # Create a test topic
    Write-Host "Creating test topic 'test-topic'..." -ForegroundColor Yellow
    & "$kafkaDir\bin\windows\kafka-topics.bat" --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1

    # Produce messages
    Write-Host "Producing messages in the 'test-topic' topic..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start cmd.exe /k `"$kafkaDir\bin\windows\kafka-console-producer.bat --topic test-topic --bootstrap-server localhost:9092`""

    # Consume messages
    Write-Host "Consuming messages from the 'test-topic' topic..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start cmd.exe /k `"$kafkaDir\bin\windows\kafka-console-consumer.bat --topic test-topic --bootstrap-server localhost:9092 --from-beginning`""

    Write-Host "Basic Kafka example started. Check the opened terminals to interact with Kafka." -ForegroundColor Green
}

# Main function
function Main {
    Write-Host "=== Apache Kafka Installation for Windows ===" -ForegroundColor Cyan

    # Check disk space on C:
    Get-DiskSpace

    # Check if Java (JDK) is already installed
    $javaInstalled = $false
    $javaVersion = $null
    if (Get-Command java -ErrorAction SilentlyContinue) {
        # Capture the Java (JDK) version
        $javaOutput = & java -version 2>&1
        $javaVersionMatch = $javaOutput | Select-String -Pattern "(\d+\.\d+\.\d+)" | Select-Object -First 1
        if ($javaVersionMatch) {
            $javaVersion = $javaVersionMatch.Matches.Groups[1].Value
            Write-Host "Java (JDK) is already installed (version $javaVersion)." -ForegroundColor Green
            $javaInstalled = $true
        }
    }

    # Interactive menu for Java (JDK)
    if ($javaInstalled) {
        Write-Host "What do you want to do with Java (JDK)?" -ForegroundColor Yellow
        $javaOptions = @(
            "Update to the same version ($javaVersion)",
            "Reinstall the same version ($javaVersion)",
            "Install a new version",
            "Keep the current installation"
        )
        $javaChoice = Show-InteractiveMenu -Options $javaOptions -Title "Java (JDK) options"

        switch ($javaChoice) {
            "Update to the same version ($javaVersion)" {
                Write-Host "Updating Java (JDK) to version $javaVersion..." -ForegroundColor Yellow
                Install-Java -javaVersion $javaVersion
            }
            "Reinstall the same version ($javaVersion)" {
                Write-Host "Reinstalling Java (JDK) version $javaVersion..." -ForegroundColor Yellow
                Install-Java -javaVersion $javaVersion
            }
            "Install a new version" {
                Write-Host "Installing a new Java (JDK) version..." -ForegroundColor Yellow
                Install-Java
            }
            "Keep the current installation" {
                Write-Host "Keeping the current Java (JDK) installation." -ForegroundColor Green

                # Ask the user if they want to run the demo/example
                $runDemo = Read-Host "Do you want to run a Kafka demo/example? (Y/N)"

                if ($runDemo -eq "Y" -or $runDemo -eq "y") {
                    # Check if Kafka was installed correctly
                    if (Test-Path "C:\kafka") {
                        # Run the test
                        Test-ExampleKafka -kafkaDir "C:\kafka"
                    }
                    else {
                        Write-Host "Kafka was not installed correctly. Check the installation." -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "Kafka demo/example will not be run." -ForegroundColor Yellow
                }
            }
        }
    }
    else {
        Write-Host "Java (JDK) not found. Installing Java (JDK)..." -ForegroundColor Yellow
        Install-Java
    }

    # Test if Java (JDK) is installed and show the version
    java --version

    # Check if Kafka is already installed
    $kafkaInstalled = $false
    $kafkaVersion = $null
    if (Test-Path "C:\kafka\libs") {
        # Look for the Kafka JAR file (kafka-clients-*.jar)
        $kafkaJar = Get-ChildItem -Path "C:\kafka\libs" -Filter "kafka-clients-*.jar" | Select-Object -First 1

        if ($kafkaJar) {
            # Extract the version from the JAR file name
            $kafkaVersion = $kafkaJar.Name -replace "kafka-clients-", "" -replace "\.jar", ""
            Write-Host "Kafka is already installed (version $kafkaVersion)." -ForegroundColor Green
            $kafkaInstalled = $true
        }
    }

    # Interactive menu for Kafka
    if ($kafkaInstalled) {
        Write-Host "What do you want to do with Kafka?" -ForegroundColor Yellow
        $kafkaOptions = @(
            "Update to the same version ($kafkaVersion)",
            "Reinstall the same version ($kafkaVersion)",
            "Install a new version",
            "Keep the current installation"
        )
        $kafkaChoice = Show-InteractiveMenu -Options $kafkaOptions -Title "Kafka options"

        switch ($kafkaChoice) {
            "Update to the same version ($kafkaVersion)" {
                Write-Host "Updating Kafka to version $kafkaVersion..." -ForegroundColor Yellow
                Install-Kafka -kafkaVersion $kafkaVersion
            }
            "Reinstall the same version ($kafkaVersion)" {
                Write-Host "Reinstalling Kafka version $kafkaVersion..." -ForegroundColor Yellow
                Install-Kafka -kafkaVersion $kafkaVersion
            }
            "Install a new version" {
                Write-Host "Installing a new Kafka version..." -ForegroundColor Yellow
                Install-Kafka
            }
            "Keep the current installation" {
                Write-Host "Keeping the current Kafka installation." -ForegroundColor Green

                # Ask the user if they want to run the demo/example
                $runDemo = Read-Host "Do you want to run a Kafka demo/example? (Y/N)"

                if ($runDemo -eq "Y" -or $runDemo -eq "y") {
                    # Check if Kafka was installed correctly
                    if (Test-Path "C:\kafka") {
                        # Run the test
                        Test-ExampleKafka -kafkaDir "C:\kafka"
                    }
                    else {
                        Write-Host "Kafka was not installed correctly. Check the installation." -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "Kafka demo/example will not be run." -ForegroundColor Yellow
                }
            }
        }
    }
    else {
        Write-Host "Kafka not found. Installing Kafka..." -ForegroundColor Yellow
        Install-Kafka
    }

    Write-Host "Installation completed successfully!" -ForegroundColor Green
}

# Run the script
Main
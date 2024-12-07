# install.ps1

Write-Host "Starting Docker and MySQL installation..." -ForegroundColor Green

# Define a helper function to prompt the user
function PromptUser {
    param (
        [string]$PromptText,
        [string]$DefaultValue
    )
    $response = Read-Host "$PromptText (Default: $DefaultValue)"
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultValue
    }
    return $response
}

# Prompt user for each required parameter
$containerName = PromptUser -PromptText "Enter the container name" -DefaultValue "mysql"
$networkName = PromptUser -PromptText "Enter the network name" -DefaultValue "general"
$mysqlPort = PromptUser -PromptText "Enter the MySQL port" -DefaultValue "3306"
$mysqlDatabase = PromptUser -PromptText "Enter the MySQL database name" -DefaultValue "general"
$mysqlUser = PromptUser -PromptText "Enter the MySQL user" -DefaultValue "default"
$mysqlPassword = PromptUser -PromptText "Enter the MySQL password" -DefaultValue "secretpass"
$mysqlRootPassword = PromptUser -PromptText "Enter the MySQL root password" -DefaultValue "secretpass"
$allowHost = PromptUser -PromptText "Enter the allowed host (Default: 0.0.0.0)" -DefaultValue "0.0.0.0"

# Generate the .env file
Write-Host "Creating .env file for MySQL setup..." -ForegroundColor Green
$envContent = @"
# MySQL container settings
CONTAINER_NAME=$containerName
NETWORK_NAME=$networkName
MYSQL_PORT=$mysqlPort
ALLOW_HOST=$allowHost

# MySQL credentials
MYSQL_DATABASE=$mysqlDatabase
MYSQL_USER=$mysqlUser
MYSQL_PASSWORD=$mysqlPassword
MYSQL_ROOT_PASSWORD=$mysqlRootPassword
"@

# Save the .env file
$envFilePath = ".env"
$envContent | Set-Content -Path $envFilePath
Write-Host ".env file created successfully at $envFilePath." -ForegroundColor Green

# Check if Docker is installed
if (-Not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed. Please install Docker Desktop and restart this script." -ForegroundColor Red
    Start-Process "https://desktop.docker.com/win/stable/Docker Desktop Installer.exe"
    exit
}

# Check if Docker Compose is installed
if (-Not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Compose is not installed. Installing Docker Compose..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/docker/compose/releases/latest/download/docker-compose-Windows-x86_64.exe" -OutFile "$Env:ProgramFiles\Docker\docker-compose.exe"
    Write-Host "Docker Compose installed successfully." -ForegroundColor Green
}

# Create the network before building the container
Write-Host "Creating Docker network $networkName if it does not already exist..." -ForegroundColor Green
try {
    docker network create $networkName
    Write-Host "Network $networkName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Network $networkName already exists or could not be created. Skipping..." -ForegroundColor Yellow
}

# Use docker-compose.example.yaml to create docker-compose.yaml
Write-Host "Generating docker-compose.yaml file from docker-compose.example.yaml..." -ForegroundColor Green
if (Test-Path "docker-compose.example.yaml") {
    $exampleContent = Get-Content "docker-compose.example.yaml" | ForEach-Object {
        $_ -replace "\$\{CONTAINER_NAME\}", $containerName `
            -replace "\$\{NETWORK_NAME\}", $networkName `
            -replace "\$\{MYSQL_PORT\}", $mysqlPort `
            -replace "\$\{ALLOW_HOST\}", $allowHost `
            -replace "\$\{MYSQL_DATABASE\}", $mysqlDatabase `
            -replace "\$\{MYSQL_USER\}", $mysqlUser `
            -replace "\$\{MYSQL_PASSWORD\}", $mysqlPassword `
            -replace "\$\{MYSQL_ROOT_PASSWORD\}", $mysqlRootPassword
    }
    $composeFilePath = "docker-compose.yaml"
    $exampleContent | Set-Content -Path $composeFilePath
    Write-Host "docker-compose.yaml file created successfully at $composeFilePath." -ForegroundColor Green
} else {
    Write-Host "docker-compose.example.yaml file not found. Ensure the example file exists in the current directory." -ForegroundColor Red
    exit
}

# Start Docker Compose with build
Write-Host "Starting Docker Compose with --build for MySQL..." -ForegroundColor Green
try {
    docker-compose up -d --build
    $containerStatus = docker inspect -f '{{.State.Running}}' $containerName
    if ($containerStatus -eq "true") {
        Write-Host "MySQL setup is complete and running. Connecting to the container..." -ForegroundColor Green
        docker exec -it $containerName bash
    } else {
        Write-Host "Container is not running. Fetching logs..." -ForegroundColor Yellow
        docker logs $containerName
    }
} catch {
    Write-Host "Failed to start Docker Compose. Ensure Docker is running and try again." -ForegroundColor Red
}

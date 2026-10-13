param(
    [Parameter(Mandatory = $true)][Alias('Profile')][string]$AwsProfile,
    [string]$Region = 'eu-west-2',
    [string]$Prefix = 'meridian'
)
$ErrorActionPreference = 'Stop'
if ($Region -notmatch '^[a-z]{2}-[a-z]+-[0-9]+$' -or $Prefix -notmatch '^[a-z][a-z0-9-]{2,30}$') {
    throw 'Invalid AWS region or repository prefix.'
}
Push-Location (Split-Path $PSScriptRoot -Parent)
$taskRegistry = $null
try {
    $taskAccount = (& aws sts get-caller-identity --profile $AwsProfile --query Account --output text).Trim()
    if ($LASTEXITCODE -ne 0 -or $taskAccount -notmatch '^[0-9]{12}$') { throw 'AWS profile authentication failed.' }
    $taskRegistry = "$taskAccount.dkr.ecr.$Region.amazonaws.com"
    $taskServices = @('auth-service', 'catalog-service', 'orders-service', 'frontend')
    # Require provisioned, immutable repositories before building or pushing.
    foreach ($taskService in $taskServices) {
        $taskMutability = & aws ecr describe-repositories --profile $AwsProfile --region $Region --repository-names "$Prefix/$taskService" --query 'repositories[0].imageTagMutability' --output text
        if ($LASTEXITCODE -ne 0 -or $taskMutability -ne 'IMMUTABLE') { throw "Provision immutable ECR repository $Prefix/$taskService first." }
    }
    $taskCommit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $taskCommit -notmatch '^[a-f0-9]{40}$') { throw 'A Git commit is required.' }
    $taskEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $taskAttempt = Get-Random -Minimum 100000 -Maximum 999999
    $taskTag = "$taskCommit-$taskEpoch-$taskAttempt"
    # Write directly to stdin: Windows PowerShell pipelines append CRLF.
    $taskPassword = & aws ecr get-login-password --profile $AwsProfile --region $Region
    if ($LASTEXITCODE -ne 0) { throw 'ECR authentication failed.' }
    $taskLoginInfo = New-Object System.Diagnostics.ProcessStartInfo
    $taskLoginInfo.FileName = 'docker'
    $taskLoginInfo.Arguments = "login --username AWS --password-stdin $taskRegistry"
    $taskLoginInfo.UseShellExecute = $false
    $taskLoginInfo.RedirectStandardInput = $true
    $taskLogin = New-Object System.Diagnostics.Process
    $taskLogin.StartInfo = $taskLoginInfo
    try {
        [void]$taskLogin.Start()
        $taskLogin.StandardInput.Write(([string]$taskPassword).Trim())
        $taskLogin.StandardInput.Close()
        $taskLogin.WaitForExit()
        if ($taskLogin.ExitCode -ne 0) { throw 'Docker registry login failed.' }
    }
    finally {
        $taskPassword = $null
        $taskLogin.Dispose()
    }
    # Windows/ARM workstations still build the architecture of the EC2 target.
    foreach ($taskService in $taskServices) {
        & docker build --platform linux/amd64 --pull -t "${taskRegistry}/${Prefix}/${taskService}:${taskTag}" $taskService
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $taskService" }
    }
    foreach ($taskService in $taskServices) {
        & docker push "${taskRegistry}/${Prefix}/${taskService}:${taskTag}"
        if ($LASTEXITCODE -ne 0) { throw "Push failed: $taskService" }
    }
    Write-Host "Pushed all four images. IMAGE_TAG=$taskTag"
    Write-Host 'These images include the current working tree. Commit reviewed changes before publishing a release.'
}
finally {
    if ($taskRegistry) { & docker logout $taskRegistry | Out-Null }
    Pop-Location
}

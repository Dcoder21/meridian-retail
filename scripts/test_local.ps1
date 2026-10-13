# Test the storefront and rehearse database recovery on Docker Desktop.
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
$taskDatabase = "meridian_restore_test_$(Get-Random -Minimum 100000 -Maximum 999999)"
$taskArchive = "meridian-local-$(Get-Date -Format 'yyyyMMddTHHmmss').dump"
function Invoke-DatabaseCommand {
    param([string]$Command, [string]$Target)
    # Windows PowerShell 5 strips embedded quotes when calling native programs.
    if ($PSVersionTable.PSVersion.Major -le 5) { $Command = $Command.Replace('"','\"') }
    $taskResult = & docker compose exec -T postgres sh -ec $Command sh $Target
    if ($LASTEXITCODE -ne 0) { throw "Database operation failed for $Target" }
    return $taskResult
}
try {
    & python scripts/smoke_test.py http://localhost:8088
    if ($LASTEXITCODE -ne 0) { throw 'Storefront integration failed.' }
    New-Item -ItemType Directory -Force backups,evidence | Out-Null
    # Use docker cp for binary archives: Windows PowerShell redirection is text-based.
    Invoke-DatabaseCommand 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -f "/tmp/$1"; pg_restore --list "/tmp/$1" > /dev/null' $taskArchive
    & docker compose cp "postgres:/tmp/$taskArchive" "backups/$taskArchive"
    if ($LASTEXITCODE -ne 0) { throw 'Copying backup archive failed.' }
    $taskChecksum = (Get-FileHash "backups/$taskArchive" -Algorithm SHA256).Hash.ToLower()
    [System.IO.File]::WriteAllText((Join-Path $PWD "backups/$taskArchive.sha256"),"$taskChecksum  $taskArchive`n",[System.Text.UTF8Encoding]::new($false))
    Invoke-DatabaseCommand 'createdb -U "$POSTGRES_USER" "$1"' $taskDatabase
    $taskRestoreCommand = 'pg_restore -U "$POSTGRES_USER" -d "$1" --no-owner --no-acl --exit-on-error --single-transaction "/tmp/ARCHIVE"'.Replace('ARCHIVE',$taskArchive)
    Invoke-DatabaseCommand $taskRestoreCommand $taskDatabase
    $taskCountCommand = 'psql -U "$POSTGRES_USER" -d "$1" -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM products;"'
    $taskRowCommand = 'psql -U "$POSTGRES_USER" -d "$1" -At -v ON_ERROR_STOP=1 -c "SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;"'
    $taskBefore = [int](Invoke-DatabaseCommand $taskCountCommand $taskDatabase)
    if ($taskBefore -lt 1) { throw 'Seed data is required for recovery proof.' }
    $taskRow = Invoke-DatabaseCommand $taskRowCommand $taskDatabase
    Invoke-DatabaseCommand 'psql -U "$POSTGRES_USER" -d "$1" -v ON_ERROR_STOP=1 -c "DELETE FROM products WHERE id = (SELECT min(id) FROM products);"' $taskDatabase
    $taskDeleted = [int](Invoke-DatabaseCommand $taskCountCommand $taskDatabase)
    Invoke-DatabaseCommand 'dropdb -U "$POSTGRES_USER" --force "$1"; createdb -U "$POSTGRES_USER" "$1"' $taskDatabase
    Invoke-DatabaseCommand $taskRestoreCommand $taskDatabase
    $taskRestored = [int](Invoke-DatabaseCommand $taskCountCommand $taskDatabase)
    $taskRestoredRow = Invoke-DatabaseCommand $taskRowCommand $taskDatabase
    if ($taskDeleted -ne ($taskBefore - 1) -or $taskRestored -ne $taskBefore -or $taskRow -ne $taskRestoredRow) {
        throw 'Database restore did not recover the exact deleted row.'
    }
    $taskEvidence = "PASS: before=$taskBefore deleted=$taskDeleted restored=$taskRestored; exact product row recovered.`nArchive: $taskArchive`nSHA256: $taskChecksum`nUTC: $([DateTimeOffset]::UtcNow.ToString('o'))"
    $taskEvidence | Set-Content evidence/local-restore.txt
    Write-Host $taskEvidence
}
finally {
    Invoke-DatabaseCommand 'dropdb -U "$POSTGRES_USER" --if-exists --force "$1"' $taskDatabase
    & docker compose exec -T postgres rm -f "/tmp/$taskArchive"
    Pop-Location
}

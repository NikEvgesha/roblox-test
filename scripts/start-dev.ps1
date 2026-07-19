param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$rojo = (Get-Command rojo -ErrorAction Stop).Source

function Test-RojoBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter(Mandatory = $true)]
        [string]$OutputName
    )

    $outputPath = Join-Path $env:TEMP $OutputName
    & $rojo build $Project --output $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Rojo build failed for $Project"
    }
}

function Ensure-RojoServer {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [string]$Project
    )

    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)"
        if ($process.Name -ne "rojo.exe" -or $process.CommandLine -notlike "*$Project*") {
            throw "Port $Port is occupied by an unexpected process: $($process.CommandLine)"
        }

        return [pscustomobject]@{
            Role = [System.IO.Path]::GetFileNameWithoutExtension($Project)
            Port = $Port
            PID = $listener.OwningProcess
            Status = "Already running"
        }
    }

    $started = Start-Process `
        -FilePath $rojo `
        -ArgumentList @("serve", $Project) `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -PassThru

    $deadline = (Get-Date).AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 200
        $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    } while (-not $listener -and (Get-Date) -lt $deadline)

    if (-not $listener) {
        throw "Rojo did not start $Project on port $Port (PID $($started.Id))"
    }

    return [pscustomobject]@{
        Role = [System.IO.Path]::GetFileNameWithoutExtension($Project)
        Port = $Port
        PID = $listener.OwningProcess
        Status = "Started"
    }
}

Push-Location $repoRoot
try {
    Write-Host (& $rojo --version)

    if (-not $SkipBuild) {
        Test-RojoBuild -Project "lobby.project.json" -OutputName "heroic-survival-lobby-check.rbxlx"
        Test-RojoBuild -Project "combat.project.json" -OutputName "heroic-survival-combat-check.rbxlx"
    }

    $servers = @(
        Ensure-RojoServer -Port 34872 -Project "lobby.project.json"
        Ensure-RojoServer -Port 34873 -Project "combat.project.json"
    )

    $servers | Format-Table -AutoSize
}
finally {
    Pop-Location
}

# setup_ffmpeg.ps1
# Ce script télécharge et installe ffmpeg et ffprobe dans le dossier bin/ de l'API REST.

$binDir = Join-Path $PSScriptRoot "bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir | Out-Null
}

$zipPath = Join-Path $PSScriptRoot "ffmpeg.zip"
$extractPath = Join-Path $PSScriptRoot "ffmpeg_temp"

Write-Host "Téléchargement de FFmpeg (version essentials)..." -ForegroundColor Cyan
# URL de téléchargement stable pour Windows
$url = "https://github.com/GyanD/codexffmpeg/releases/download/6.0/ffmpeg-6.0-essentials_build.zip"

try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UserAgent "Mozilla/5.0"
    Write-Host "Extraction des fichiers..." -ForegroundColor Cyan
    
    if (Test-Path $extractPath) {
        Remove-Item -Recurse -Force $extractPath
    }
    
    Expand-Archive -Path $zipPath -DestinationPath $extractPath
    
    # Trouver ffmpeg.exe et ffprobe.exe
    $ffmpegSrc = Get-ChildItem -Path $extractPath -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
    $ffprobeSrc = Get-ChildItem -Path $extractPath -Filter "ffprobe.exe" -Recurse | Select-Object -First 1
    
    if ($ffmpegSrc -and $ffprobeSrc) {
        Copy-Item -Path $ffmpegSrc.FullName -Destination $binDir -Force
        Copy-Item -Path $ffprobeSrc.FullName -Destination $binDir -Force
        Write-Host "FFmpeg et FFprobe installés avec succès dans $binDir" -ForegroundColor Green
    } else {
        Write-Host "Erreur : Exécutables ffmpeg.exe/ffprobe.exe introuvables dans l'archive téléchargée." -ForegroundColor Red
    }
} catch {
    Write-Host "Une erreur est survenue lors de l'installation de FFmpeg : $_" -ForegroundColor Red
} finally {
    # Nettoyage
    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath
    }
    if (Test-Path $extractPath) {
        Remove-Item -Recurse -Force $extractPath
    }
}

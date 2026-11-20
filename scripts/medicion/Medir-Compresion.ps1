<#
===============================================================================
 Medir-Compresion.ps1
 Universidad Veracruzana - Facultad de Electronica y Comunicaciones
 Region Poza Rica-Tuxpan | Ingenieria en Tecnologias Computacionales
 Experiencia educativa: Investigacion Aplicada a Tecnologias Computacionales

 Protocolo: "Analisis experimental del tiempo de compresion en archivos
             digitales de imagen y video"

 Que hace:
   1. Levanta la Ficha del Entorno de Prueba (CPU, RAM, SO, version de 7-Zip).
   2. Comprime cada uno de los 4 archivos de la muestra 20 veces consecutivas
      (80 ejecuciones) con 7-Zip, formato ZIP / algoritmo DEFLATE, mismo nivel.
   3. Mide cada ejecucion con System.Diagnostics.Stopwatch (resolucion ~0.1 ms).
   4. Exporta 3 archivos CSV y un TXT con la ficha del entorno.

 USO:
   1. Coloca este .ps1 en la MISMA carpeta que la subcarpeta "muestra".
   2. Abre PowerShell en esa carpeta.
   3. Ejecuta:   powershell -ExecutionPolicy Bypass -File .\Medir-Compresion.ps1
===============================================================================
#>

[CmdletBinding()]
param(
    # Carpeta donde estan los 4 archivos de la muestra
    [string]$CarpetaMuestra = ".\muestra",

    # Carpeta donde se escriben los resultados
    [string]$CarpetaSalida  = ".\resultados",

    # Repeticiones por archivo (el protocolo pide 20)
    [int]$Repeticiones = 20,

    # Nivel de compresion de 7-Zip: 1=Rapida, 5=Normal, 9=Maxima/Ultra.
    # Se recomienda 9: separa mejor los formatos y es identico para los 4 archivos.
    [ValidateSet(1,3,5,7,9)]
    [int]$Nivel = 9,

    # Hilos de 7-Zip. 1 = monohilo (menos varianza, mas reproducible).
    # Cambia a 0 para dejar que 7-Zip use todos los nucleos (documentalo si lo haces).
    [int]$Hilos = 1,

    # Ejecucion de calentamiento previa, NO registrada. Evita que T1 salga inflado
    # por la cache fria del sistema operativo. Ponlo en $false si tu profesor
    # prefiere registrar el efecto de cache frio.
    [bool]$Calentamiento = $true
)

# "Continue" a proposito: 7z.exe escribe en stderr de forma rutinaria y con "Stop"
# algunas versiones de PowerShell abortan el script sin motivo real.
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# -----------------------------------------------------------------------------
# 0. Localizar 7-Zip
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host " MEDICION DE TIEMPO DE COMPRESION - n=4, 20 repeticiones" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host ""

$rutas7z = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
    "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe",
    ".\7z.exe",
    ".\7-Zip\7z.exe"
)
$7z = $rutas7z | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $7z) {
    $cmd = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($cmd) { $7z = $cmd.Source }
}
if (-not $7z) {
    Write-Host "ERROR: no se encontro 7z.exe." -ForegroundColor Red
    Write-Host "Instala 7-Zip desde https://www.7-zip.org/ o copia 7z.exe junto a este script."
    exit 1
}
$7z = (Resolve-Path $7z).Path
Write-Host "7-Zip encontrado en: $7z" -ForegroundColor Green

# Version exacta de 7-Zip (para la Ficha del Entorno)
$ver7z = "indeterminada"
try {
    $salida7z = & $7z i 2>$null | Select-Object -First 6
    $linea    = $salida7z | Where-Object { $_ -match '7-Zip' } | Select-Object -First 1
    if ($linea -match '7-Zip.*?(\d+\.\d+)') { $ver7z = $Matches[1] }
} catch { }
if ($ver7z -eq "indeterminada") {
    try { $ver7z = (Get-Item $7z).VersionInfo.ProductVersion } catch { }
}

# -----------------------------------------------------------------------------
# 1. Ficha del Entorno de Prueba
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Levantando Ficha del Entorno de Prueba..." -ForegroundColor Yellow

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$os  = Get-CimInstance Win32_OperatingSystem
$ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$ramGB    = [math]::Round($ramBytes / 1GB, 2)

# Tipo de unidad donde se ejecutan las pruebas (SSD / HDD)
$tipoDisco = "No determinado (verificar manualmente)"
try {
    $d    = (Get-Location).Path.Substring(0,1)
    $part = Get-Partition -DriveLetter $d -ErrorAction SilentlyContinue
    if ($part) {
        $md = (Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue |
               Get-PhysicalDisk -ErrorAction SilentlyContinue).MediaType
        if ($md) { $tipoDisco = $md }
    }
} catch { }

$ficha = [ordered]@{
    "Procesador"                   = "$($cpu.Name.Trim())"
    "Frecuencia base (MHz)"        = $cpu.MaxClockSpeed
    "Nucleos fisicos"              = $cpu.NumberOfCores
    "Procesadores logicos"         = $cpu.NumberOfLogicalProcessors
    "Memoria RAM total (GB)"       = $ramGB
    "Sistema Operativo"            = "$($os.Caption)"
    "Version exacta del SO"        = "$($os.Version) (build $($os.BuildNumber))"
    "Arquitectura"                 = $os.OSArchitecture
    "Tipo de unidad de trabajo"    = $tipoDisco
    "Software de compresion"       = "7-Zip"
    "Version del software"         = $ver7z
    "Formato contenedor"           = "ZIP"
    "Algoritmo de compresion"      = "DEFLATE"
    "Nivel de compresion (-mx)"    = $Nivel
    "Hilos de compresion (-mmt)"   = $(if ($Hilos -eq 0) { "automatico (todos los nucleos)" } else { $Hilos })
    "Repeticiones por archivo"     = $Repeticiones
    "Ejecucion de calentamiento"   = $(if ($Calentamiento) { "Si (no registrada)" } else { "No" })
    "Metodo de medicion"           = "System.Diagnostics.Stopwatch (wall-clock, ms)"
    "Fecha y hora de la prueba"    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    "Equipo"                       = $env:COMPUTERNAME
}

$ficha.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0,-30} : {1}" -f $_.Key, $_.Value)
}

# -----------------------------------------------------------------------------
# 2. Verificar la muestra (n = 4)
# -----------------------------------------------------------------------------
if (-not (Test-Path $CarpetaMuestra)) {
    Write-Host "`nERROR: no existe la carpeta '$CarpetaMuestra'." -ForegroundColor Red
    exit 1
}

$muestra = @(
    [pscustomobject]@{ No=1; Tipo="Imagen"; Formato=".bmp"; Patron="*.bmp" }
    [pscustomobject]@{ No=2; Tipo="Imagen"; Formato=".jpg"; Patron="*.jpg" }
    [pscustomobject]@{ No=3; Tipo="Video";  Formato=".avi"; Patron="*.avi" }
    [pscustomobject]@{ No=4; Tipo="Video";  Formato=".mp4"; Patron="*.mp4" }
)

foreach ($m in $muestra) {
    $f = Get-ChildItem -Path $CarpetaMuestra -Filter $m.Patron -File | Select-Object -First 1
    if (-not $f) {
        Write-Host "`nERROR: falta un archivo $($m.Formato) en '$CarpetaMuestra'." -ForegroundColor Red
        exit 1
    }
    $m | Add-Member -NotePropertyName Ruta    -NotePropertyValue $f.FullName
    $m | Add-Member -NotePropertyName Nombre  -NotePropertyValue $f.Name
    $m | Add-Member -NotePropertyName Bytes   -NotePropertyValue $f.Length
}

Write-Host "`nMuestra detectada (n = $($muestra.Count)):" -ForegroundColor Yellow
$muestra | ForEach-Object {
    Write-Host ("  [{0}] {1,-7} {2,-6} {3,-34} {4,10:N0} bytes ({5:N2} MiB)" -f `
        $_.No, $_.Tipo, $_.Formato, $_.Nombre, $_.Bytes, ($_.Bytes/1MB))
}

# -----------------------------------------------------------------------------
# 3. Control de carga del sistema
# -----------------------------------------------------------------------------
Write-Host "`nProcesos con mayor uso de memoria en este momento:" -ForegroundColor Yellow
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 |
    ForEach-Object { Write-Host ("  {0,-28} {1,8:N0} MB" -f $_.ProcessName, ($_.WorkingSet64/1MB)) }

Write-Host "`n  >> Cierra navegadores, reproductores, antivirus en analisis y actualizaciones." -ForegroundColor Magenta
Write-Host "  >> Conecta el equipo a corriente y pon el plan de energia en Alto rendimiento." -ForegroundColor Magenta
Read-Host "`nCuando el equipo este listo, presiona ENTER para iniciar las $($muestra.Count * $Repeticiones) ejecuciones"

# -----------------------------------------------------------------------------
# 4. Preparar salida
# -----------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $CarpetaSalida | Out-Null
$tmp = Join-Path $CarpetaSalida "_tmp_zips"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$registros = New-Object System.Collections.Generic.List[object]

# Argumentos fijos de 7-Zip, IDENTICOS para los 4 archivos (variable controlada):
#   -tzip         contenedor ZIP
#   -mm=Deflate   algoritmo DEFLATE explicito
#   -mx=N         nivel de compresion
#   -mmt=N        numero de hilos
$mmt     = if ($Hilos -eq 0) { "-mmt=on" } else { "-mmt=$Hilos" }
$argsFijos = @("a", "-tzip", "-mm=Deflate", "-mx=$Nivel", $mmt, "-bso0", "-bse0", "-bsp0")

# Prueba de compatibilidad: las banderas -bso0/-bse0/-bsp0 existen desde 7-Zip 15.
# Si la version instalada es anterior, se usan los argumentos sin ellas.
$pruebaZip    = Join-Path $tmp "_compat.zip"
$pruebaOrigen = $muestra[0].Ruta
& $7z @argsFijos $pruebaZip $pruebaOrigen > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  (version de 7-Zip antigua: se omiten las banderas -bs*)" -ForegroundColor DarkGray
    $argsFijos = @("a", "-tzip", "-mm=Deflate", "-mx=$Nivel", $mmt)
}
Remove-Item $pruebaZip -Force -ErrorAction SilentlyContinue
$comandoDoc = "7z.exe " + ($argsFijos -join " ") + " <destino.zip> <archivo>"
$ficha["Linea de comando utilizada"] = $comandoDoc

# -----------------------------------------------------------------------------
# 5. Ejecucion de las pruebas
# -----------------------------------------------------------------------------
$inicioGlobal = Get-Date

foreach ($m in $muestra) {

    Write-Host "`n-------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host (" Archivo {0}/4 : {1}  ({2}, {3:N2} MiB)" -f $m.No, $m.Nombre, $m.Tipo, ($m.Bytes/1MB)) -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor Cyan

    $destino = Join-Path $tmp ("salida_" + $m.No + ".zip")
    $origen  = $m.Ruta

    # --- Calentamiento (no registrado) ---
    if ($Calentamiento) {
        if (Test-Path $destino) { Remove-Item $destino -Force }
        & $7z @argsFijos $destino $origen > $null 2>&1
        if (Test-Path $destino) { Remove-Item $destino -Force }
        Write-Host "  (calentamiento realizado, no registrado)" -ForegroundColor DarkGray
    }

    for ($i = 1; $i -le $Repeticiones; $i++) {

        if (Test-Path $destino) { Remove-Item $destino -Force }

        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $7z @argsFijos $destino $origen > $null 2>&1
        $sw.Stop()
        $codigo = $LASTEXITCODE

        $ms = $sw.Elapsed.TotalMilliseconds
        $bytesZip = if (Test-Path $destino) { (Get-Item $destino).Length } else { 0 }

        $registros.Add([pscustomobject]@{
            No             = $m.No
            TipoArchivo    = $m.Tipo
            NombreArchivo  = $m.Nombre
            Formato        = $m.Formato
            Repeticion     = $i
            Tiempo_s       = [math]::Round($ms / 1000, 4)
            Tiempo_ms      = [math]::Round($ms, 2)
            BytesOriginal  = $m.Bytes
            BytesComprimido= $bytesZip
            RatioPorc      = if ($m.Bytes -gt 0) { [math]::Round(100 * $bytesZip / $m.Bytes, 2) } else { 0 }
            CodigoSalida   = $codigo
        })

        Write-Host ("  T{0,-2} = {1,8:N4} s" -f $i, ($ms/1000)) -NoNewline
        if ($codigo -ne 0) { Write-Host "   [ADVERTENCIA: codigo de salida $codigo]" -ForegroundColor Red }
        else { Write-Host "" }
    }

    if (Test-Path $destino) { Remove-Item $destino -Force }
}

$duracionTotal = (Get-Date) - $inicioGlobal
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# -----------------------------------------------------------------------------
# 6. Exportar resultados
# -----------------------------------------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

# 6.1 Formato largo (una fila por ejecucion) - para analisis estadistico
$rutaLargo = Join-Path $CarpetaSalida "medidas_largo_$stamp.csv"
$registros | Export-Csv -Path $rutaLargo -NoTypeInformation -Encoding UTF8

# 6.2 Formato ancho (4 filas x T1..T20) - se pega directo en la tabla del protocolo
$filasAncho = foreach ($m in $muestra) {
    $r = $registros | Where-Object { $_.No -eq $m.No } | Sort-Object Repeticion
    $fila = [ordered]@{
        "No."            = $m.No
        "Tipo de archivo"= $m.Tipo
        "Nombre del archivo" = $m.Nombre
        "Formato"        = $m.Formato
    }
    for ($i = 1; $i -le $Repeticiones; $i++) {
        $fila["T$i (s)"] = ($r | Where-Object { $_.Repeticion -eq $i }).Tiempo_s
    }
    $tiempos = $r.Tiempo_s
    $media = ($tiempos | Measure-Object -Average).Average
    $sd = if ($tiempos.Count -gt 1) {
        [math]::Sqrt( (($tiempos | ForEach-Object { [math]::Pow($_ - $media, 2) }) | Measure-Object -Sum).Sum / ($tiempos.Count - 1) )
    } else { 0 }
    $fila["Tiempo Promedio (s)"]  = [math]::Round($media, 4)
    $fila["Desviacion Estandar"]  = [math]::Round($sd, 4)
    $fila["Tamano original (MiB)"]= [math]::Round($m.Bytes/1MB, 2)
    $fila["Tamano ZIP (MiB)"]     = [math]::Round(($r | Select-Object -First 1).BytesComprimido/1MB, 2)
    $fila["Ratio (%)"]            = ($r | Select-Object -First 1).RatioPorc
    $fila["Observaciones"]        = ""
    [pscustomobject]$fila
}
$rutaAncho = Join-Path $CarpetaSalida "tabla_captura_$stamp.csv"
$filasAncho | Export-Csv -Path $rutaAncho -NoTypeInformation -Encoding UTF8

# 6.3 Tabla 4: resumen por tipo de archivo
$resumen = foreach ($tipo in @("Imagen","Video")) {
    $t = ($registros | Where-Object { $_.TipoArchivo -eq $tipo }).Tiempo_s
    $media = ($t | Measure-Object -Average).Average
    $sd = [math]::Sqrt( (($t | ForEach-Object { [math]::Pow($_ - $media,2) }) | Measure-Object -Sum).Sum / ($t.Count - 1) )
    [pscustomobject]@{
        "Tipo de archivo"        = $tipo
        "n (ejecuciones)"        = $t.Count
        "Promedio Tiempo (s)"    = [math]::Round($media, 4)
        "Desv. Estandar Tiempo"  = [math]::Round($sd, 4)
        "Minimo (s)"             = [math]::Round(($t | Measure-Object -Minimum).Minimum, 4)
        "Maximo (s)"             = [math]::Round(($t | Measure-Object -Maximum).Maximum, 4)
    }
}
$rutaResumen = Join-Path $CarpetaSalida "tabla4_resumen_$stamp.csv"
$resumen | Export-Csv -Path $rutaResumen -NoTypeInformation -Encoding UTF8

# 6.4 Ficha del entorno
$rutaFicha = Join-Path $CarpetaSalida "ficha_entorno_$stamp.txt"
$lineas = @("FICHA DEL ENTORNO DE PRUEBA", ("=" * 60), "")
$ficha.GetEnumerator() | ForEach-Object { $lineas += ("{0,-30} : {1}" -f $_.Key, $_.Value) }
$lineas += ""
$lineas += "ARCHIVOS DE LA MUESTRA"
$lineas += ("-" * 60)
$muestra | ForEach-Object {
    $lineas += ("[{0}] {1,-7} {2,-6} {3,-34} {4,12:N0} bytes" -f $_.No, $_.Tipo, $_.Formato, $_.Nombre, $_.Bytes)
}
$lineas += ""
$lineas += ("Duracion total de la sesion de pruebas: {0:N1} segundos" -f $duracionTotal.TotalSeconds)
$lineas | Set-Content -Path $rutaFicha -Encoding UTF8

# -----------------------------------------------------------------------------
# 7. Resumen en pantalla
# -----------------------------------------------------------------------------
Write-Host "`n`n=============================================================" -ForegroundColor Green
Write-Host " RESULTADOS" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green

Write-Host "`nPor archivo:" -ForegroundColor Yellow
$filasAncho | Select-Object "No.","Formato","Tiempo Promedio (s)","Desviacion Estandar","Ratio (%)" | Format-Table -AutoSize

Write-Host "Tabla 4 - Resumen por tipo de archivo:" -ForegroundColor Yellow
$resumen | Format-Table -AutoSize

Write-Host "Archivos generados en '$CarpetaSalida':" -ForegroundColor Green
Write-Host "  - $(Split-Path $rutaAncho   -Leaf)   <- pegar en la hoja de captura de Excel"
Write-Host "  - $(Split-Path $rutaLargo   -Leaf)   <- datos crudos para el analisis estadistico"
Write-Host "  - $(Split-Path $rutaResumen -Leaf)   <- Tabla 4"
Write-Host "  - $(Split-Path $rutaFicha   -Leaf)   <- Ficha del Entorno de Prueba"
Write-Host ("`nDuracion total: {0:N1} segundos`n" -f $duracionTotal.TotalSeconds) -ForegroundColor Green

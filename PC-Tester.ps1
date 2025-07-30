# =================================================================================
# ||                                                                             ||
# ||                 SCRIPT DE ANÁLISIS RÁPIDO DE SISTEMA WINDOWS                ||
# ||                                                                             ||
# =================================================================================

# --- FASE 0: CONFIGURACIÓN INICIAL ---
Write-Host "=================================================" -ForegroundColor Green
Write-Host "      INICIANDO PRUEBA DEL SISTEMA" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[+] Permisos de administrador confirmados."

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportFolder = "$env:USERPROFILE\Desktop\Analisis_Sistema_$Timestamp"
New-Item -ItemType Directory -Path $ReportFolder | Out-Null
Set-Location -Path $ReportFolder
Write-Host "[+] Carpeta de resultados creada en: $ReportFolder"
Write-Host ""

# --- FASE 1: RECOPILACIÓN DE DATOS ---
$SystemInfo = [PSCustomObject]@{
    Manufacturer      = "No disponible"; Model             = "No disponible"
    OS                = "No disponible"; OSArch            = "N/A"
    CPU               = "No disponible"; Cores             = "N/A"; Threads           = "N/A"
    RAM_GB            = "N/A"
    Resolution        = "No disponible"
    GPU               = "No disponible"; GPUMemory_GB      = "N/A"
    Disks             = @()
    WifiAdapter       = "No detectado"; BluetoothAdapter  = "No detectado"
    AudioDevices      = @(); CameraDevices     = @()
    BatteryDesign     = "N/A"; BatteryFullCharge = "N/A"; BatteryHealth     = "N/A"; BatteryCycles = "N/A"
}
Write-Host "[1/8] Obteniendo detalles del sistema y RAM..."
try { $compInfo = Get-ComputerInfo; $SystemInfo.Manufacturer = $compInfo.CsManufacturer; $SystemInfo.Model = $compInfo.CsModel; $SystemInfo.OS = $compInfo.OsName; $SystemInfo.OSArch = $compInfo.OsArchitecture; $SystemInfo.RAM_GB = [math]::Round($compInfo.OsTotalVisibleMemorySize / 1MB) } catch { Write-Warning "Get-ComputerInfo falló." }
Write-Host "[2/8] Obteniendo detalles de la CPU..."
try { $cpu = Get-CimInstance Win32_Processor; $SystemInfo.CPU = $cpu.Name; $SystemInfo.Cores = $cpu.NumberOfCores; $SystemInfo.Threads = $cpu.NumberOfLogicalProcessors } catch { Write-Warning "No se pudo obtener la info de la CPU." }
Write-Host "[3/8] Analizando unidades de disco..."
try { $SystemInfo.Disks = Get-PhysicalDisk | Select-Object Model, @{N="Size";E={[math]::Round($_.Size / 1GB)}}, MediaType, HealthStatus } catch { Write-Warning "No se pudo obtener la info de los discos." }
Write-Host "[4/8] Obteniendo detalles de la GPU y Pantalla..."
try { $video = Get-CimInstance Win32_VideoController | Select-Object -First 1; $SystemInfo.GPU = $video.Name; $SystemInfo.GPUMemory_GB = [math]::Round($video.AdapterRAM / 1GB); $SystemInfo.Resolution = "$($video.CurrentHorizontalResolution)x$($video.CurrentVerticalResolution)" } catch { Write-Warning "No se pudo obtener la info de la GPU." }
Write-Host "[5/8] Verificando conectividad Wi-Fi y Bluetooth..."
try { $SystemInfo.WifiAdapter = (Get-NetAdapter | Where-Object {$_.Name -like "*Wi-Fi*"}).Status } catch {}
try { $SystemInfo.BluetoothAdapter = (Get-NetAdapter | Where-Object {$_.Name -like "*Bluetooth*"}).Status } catch {}
Write-Host "[6/8] Listando dispositivos de Audio y Cámara..."
try { $SystemInfo.AudioDevices = (Get-CimInstance Win32_SoundDevice).Name } catch {}
try { $SystemInfo.CameraDevices = (Get-PnpDevice -Class 'Camera','Image' -Status 'OK').FriendlyName } catch {}
Write-Host "[7/8] Generando informe de batería..."
$batteryPath = "$ReportFolder\battery_report.html"
Start-Process "powercfg" -ArgumentList "/batteryreport /output $batteryPath /duration 0" -Wait -NoNewWindow -ErrorAction SilentlyContinue
Write-Host "[8/8] Prueba de Sonido del Sistema (Beep)..."
try { [System.Media.SystemSounds]::Beep.Play() } catch {}
Start-Sleep -Seconds 1
Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "      PROCESANDO DATOS Y CREANDO INFORME" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""

# --- FASE 2: PROCESAMIENTO DE INFORMES ---
if (Test-Path $batteryPath) {
    try {
        $ie = New-Object -ComObject InternetExplorer.Application; $ie.Visible = $false
        $ie.Navigate("file://$batteryPath"); while ($ie.Busy) { Start-Sleep -Milliseconds 100 }
        $doc = $ie.Document
        $designLabel = $doc.getElementsByTagName('td') | Where-Object { $_.innerText -eq 'Design capacity' }; $SystemInfo.BatteryDesign = $designLabel.nextSibling.innerText
        $fullChargeLabel = $doc.getElementsByTagName('td') | Where-Object { $_.innerText -eq 'Full charge capacity' }; $SystemInfo.BatteryFullCharge = $fullChargeLabel.nextSibling.innerText
        $cycleCountLabel = $doc.getElementsByTagName('td') | Where-Object { $_.innerText -eq 'Cycle count' }; $SystemInfo.BatteryCycles = $cycleCountLabel.nextSibling.innerText
        $ie.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ie) | Out-Null
        $design = [double]($SystemInfo.BatteryDesign -replace '[^\d.]',''); $full = [double]($SystemInfo.BatteryFullCharge -replace '[^\d.]','')
        if ($design -gt 0) { $SystemInfo.BatteryHealth = [math]::Round(($full / $design) * 100) }
    } catch { Write-Warning "Ocurrió un error al procesar el informe de la batería." }
}

# --- FASE 3: GENERACIÓN DEL INFORME HTML ---

# Preparar contenido dinámico para bucles
$diskHtml = ""
foreach($disk in $SystemInfo.Disks){
    $diskHtml += @"
    <div class="storage-item">
        <div class="info-row"><span class="info-label">Modelo</span><span class="info-value">$($disk.Model)</span></div>
        <div class="info-row"><span class="info-label">Tamaño</span><span class="info-value">$($disk.Size) GB</span></div>
        <div class="info-row"><span class="info-label">Tipo</span><span class="info-value">$($disk.MediaType)</span></div>
        <div class="info-row"><span class="info-label">Estado</span><span class="info-value">$($disk.HealthStatus)</span></div>
    </div>
"@
}
if(-not $diskHtml){ $diskHtml = "<p class='na'>Información de discos no disponible.</p>" }

$audioHtml = ""; foreach($dev in $SystemInfo.AudioDevices){ $audioHtml += "<li>$dev</li>" }
if(-not $audioHtml){ $audioHtml = "<li>No detectado</li>" }

$cameraHtml = ""; foreach($dev in $SystemInfo.CameraDevices){ $cameraHtml += "<li>$dev</li>" }
if(-not $cameraHtml){ $cameraHtml = "<li>No detectada</li>" }


# Plantilla HTML completa
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema de Análisis - Panel de Control</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root {
            --primary-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --accent-gradient: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            --glass-bg: rgba(255, 255, 255, 0.05);
            --glass-border: rgba(255, 255, 255, 0.1);
            --text-primary: #ffffff;
            --text-secondary: rgba(255, 255, 255, 0.7);
            --shadow-glass: 0 8px 32px rgba(0, 0, 0, 0.3);
            --shadow-hover: 0 12px 40px rgba(0, 0, 0, 0.4);
            --tested-key-bg: linear-gradient(135deg, #2a9d8f, #264653);
            --toggle-btn-bg: linear-gradient(135deg, #f39c12, #e67e22);
        }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, #0c0c0c 0%, #1a1a2e 25%, #16213e  50%, #0f3460 100%);
            min-height: 100vh; color: var(--text-primary); overflow-x: hidden; position: relative;
        }
        body::before {
            content: ''; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            background: 
                radial-gradient(circle at 20% 20%, rgba(102, 126, 234, 0.1) 0%, transparent 50%),
                radial-gradient(circle at 80% 80%, rgba(118, 75, 162, 0.1) 0%, transparent 50%),
                radial-gradient(circle at 40% 60%, rgba(75, 172, 254, 0.05) 0%, transparent 50%);
            pointer-events: none; z-index: -1;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; position: relative; z-index: 1; }
        .header { text-align: center; margin-bottom: 3rem; animation: fadeInDown 1s ease-out; }
        .header h1 { font-size: 3rem; font-weight: 700; background: var(--primary-gradient); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; margin-bottom: 0.5rem; letter-spacing: -0.02em; }
        .header .subtitle { color: var(--text-secondary); font-size: 1.1rem; font-weight: 400; }
        .glass-card { background: var(--glass-bg); backdrop-filter: blur(20px); border: 1px solid var(--glass-border); border-radius: 20px; padding: 2rem; margin-bottom: 2rem; box-shadow: var(--shadow-glass); transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); position: relative; overflow: hidden; }
        .glass-card::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 1px; background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent); }
        .glass-card:hover { transform: translateY(-5px); box-shadow: var(--shadow-hover); border-color: rgba(255, 255, 255, 0.2); }
        .section-title { font-size: 1.5rem; font-weight: 600; margin-bottom: 1.5rem; color: var(--text-primary); display: flex; align-items: center; gap: 0.75rem; }
        .section-title::before { content: ''; width: 4px; height: 1.2em; background: var(--accent-gradient); border-radius: 2px; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1.5rem; }
        .info-row { display: flex; justify-content: space-between; align-items: center; padding: 0.75rem 0; border-bottom: 1px solid rgba(255, 255, 255, 0.05); transition: all 0.2s ease; }
        .info-row:hover { background: rgba(255, 255, 255, 0.02); border-radius: 8px; padding-left: 0.5rem; padding-right: 0.5rem; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 500; color: var(--text-secondary); font-size: 0.95rem; }
        .info-value { font-weight: 600; color: var(--text-primary); text-align: right; max-width: 60%; }
        .storage-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; margin-top: 1rem; }
        .storage-item { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 1.5rem; transition: all 0.3s ease; }
        .storage-item:hover { background: rgba(255, 255, 255, 0.05); border-color: rgba(255, 255, 255, 0.15); transform: translateY(-2px); }
        .battery-health { display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 600; color: var(--text-primary); }
        .health-indicator { width: 8px; height: 8px; border-radius: 50%; background: #10b981; box-shadow: 0 0 10px rgba(16, 185, 129, 0.5); animation: pulse 2s infinite; }
        .testing-lab { background: rgba(255, 255, 255, 0.02); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 20px; padding: 2rem; margin-top: 2rem; }
        .test-section { margin-bottom: 2rem; }
        .test-section:last-child { margin-bottom: 0; }
        .test-title { font-size: 1.1rem; font-weight: 600; color: var(--text-primary); margin-bottom: 1rem; display: flex; align-items: center; gap: 0.5rem; }
        .test-buttons { display: flex; flex-wrap: wrap; gap: 0.75rem; }
        .btn { background: var(--glass-bg); backdrop-filter: blur(10px); border: 1px solid var(--glass-border); border-radius: 12px; padding: 0.75rem 1.5rem; font-family: inherit; font-weight: 500; color: var(--text-primary); cursor: pointer; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); position: relative; overflow: hidden; }
        .btn::before { content: ''; position: absolute; top: 0; left: -100%; width: 100%; height: 100%; background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent); transition: left 0.5s ease; }
        .btn:hover::before { left: 100%; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3); border-color: rgba(255, 255, 255, 0.2); }
        .btn:active { transform: translateY(0); }
        .btn-red { background: linear-gradient(135deg, #ff6b6b, #ee5a52); }
        .btn-green { background: linear-gradient(135deg, #51cf66, #40c057); }
        .btn-blue { background: linear-gradient(135deg, #4dabf7, #339af0); }
        .btn-black { background: linear-gradient(135deg, #495057, #343a40); }
        .btn-white { background: linear-gradient(135deg, #f8f9fa, #e9ecef); color: #333; }
        .btn-toggle { background: var(--toggle-btn-bg); }
        .pixel-tester { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: 9999; display: none; cursor: pointer; animation: fadeIn 0.3s ease; }
        .keyboard-container { background: rgba(0, 0, 0, 0.3); backdrop-filter: blur(15px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 16px; padding: 1.5rem; margin-top: 1rem; }
        .keyboard-info { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; padding-bottom: 1rem; border-bottom: 1px solid rgba(255, 255, 255, 0.1); flex-wrap: wrap; gap: 10px; }
        .key-counter-text { font-weight: 600; color: var(--text-primary); }
        .keyboard-controls { display: flex; gap: 10px; }
        .keyboard-row { display: flex; justify-content: center; gap: 0.25rem; margin-bottom: 0.25rem; }
        .keyboard-container.inactive .keyboard-row { opacity: 0.6; transition: opacity 0.3s ease; }
        .key { background: rgba(255, 255, 255, 0.05); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 8px; padding: 0.75rem; min-width: 45px; text-align: center; font-weight: 500; color: var(--text-secondary); cursor: default; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); user-select: none; position: relative; font-size: 0.85rem; }
        .key:hover { background: rgba(255, 255, 255, 0.08); border-color: rgba(255, 255, 255, 0.2); }
        .key.pressed { background: var(--accent-gradient); color: white; transform: translateY(1px) scale(0.98); box-shadow: 0 2px 8px rgba(75, 172, 254, 0.3); }
        .key.tested { background: var(--tested-key-bg); color: white; }
        .key.long { flex-grow: 1; } .key.mid { flex-grow: 0.5; } .key.space { flex-grow: 8; }
        .device-list { list-style: none; margin-top: 1rem; padding: 0;}
        .device-list li { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.05); border-radius: 8px; padding: 0.75rem 1rem; margin-bottom: 0.5rem; transition: all 0.2s ease; position: relative; padding-left: 2.5rem; }
        .device-list li::before { content: '●'; position: absolute; left: 1rem; color: #10b981; font-size: 1.2em; }
        .device-list li:hover { background: rgba(255, 255, 255, 0.05); border-color: rgba(255, 255, 255, 0.1); transform: translateX(5px); }
        @keyframes fadeInDown { from { opacity: 0; transform: translateY(-30px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
        @keyframes pulse { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.7; transform: scale(1.1); } }
        .animate-card { animation: fadeInUp 0.6s ease-out forwards; opacity: 0; }
        @keyframes fadeInUp { from { opacity: 0; transform: translateY(30px); } to { opacity: 1; transform: translateY(0); } }
        .card-1 { animation-delay: 0.1s; } .card-2 { animation-delay: 0.2s; } .card-3 { animation-delay: 0.3s; } .card-4 { animation-delay: 0.4s; } .card-5 { animation-delay: 0.5s; }
        @media (max-width: 768px) { .container { padding: 1rem; } .header h1 { font-size: 2rem; } .glass-card { padding: 1.5rem; } .info-grid { grid-template-columns: 1fr; } .test-buttons { justify-content: center; } .keyboard-row { gap: 0.15rem; } .key { padding: 0.5rem; min-width: 35px; font-size: 0.75rem; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Sistema de Análisis</h1>
            <p class="subtitle">Panel de Control • Generado el: <!--FECHA--></p>
        </div>
        <div class="glass-card animate-card card-1">
            <h2 class="section-title">Especificaciones Técnicas</h2>
            <div class="info-grid">
                <div>
                    <div class="info-row"><span class="info-label">Fabricante</span><span class="info-value"><!--FABRICANTE--></span></div>
                    <div class="info-row"><span class="info-label">Modelo</span><span class="info-value"><!--MODELO--></span></div>
                    <div class="info-row"><span class="info-label">Sistema Operativo</span><span class="info-value"><!--SO--></span></div>
                    <div class="info-row"><span class="info-label">Procesador</span><span class="info-value"><!--CPU--></span></div>
                </div>
                <div>
                    <div class="info-row"><span class="info-label">Núcleos / Hilos</span><span class="info-value"><!--NUCLEOS--></span></div>
                    <div class="info-row"><span class="info-label">RAM Instalada</span><span class="info-value"><!--RAM--></span></div>
                    <div class="info-row"><span class="info-label">Resolución de Pantalla</span><span class="info-value"><!--RESOLUCION--></span></div>
                    <div class="info-row"><span class="info-label">Tarjeta Gráfica</span><span class="info-value"><!--GPU--></span></div>
                    <div class="info-row"><span class="info-label">Memoria de Vídeo</span><span class="info-value"><!--VRAM--></span></div>
                </div>
            </div>
        </div>
        <div class="glass-card animate-card card-2">
            <h2 class="section-title">Almacenamiento</h2>
            <div class="storage-grid"><!--DISCOS--></div>
        </div>
        <div class="glass-card animate-card card-3">
            <h2 class="section-title">Estado de la Batería</h2>
            <div class="info-grid">
                <div>
                    <div class="info-row"><span class="info-label">Salud General</span><span class="info-value battery-health"><span class="health-indicator"></span><!--SALUD_BATERIA-->%</span></div>
                    <div class="info-row"><span class="info-label">Ciclos de Carga</span><span class="info-value"><!--CICLOS_BATERIA--></span></div>
                </div>
                <div>
                    <div class="info-row"><span class="info-label">Capacidad Original</span><span class="info-value"><!--CAPACIDAD_ORIGINAL_BATERIA--></span></div>
                    <div class="info-row"><span class="info-label">Capacidad Actual</span><span class="info-value"><!--CAPACIDAD_ACTUAL_BATERIA--></span></div>
                </div>
            </div>
        </div>
        <div class="glass-card animate-card card-4">
            <h2 class="section-title">Conectividad y Dispositivos</h2>
            <div class="info-grid">
                <div>
                    <div class="info-row"><span class="info-label">Adaptador Wi-Fi</span><span class="info-value"><!--WIFI--></span></div>
                    <div class="info-row"><span class="info-label">Adaptador Bluetooth</span><span class="info-value"><!--BLUETOOTH--></span></div>
                </div>
                <div>
                    <h3 style="color: var(--text-primary); margin-bottom: 1rem; font-size: 1.1rem;">Dispositivos de Audio</h3>
                    <ul class="device-list"><!--AUDIO--></ul>
                    <h3 style="color: var(--text-primary); margin: 1.5rem 0 1rem; font-size: 1.1rem;">Cámaras Detectadas</h3>
                    <ul class="device-list"><!--CAMARA--></ul>
                </div>
            </div>
        </div>
        <div class="glass-card animate-card card-5">
            <h2 class="section-title">Laboratorio de Pruebas Interactivo</h2>
            <div class="testing-lab">
                <div class="test-section">
                    <div class="test-title">🔊 Prueba de Audio</div>
                    <div class="test-buttons"><button class="btn" onclick="playSound()">Reproducir Sonido de Prueba</button></div>
                </div>
                <div class="test-section">
                    <div class="test-title">🖥️ Prueba de Píxeles</div>
                    <div class="test-buttons">
                        <button class="btn btn-red" onclick="startPixelTest('red')">Rojo</button>
                        <button class="btn btn-green" onclick="startPixelTest('green')">Verde</button>
                        <button class="btn btn-blue" onclick="startPixelTest('blue')">Azul</button>
                        <button class="btn btn-black" onclick="startPixelTest('black')">Negro</button>
                        <button class="btn btn-white" onclick="startPixelTest('white')">Blanco</button>
                    </div>
                    <div id="pixel-tester" class="pixel-tester" onclick="endPixelTest()"></div>
                </div>
                <div class="test-section">
                    <div class="test-title">⌨️ Prueba de Teclado</div>
                    <div class="keyboard-container" id="keyboard-container">
                        <div class="keyboard-info">
                            <span class="key-counter-text">Teclas probadas: <span id="key-count-value">0</span></span>
                            <div class="keyboard-controls">
                                <button class="btn btn-toggle" id="toggle-keyboard-test" onclick="toggleKeyboardTest()">Iniciar Prueba</button>
                                <button class="btn" onclick="resetKeyboardTest()">Reiniciar</button>
                            </div>
                        </div>
                        <div class="keyboard-row"><div class="key" id="Escape">Esc</div><div class="key" id="F1">F1</div><div class="key" id="F2">F2</div><div class="key" id="F3">F3</div><div class="key" id="F4">F4</div><div class="key" id="F5">F5</div><div class="key" id="F6">F6</div><div class="key" id="F7">F7</div><div class="key" id="F8">F8</div><div class="key" id="F9">F9</div><div class="key" id="F10">F10</div><div class="key" id="F11">F11</div><div class="key" id="F12">F12</div></div>
                        <div class="keyboard-row"><div class="key" id="Backquote">`</div><div class="key" id="Digit1">1</div><div class="key" id="Digit2">2</div><div class="key" id="Digit3">3</div><div class="key" id="Digit4">4</div><div class="key" id="Digit5">5</div><div class="key" id="Digit6">6</div><div class="key" id="Digit7">7</div><div class="key" id="Digit8">8</div><div class="key" id="Digit9">9</div><div class="key" id="Digit0">0</div><div class="key" id="Minus">-</div><div class="key" id="Equal">=</div><div class="key long" id="Backspace">Backspace</div></div>
                        <div class="keyboard-row"><div class="key mid" id="Tab">Tab</div><div class="key" id="KeyQ">Q</div><div class="key" id="KeyW">W</div><div class="key" id="KeyE">E</div><div class="key" id="KeyR">R</div><div class="key" id="KeyT">T</div><div class="key" id="KeyY">Y</div><div class="key" id="KeyU">U</div><div class="key" id="KeyI">I</div><div class="key" id="KeyO">O</div><div class="key" id="KeyP">P</div><div class="key" id="BracketLeft">[</div><div class="key" id="BracketRight">]</div><div class="key mid" id="Backslash">\</div></div>
                        <div class="keyboard-row"><div class="key long" id="CapsLock">Caps Lock</div><div class="key" id="KeyA">A</div><div class="key" id="KeyS">S</div><div class="key" id="KeyD">D</div><div class="key" id="KeyF">F</div><div class="key" id="KeyG">G</div><div class="key" id="KeyH">H</div><div class="key" id="KeyJ">J</div><div class="key" id="KeyK">K</div><div class="key" id="KeyL">L</div><div class="key" id="Semicolon">;</div><div class="key" id="Quote">'</div><div class="key long" id="Enter">Enter</div></div>
                        <div class="keyboard-row"><div class="key long" id="ShiftLeft">Shift</div><div class="key" id="KeyZ">Z</div><div class="key" id="KeyX">X</div><div class="key" id="KeyC">C</div><div class="key" id="KeyV">V</div><div class="key" id="KeyB">B</div><div class="key" id="KeyN">N</div><div class="key" id="KeyM">M</div><div class="key" id="Comma">,</div><div class="key" id="Period">.</div><div class="key" id="Slash">/</div><div class="key long" id="ShiftRight">Shift</div></div>
                        <div class="keyboard-row"><div class="key" id="ControlLeft">Ctrl</div><div class="key" id="MetaLeft">Win</div><div class="key" id="AltLeft">Alt</div><div class="key space" id="Space">Space</div><div class="key" id="AltRight">Alt</div><div class="key" id="ControlRight">Ctrl</div><div class="key" id="ArrowLeft">◄</div><div class="key" id="ArrowUp">▲</div><div class="key" id="ArrowDown">▼</div><div class="key" id="ArrowRight">►</div></div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <script>
        let audioContext;
        function playSound() {
            if (!audioContext) { audioContext = new (window.AudioContext || window.webkitAudioContext)(); }
            if (audioContext.state === 'suspended') { audioContext.resume(); }
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            oscillator.type = 'sine';
            oscillator.frequency.setValueAtTime(440, audioContext.currentTime);
            gainNode.gain.setValueAtTime(0.5, audioContext.currentTime);
            oscillator.start();
            oscillator.stop(audioContext.currentTime + 0.2);
        }
        const pixelTesterDiv = document.getElementById('pixel-tester');
        function startPixelTest(color) { pixelTesterDiv.style.backgroundColor = color; pixelTesterDiv.style.display = 'block'; }
        function endPixelTest() { pixelTesterDiv.style.display = 'none'; }
        let isKeyboardTestActive = false;
        const testedKeys = new Set();
        const keyCounter = document.getElementById('key-count-value');
        const keyboardContainer = document.getElementById('keyboard-container');
        const toggleBtn = document.getElementById('toggle-keyboard-test');
        function toggleKeyboardTest() {
            isKeyboardTestActive = !isKeyboardTestActive;
            if (isKeyboardTestActive) {
                toggleBtn.textContent = 'Detener Prueba';
                keyboardContainer.classList.remove('inactive');
                window.focus();
            } else {
                toggleBtn.textContent = 'Iniciar Prueba';
                keyboardContainer.classList.add('inactive');
                const pressedKeys = keyboardContainer.querySelectorAll('.pressed');
                pressedKeys.forEach(k => k.classList.remove('pressed'));
            }
        }
        window.addEventListener('keydown', function(e) {
            if (!isKeyboardTestActive) return;
            e.preventDefault();
            const keyElement = document.getElementById(e.code);
            if (keyElement) { keyElement.classList.add('pressed'); }
        });
        window.addEventListener('keyup', function(e) {
            if (!isKeyboardTestActive) return;
            const keyElement = document.getElementById(e.code);
            if (keyElement) {
                keyElement.classList.remove('pressed');
                if (!keyElement.classList.contains('tested')) {
                    keyElement.classList.add('tested');
                    testedKeys.add(e.code);
                    keyCounter.textContent = testedKeys.size;
                }
            }
        });
        function resetKeyboardTest() {
            testedKeys.clear();
            keyCounter.textContent = 0;
            const allKeys = keyboardContainer.querySelectorAll('.key');
            allKeys.forEach(k => { k.classList.remove('pressed'); k.classList.remove('tested'); });
            if (isKeyboardTestActive) { toggleKeyboardTest(); }
        }
        document.addEventListener('DOMContentLoaded', () => {
            keyboardContainer.classList.add('inactive');
        });
    </script>
</body>
</html>
'@

# Reemplazar los marcadores en la plantilla con los datos recopilados
$finalHtml = $htmlTemplate `
    -replace '<!--FECHA-->', (Get-Date -Format "dd/MM/yyyy HH:mm:ss") `
    -replace '<!--FABRICANTE-->', $SystemInfo.Manufacturer `
    -replace '<!--MODELO-->', $SystemInfo.Model `
    -replace '<!--SO-->', "$($SystemInfo.OS) ($($SystemInfo.OSArch))" `
    -replace '<!--CPU-->', $SystemInfo.CPU `
    -replace '<!--NUCLEOS-->', "$($SystemInfo.Cores) / $($SystemInfo.Threads)" `
    -replace '<!--RAM-->', "$($SystemInfo.RAM_GB) GB" `
    -replace '<!--RESOLUCION-->', $SystemInfo.Resolution `
    -replace '<!--GPU-->', $SystemInfo.GPU `
    -replace '<!--VRAM-->', "$($SystemInfo.GPUMemory_GB) GB" `
    -replace '<!--DISCOS-->', $diskHtml `
    -replace '<!--SALUD_BATERIA-->', $SystemInfo.BatteryHealth `
    -replace '<!--CICLOS_BATERIA-->', $SystemInfo.BatteryCycles `
    -replace '<!--CAPACIDAD_ORIGINAL_BATERIA-->', $SystemInfo.BatteryDesign `
    -replace '<!--CAPACIDAD_ACTUAL_BATERIA-->', $SystemInfo.BatteryFullCharge `
    -replace '<!--WIFI-->', $SystemInfo.WifiAdapter `
    -replace '<!--BLUETOOTH-->', $SystemInfo.BluetoothAdapter `
    -replace '<!--AUDIO-->', $audioHtml `
    -replace '<!--CAMARA-->', $cameraHtml

# Guardar el archivo HTML final
$finalHtml | Out-File -FilePath "Resumen.html" -Encoding utf8

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "             INSPECCIÓN COMPLETADA" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

Write-Host "             CREDITOS: Rodyher" -ForegroundColor Green
Write-Host "             https://github.com/Rodyher" -ForegroundColor Green
Write-Host "             Redes sociales:   @rodyher" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host ""
Write-Host "[+] Abriendo el informe interactivo..."

# Abrir el informe y la carpeta de resultados
Invoke-Item "Resumen.html"
Invoke-Item .
echo ------------------------------------------------------------------

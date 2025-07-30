#!/bin/bash

# =================================================================================
# ||                                                                             ||
# ||                 SCRIPT DE ANÁLISIS RÁPIDO DE SISTEMA LINUX                  ||
# ||                                                                             ||
# =================================================================================

# --- FASE 0: CONFIGURACIÓN INICIAL ---
echo -e "\e[32m=================================================\e[0m"
echo -e "\e[32m     INICIANDO EL LABORATORIO INTERACTIVO LINUX\e[0m"
echo -e "\e[32m=================================================\e[0m"
echo ""

# Crear carpeta de resultados en el directorio Home del usuario (~)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$HOME/Analisis_Sistema_$TIMESTAMP" 
mkdir -p "$REPORT_DIR"
cd "$REPORT_DIR"
echo -e "\e[34m[+]\e[0m Carpeta de resultados creada en: $REPORT_DIR"
echo ""

# --- FASE 1: RECOPILACIÓN DE DATOS ---
echo -e "\e[34m[1/8]\e[0m Obteniendo detalles del sistema..."
MANUFACTURER=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null || echo "No disponible")
MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "No disponible")
OS_INFO=$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"' || echo "No disponible")
OS_ARCH=$(uname -m)

echo -e "\e[34m[2/8]\e[0m Obteniendo detalles de la CPU y RAM..."
CPU_INFO=$(lscpu | grep "Model name" | cut -d ':' -f 2 | sed 's/^[ \t]*//' || echo "No disponible")
CORES=$(lscpu | grep "^Core(s) per socket" | awk '{print $NF}')
THREADS=$(lscpu | grep "^Thread(s) per core" | awk '{print $NF}')
CPU_THREADS=$((CORES * THREADS))
RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo || echo "N/A")

echo -e "\e[34m[3/8]\e[0m Obteniendo detalles de la GPU y Pantalla..."
GPU=$(lspci | grep -i 'VGA\|3D\|2D' | head -n 1 | cut -d ':' -f3 | sed 's/ (rev ..)//' | sed 's/^[ \t]*//' || echo "No disponible")
RESOLUTION=$(xrandr --current 2>/dev/null | grep '*' | uniq | awk '{print $1}' || echo "No disponible")

echo -e "\e[34m[4/8]\e[0m Analizando unidades de disco..."
DISK_HTML=""
while read -r name model size rota type; do
    disk_type="HDD"
    if [ "$rota" = "0" ]; then
        disk_type="SSD"
    elif [ "$type" = "rom" ]; then
        disk_type="Optical"
    fi
    DISK_HTML+="<div class=\"storage-item\"><div class=\"info-row\"><span class=\"info-label\">Modelo</span><span class=\"info-value\">$model</span></div><div class=\"info-row\"><span class=\"info-label\">Tamaño</span><span class=\"info-value\">$size</span></div><div class=\"info-row\"><span class=\"info-label\">Tipo</span><span class=\"info-value\">$disk_type</span></div></div>"
done < <(lsblk -o NAME,MODEL,SIZE,ROTA,TYPE -dn -p | grep "disk")

echo -e "\e[34m[5/8]\e[0m Verificando conectividad..."
WIFI=$(lspci | grep -i "Network controller\|Wireless" | cut -d ':' -f3 | sed 's/^[ \t]*//' || echo "No detectado")
BLUETOOTH=$(lsusb | grep -i "Bluetooth" | cut -d ' ' -f 7- || echo "No detectado")

echo -e "\e[34m[6/8]\e[0m Listando dispositivos de Audio y Cámara..."
AUDIO_DEVICES=$(aplay -l | grep "card" | cut -d ':' -f 2 | cut -d '[' -f 1 | sed 's/^[ \t]*//')
CAMERA_DEVICES=$(ls /dev/video* 2>/dev/null || echo "No detectada")

echo -e "\e[34m[7/8]\e[0m Analizando estado de la batería..."
BAT_PATH=$(find /sys/class/power_supply/ -name 'BAT*' | head -n 1)
if [ -d "$BAT_PATH" ]; then
    DESIGN_CAP=$(cat "$BAT_PATH/energy_full_design" 2>/dev/null || cat "$BAT_PATH/charge_full_design" 2>/dev/null)
    FULL_CAP=$(cat "$BAT_PATH/energy_full" 2>/dev/null || cat "$BAT_PATH/charge_full" 2>/dev/null)
    CYCLES=$(cat "$BAT_PATH/cycle_count" 2>/dev/null || echo "N/A")
    if [ -n "$DESIGN_CAP" ] && [ -n "$FULL_CAP" ]; then
        HEALTH=$((100 * FULL_CAP / DESIGN_CAP))
        DESIGN_CAP_MWH=$(($DESIGN_CAP / 1000))
        FULL_CAP_MWH=$(($FULL_CAP / 1000))
    else
        HEALTH="N/A"
    fi
else
    DESIGN_CAP_MWH="N/A"; FULL_CAP_MWH="N/A"; CYCLES="N/A"; HEALTH="N/A"
fi

echo -e "\e[34m[8/8]\e[0m Prueba de Sonido del Sistema... ¡ESCUCHA!"
echo -e '\a'
sleep 1

echo ""
echo -e "\e[32m=================================================\e[0m"
echo -e "\e[32m      GENERANDO INFORME INTERACTIVO HTML\e[0m"
echo -e "\e[32m=================================================\e[0m"
echo ""

# --- FASE 2: GENERACIÓN DEL INFORME HTML ---

AUDIO_HTML=""
while IFS= read -r line; do
    AUDIO_HTML+="<li>$line</li>"
done <<< "$AUDIO_DEVICES"

CAMERA_HTML=""
while IFS= read -r line; do
    CAMERA_HTML+="<li>$line</li>"
done <<< "$CAMERA_DEVICES"

cat > Resumen.html <<EOF
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
        body { font-family: 'Inter', sans-serif; background: linear-gradient(135deg, #0c0c0c 0%, #1a1a2e 25%, #16213e 50%, #0f3460 100%); min-height: 100vh; color: var(--text-primary); overflow-x: hidden; }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .header { text-align: center; margin-bottom: 3rem; }
        .header h1 { font-size: 3rem; font-weight: 700; background: var(--primary-gradient); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 0.5rem; }
        .header .subtitle { color: var(--text-secondary); font-size: 1.1rem; }
        .glass-card { background: var(--glass-bg); backdrop-filter: blur(20px); border: 1px solid var(--glass-border); border-radius: 20px; padding: 2rem; margin-bottom: 2rem; box-shadow: var(--shadow-glass); transition: all 0.3s; }
        .glass-card:hover { transform: translateY(-5px); box-shadow: var(--shadow-hover); }
        .section-title { font-size: 1.5rem; font-weight: 600; margin-bottom: 1.5rem; display: flex; align-items: center; gap: 0.75rem; }
        .section-title::before { content: ''; width: 4px; height: 1.2em; background: var(--accent-gradient); border-radius: 2px; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1.5rem; }
        .info-row { display: flex; justify-content: space-between; align-items: center; padding: 0.75rem 0; border-bottom: 1px solid rgba(255, 255, 255, 0.05); }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 500; color: var(--text-secondary); font-size: 0.95rem; }
        .info-value { font-weight: 600; text-align: right; max-width: 60%; }
        .storage-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; margin-top: 1rem; }
        .storage-item { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 1.5rem; }
        .battery-health { display: inline-flex; align-items: center; gap: 0.5rem; }
        .health-indicator { width: 8px; height: 8px; border-radius: 50%; background: #10b981; animation: pulse 2s infinite; }
        .testing-lab { background: rgba(255, 255, 255, 0.02); border-radius: 20px; padding: 2rem; margin-top: 2rem; }
        .test-section { margin-bottom: 2rem; }
        .test-section:last-child { margin-bottom: 0; }
        .test-title { font-size: 1.1rem; font-weight: 600; margin-bottom: 1rem; }
        .test-buttons { display: flex; flex-wrap: wrap; gap: 0.75rem; }
        .btn { background: var(--glass-bg); backdrop-filter: blur(10px); border: 1px solid var(--glass-border); border-radius: 12px; padding: 0.75rem 1.5rem; font-family: inherit; font-weight: 500; color: var(--text-primary); cursor: pointer; transition: all 0.3s; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3); }
        .btn-red { background: linear-gradient(135deg, #ff6b6b, #ee5a52); }
        .btn-green { background: linear-gradient(135deg, #51cf66, #40c057); }
        .btn-blue { background: linear-gradient(135deg, #4dabf7, #339af0); }
        .btn-black { background: linear-gradient(135deg, #495057, #343a40); }
        .btn-white { background: linear-gradient(135deg, #f8f9fa, #e9ecef); color: #333; }
        .btn-toggle { background: var(--toggle-btn-bg); }
        .pixel-tester { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: 9999; display: none; cursor: pointer; }
        .keyboard-container { background: rgba(0, 0, 0, 0.3); border-radius: 16px; padding: 1.5rem; margin-top: 1rem; }
        .keyboard-info { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; padding-bottom: 1rem; border-bottom: 1px solid rgba(255, 255, 255, 0.1); }
        .keyboard-controls { display: flex; gap: 10px; }
        .keyboard-container.inactive .keyboard-row { opacity: 0.6; }
        .key { background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 8px; padding: 0.75rem; min-width: 45px; text-align: center; font-weight: 500; color: var(--text-secondary); user-select: none; }
        .key.pressed { background: var(--accent-gradient); color: white; }
        .key.tested { background: var(--tested-key-bg); color: white; }
        .keyboard-row { display: flex; justify-content: center; gap: 0.25rem; margin-bottom: 0.25rem; }
        .key.long { flex-grow: 1; } .key.mid { flex-grow: 0.5; } .key.space { flex-grow: 8; }
        .device-list { list-style: none; padding: 0; }
        .device-list li { background: rgba(255, 255, 255, 0.03); border-radius: 8px; padding: 0.75rem 1rem; margin-bottom: 0.5rem; }
        @keyframes pulse { 50% { opacity: 0.7; transform: scale(1.1); } }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>Sistema de Análisis</h1>
        <p class="subtitle">Panel de Control • Generado el: $(date)</p>
    </div>
    <div class="glass-card">
        <h2 class="section-title">Especificaciones Técnicas</h2>
        <div class="info-grid">
            <div>
                <div class="info-row"><span class="info-label">Fabricante</span><span class="info-value">$MANUFACTURER</span></div>
                <div class="info-row"><span class="info-label">Modelo</span><span class="info-value">$MODEL</span></div>
                <div class="info-row"><span class="info-label">Sistema Operativo</span><span class="info-value">$OS_INFO ($OS_ARCH)</span></div>
                <div class="info-row"><span class="info-label">Procesador</span><span class="info-value">$CPU_INFO</span></div>
            </div>
            <div>
                <div class="info-row"><span class="info-label">Núcleos / Hilos</span><span class="info-value">$CORES / $CPU_THREADS</span></div>
                <div class="info-row"><span class="info-label">RAM Instalada</span><span class="info-value">${RAM_GB} GB</span></div>
                <div class="info-row"><span class="info-label">Resolución de Pantalla</span><span class="info-value">$RESOLUTION</span></div>
                <div class="info-row"><span class="info-label">Tarjeta Gráfica</span><span class="info-value">$GPU</span></div>
            </div>
        </div>
    </div>
    <div class="glass-card">
        <h2 class="section-title">Almacenamiento</h2>
        <div class="storage-grid">$DISK_HTML</div>
    </div>
    <div class="glass-card">
        <h2 class="section-title">Estado de la Batería</h2>
        <div class="info-grid">
            <div>
                <div class="info-row"><span class="info-label">Salud General</span><span class="info-value battery-health"><span class="health-indicator"></span>${HEALTH}%</span></div>
                <div class="info-row"><span class="info-label">Ciclos de Carga</span><span class="info-value">$CYCLES</span></div>
            </div>
            <div>
                <div class="info-row"><span class="info-label">Capacidad Original</span><span class="info-value">${DESIGN_CAP_MWH} mWh</span></div>
                <div class="info-row"><span class="info-label">Capacidad Actual</span><span class="info-value">${FULL_CAP_MWH} mWh</span></div>
            </div>
        </div>
    </div>
    <div class="glass-card">
        <h2 class="section-title">Conectividad y Dispositivos</h2>
        <div class="info-grid">
            <div>
                <div class="info-row"><span class="info-label">Adaptador Wi-Fi</span><span class="info-value">$WIFI</span></div>
                <div class="info-row"><span class="info-label">Adaptador Bluetooth</span><span class="info-value">$BLUETOOTH</span></div>
            </div>
            <div>
                <h3 style="color: var(--text-primary); margin-bottom: 1rem; font-size: 1.1rem;">Dispositivos de Audio</h3><ul class="device-list">$AUDIO_HTML</ul>
                <h3 style="color: var(--text-primary); margin: 1.5rem 0 1rem; font-size: 1.1rem;">Cámaras Detectadas</h3><ul class="device-list">$CAMERA_HTML</ul>
            </div>
        </div>
    </div>
    <div class="glass-card"><h2 class="section-title">Laboratorio de Pruebas Interactivo</h2>
        <div class="testing-lab">
            <div class="test-section"><div class="test-title">🔊 Prueba de Audio</div><div class="test-buttons"><button class="btn" onclick="playSound()">Reproducir Sonido de Prueba</button></div></div>
            <div class="test-section"><div class="test-title">🖥️ Prueba de Píxeles</div><div class="test-buttons"><button class="btn btn-red" onclick="startPixelTest('red')">Rojo</button><button class="btn btn-green" onclick="startPixelTest('green')">Verde</button><button class="btn btn-blue" onclick="startPixelTest('blue')">Azul</button><button class="btn btn-black" onclick="startPixelTest('black')">Negro</button><button class="btn btn-white" onclick="startPixelTest('white')">Blanco</button></div><div id="pixel-tester" class="pixel-tester" onclick="endPixelTest()"></div></div>
            <div class="test-section"><div class="test-title">⌨️ Prueba de Teclado</div><div class="keyboard-container inactive" id="keyboard-container"><div class="keyboard-info"><span class="key-counter-text">Teclas probadas: <span id="key-count-value">0</span></span><div class="keyboard-controls"><button class="btn btn-toggle" id="toggle-keyboard-test" onclick="toggleKeyboardTest()">Iniciar Prueba</button><button class="btn" onclick="resetKeyboardTest()">Reiniciar</button></div></div>
            <div class="keyboard-row"><div class="key" id="Escape">Esc</div><div class="key" id="F1">F1</div><div class="key" id="F2">F2</div><div class="key" id="F3">F3</div><div class="key" id="F4">F4</div><div class="key" id="F5">F5</div><div class="key" id="F6">F6</div><div class="key" id="F7">F7</div><div class="key" id="F8">F8</div><div class="key" id="F9">F9</div><div class="key" id="F10">F10</div><div class="key" id="F11">F11</div><div class="key" id="F12">F12</div></div>
            <div class="keyboard-row"><div class="key" id="Backquote">\`</div><div class="key" id="Digit1">1</div><div class="key" id="Digit2">2</div><div class="key" id="Digit3">3</div><div class="key" id="Digit4">4</div><div class="key" id="Digit5">5</div><div class="key" id="Digit6">6</div><div class="key" id="Digit7">7</div><div class="key" id="Digit8">8</div><div class="key" id="Digit9">9</div><div class="key" id="Digit0">0</div><div class="key" id="Minus">-</div><div class="key" id="Equal">=</div><div class="key long" id="Backspace">Backspace</div></div>
            <div class="keyboard-row"><div class="key mid" id="Tab">Tab</div><div class="key" id="KeyQ">Q</div><div class="key" id="KeyW">W</div><div class="key" id="KeyE">E</div><div class="key" id="KeyR">R</div><div class="key" id="KeyT">T</div><div class="key" id="KeyY">Y</div><div class="key" id="KeyU">U</div><div class="key" id="KeyI">I</div><div class="key" id="KeyO">O</div><div class="key" id="KeyP">P</div><div class="key" id="BracketLeft">[</div><div class="key" id="BracketRight">]</div><div class="key mid" id="Backslash">\\</div></div>
            <div class="keyboard-row"><div class="key long" id="CapsLock">Caps Lock</div><div class="key" id="KeyA">A</div><div class="key" id="KeyS">S</div><div class="key" id="KeyD">D</div><div class="key" id="KeyF">F</div><div class="key" id="KeyG">G</div><div class="key" id="KeyH">H</div><div class="key" id="KeyJ">J</div><div class="key" id="KeyK">K</div><div class="key" id="KeyL">L</div><div class="key" id="Semicolon">;</div><div class="key" id="Quote">'</div><div class="key long" id="Enter">Enter</div></div>
            <div class="keyboard-row"><div class="key long" id="ShiftLeft">Shift</div><div class="key" id="KeyZ">Z</div><div class="key" id="KeyX">X</div><div class="key" id="KeyC">C</div><div class="key" id="KeyV">V</div><div class="key" id="KeyB">B</div><div class="key" id="KeyN">N</div><div class="key" id="KeyM">M</div><div class="key" id="Comma">,</div><div class="key" id="Period">.</div><div class="key" id="Slash">/</div><div class="key long" id="ShiftRight">Shift</div></div>
            <div class="keyboard-row"><div class="key" id="ControlLeft">Ctrl</div><div class="key" id="MetaLeft">Win</div><div class="key" id="AltLeft">Alt</div><div class="key space" id="Space">Space</div><div class="key" id="AltRight">Alt</div><div class="key" id="ControlRight">Ctrl</div><div class="key" id="ArrowLeft">◄</div><div class="key" id="ArrowUp">▲</div><div class="key" id="ArrowDown">▼</div><div class="key" id="ArrowRight">►</div></div>
            </div></div>
        </div>
    </div>
</div>
<script>
    let audioContext;
    function playSound() { if (!audioContext) { audioContext = new (window.AudioContext || window.webkitAudioContext)(); } if (audioContext.state === 'suspended') { audioContext.resume(); } const o = audioContext.createOscillator(), g = audioContext.createGain(); o.connect(g); g.connect(audioContext.destination); o.type = 'sine'; o.frequency.setValueAtTime(440, audioContext.currentTime); g.gain.setValueAtTime(0.5, audioContext.currentTime); o.start(); o.stop(audioContext.currentTime + 0.2); }
    const pixelTesterDiv = document.getElementById('pixel-tester');
    function startPixelTest(c) { pixelTesterDiv.style.backgroundColor = c; pixelTesterDiv.style.display = 'block'; }
    function endPixelTest() { pixelTesterDiv.style.display = 'none'; }
    let isKeyboardTestActive = !1; const testedKeys = new Set(), keyCounter = document.getElementById('key-count-value'), keyboardContainer = document.getElementById('keyboard-container'), toggleBtn = document.getElementById('toggle-keyboard-test');
    function toggleKeyboardTest() { (isKeyboardTestActive = !isKeyboardTestActive) ? (toggleBtn.textContent = 'Detener Prueba', keyboardContainer.classList.remove('inactive'), window.focus()) : (toggleBtn.textContent = 'Iniciar Prueba', keyboardContainer.classList.add('inactive'), keyboardContainer.querySelectorAll('.pressed').forEach(k => k.classList.remove('pressed'))) }
    window.addEventListener('keydown', function (e) { if (!isKeyboardTestActive) return; e.preventDefault(); const k = document.getElementById(e.code); k && k.classList.add('pressed') });
    window.addEventListener('keyup', function (e) { if (!isKeyboardTestActive) return; const k = document.getElementById(e.code); k && (k.classList.remove('pressed'), k.classList.contains('tested') || (k.classList.add('tested'), testedKeys.add(e.code), keyCounter.textContent = testedKeys.size)) });
    function resetKeyboardTest() { testedKeys.clear(); keyCounter.textContent = 0; keyboardContainer.querySelectorAll('.key').forEach(k => { k.classList.remove('pressed'); k.classList.remove('tested') }); isKeyboardTestActive && toggleKeyboardTest() }
    document.addEventListener('DOMContentLoaded', () => { keyboardContainer.classList.add('inactive'); });
</script>
</body></html>
EOF

echo -e "\e[32m=================================================\e[0m"
echo -e "\e[32m             INSPECCIÓN COMPLETADA\e[0m"
echo -e "\e[32m=================================================\e[0m"
echo ""
echo ""
echo ""
echo -e "\e[32m=================================================\e[0m"
echo ""
echo -e "\e[32m             Creditos:          Rodyher\e[0m"
echo -e "\e[32m             https://github.com/Rodyher\e[0m"
echo -e "\e[32m             Redes Sociales:   @rodyher\e[0m"
echo ""
echo -e "\e[32m=================================================\e[0m"
echo -e "\e[34m[+]\e[0m Abriendo el informe interactivo..."

# Abrir el informe y la carpeta de resultados de forma compatible
xdg-open "Resumen.html" 2>/dev/null || open "Resumen.html" 2>/dev/null || firefox "Resumen.html" 2>/dev/null &

exit 0
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

¡Listo! Con este cambio, tu script para Linux es ahora tan robusto y fácil de usar como la versión de Windows.

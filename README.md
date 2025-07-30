# 💻 Laboratorio de Inspección de Laptops

¡Bienvenido! Este es un poderoso script de diagnóstico diseñado para ayudarte a revisar cualquier laptop con Windows de forma rápida, segura y completa antes de comprarla.

En lugar de instalar programas o conectar un USB, este proyecto te permite ejecutar un análisis profundo directamente desde internet con un solo comando. El script generará un panel de control interactivo en el escritorio del equipo, dándote toda la información técnica que necesitas y herramientas para probar el hardware en tiempo real.

---

## ✨ ¿Qué Hace Este Script?

Este "Laboratorio Interactivo" realiza dos tareas principales:

1.  **Análisis Automático del Sistema:** Recopila información crucial del hardware y la presenta en un informe web fácil de leer. Esto incluye:
    *   **Especificaciones Técnicas:** Modelo, Fabricante, Sistema Operativo.
    *   **Rendimiento:** CPU, Núcleos/Hilos, cantidad de RAM.
    *   **Pantalla y Gráficos:** Tarjeta gráfica, memoria de vídeo y resolución de pantalla.
    *   **Almacenamiento:** Lista de todos los discos duros, mostrando su tamaño, tipo (SSD o HDD) y estado de salud.
    *   **Batería:** Salud general (%), ciclos de carga, capacidad original y capacidad máxima actual.
    *   **Conectividad:** Detección de adaptadores Wi-Fi y Bluetooth.
    *   **Dispositivos:** Lista de cámaras y dispositivos de audio detectados.

2.  **Laboratorio de Pruebas Interactivo:** El informe HTML generado no es estático. Incluye herramientas para que pruebes el hardware físicamente:
    *   **Prueba de Sonido:** Un botón para reproducir un tono y verificar el funcionamiento de los altavoces.
    *   **Prueba de Píxeles:** Llena la pantalla de colores sólidos (rojo, verde, azul, negro, blanco) para que puedas detectar fácilmente píxeles muertos o atascados.
    *   **Prueba de Teclado:** Un teclado virtual que ilumina cada tecla física que presionas, confirmando su funcionamiento y llevando un conteo de las teclas probadas.

---

## 🚀 Cómo Usarlo (Guía Rápida)

Analizar un portátil es tan fácil como seguir estos 3 sencillos pasos. ¡No tardarás más de un minuto!

### Paso 1: Abrir la Terminal de Comandos

En el portátil que quieres analizar, necesitas abrir la terminal "PowerShell" con permisos especiales.

1.  Haz clic en el **Menú Inicio** (el ícono de Windows en la barra de tareas).
2.  Escribe la palabra `powershell`.
3.  En los resultados, verás "Windows PowerShell". Haz **clic derecho** sobre él.
4.  En el menú que aparece, selecciona **"Ejecutar como administrador"**.

![Paso 1: Ejecutar como administrador](https://www.adslzone.net/app/uploads-adslzone.net/2019/07/powershell-1.jpg)

5.  Si aparece una ventana pidiendo permiso, haz clic en **"Sí"**.

### Paso 2: Escribir el Comando Mágico

Ahora verás una ventana con fondo azul. Simplemente escribe (o copia y pega) el siguiente comando:

```powershell
irm https://bit.ly/PC-Tester | iex
```

O para Linux:
```bash
curl -sL https://bit.ly/PC-Tester-sh | bash
```

### Paso 3: ¡Listo! Analiza los Resultados
Presiona la tecla Enter.

El script comenzará a trabajar. Verás texto de progreso en la ventana azul.
Al cabo de un minuto aproximadamente, se abrirán dos cosas automáticamente:
Tu navegador web, mostrando el "Panel de Control" con toda la información y las pruebas interactivas.
Una carpeta en el Escritorio, que contiene informes más detallados por si quieres profundizar.
¡Ahora puedes revisar toda la información y usar las herramientas interactivas para completar tu inspección!

🛡️ ¿Es Seguro?
Sí, es 100% seguro.

Sin Instalación: El script se ejecuta directamente desde la memoria RAM. No instala ningún programa ni deja rastros permanentes en el sistema.

Código Abierto: El código fuente de este script es público aquí en GitHub. Cualquiera puede revisarlo para confirmar que solo realiza tareas de diagnóstico.

Temporal: La única cosa que se crea es la carpeta de resultados en el Escritorio, la cual puedes borrar fácilmente después de tu análisis.


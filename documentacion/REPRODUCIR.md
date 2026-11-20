# Cómo reproducir el experimento

## 1. Obtener el paquete experimental

Descarga `Paquete_Experimental_Compresion.zip` de la sección **Releases** del repositorio. Trae los scripts de medición, la plantilla de captura y la carpeta `muestra/` con los cuatro archivos de prueba. Descomprímelo y comprueba que los archivos son idénticos a los que usamos con las huellas de [muestra/README.md](../muestra/README.md).

## 2. Instalar 7-Zip

- **Windows:** <https://www.7-zip.org/> (versión de 64 bits). Sin permisos de administrador, copia `7z.exe` junto al script.
- **Linux:** `sudo apt install p7zip-full`

## 3. Preparar el equipo

1. Copia la carpeta descomprimida (scripts y `muestra/` juntos) al disco interno, por ejemplo `C:\pruebas_compresion`. No uses una USB ni una carpeta sincronizada con la nube: el tiempo de escritura contaminaría la medición.
2. Cierra navegadores, reproductores y cualquier programa abierto. Pausa actualizaciones y análisis del antivirus.
3. Conecta el equipo a la corriente y elige el plan de energía de alto rendimiento.

## 4. Medir

**Windows (PowerShell):**

```powershell
cd C:\pruebas_compresion
powershell -ExecutionPolicy Bypass -File .\Medir-Compresion.ps1 -Hilos 1
```

**Linux:**

```bash
bash medir_compresion.sh
```

El script muestra la ficha del entorno, pide confirmación, hace una compresión de calentamiento por archivo y luego las 80 mediciones. Al terminar deja los resultados en CSV. Instrucciones detalladas en el `LEEME.txt` del paquete (copia en [scripts/medicion/LEEME_paquete.txt](../scripts/medicion/LEEME_paquete.txt)).

## 5. Analizar

Reemplaza `datos/crudos/mediciones_80.csv` con tu archivo de resultados y ejecuta, desde la raíz del repositorio:

```bash
pip install -r scripts/analisis/requirements.txt
python scripts/analisis/analisis.py
```

Los tiempos absolutos dependerán de tu procesador. Lo que debería repetirse es el **orden** de los archivos (`.avi` el más lento, `.mp4` el más rápido) y la relación entre tiempo y porcentaje de compresión.

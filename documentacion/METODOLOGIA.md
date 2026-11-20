# Metodología

## Pregunta de investigación

¿Influye el tipo de archivo digital (imagen o video) en el tiempo que tarda en comprimirse?

## Hipótesis

- **H₀ (nula):** μ_imagen = μ_video. El tiempo promedio de compresión es el mismo para ambos tipos.
- **Hᵢ (de investigación):** el tipo de archivo influye de manera significativa en el tiempo de compresión, por la estructura y el volumen de sus datos.
- **Nivel de significancia:** α = 0.05, prueba bilateral.

## Variables

| Variable | Tipo | Cómo se controla o mide |
|---|---|---|
| Tipo de archivo (imagen / video) | Independiente | Dos archivos por categoría: uno sin compresión previa y uno comprimido |
| Tiempo de compresión (s) | Dependiente | `System.Diagnostics.Stopwatch`, resolución ≈ 0.1 ms, tiempo de reloj |
| Tamaño del archivo | Controlada | Los cuatro archivos miden entre 39.2 y 40.5 MiB (diferencia máxima 3.3 %) |
| Software y algoritmo | Controlada | 7-Zip 26.06, contenedor ZIP, DEFLATE, mismos argumentos para todos |
| Nivel de compresión | Controlada | `-mx=9` (máximo) |
| Hilos | Controlada | Un solo hilo |
| Equipo | Controlada | La misma computadora, conectada a la corriente, sin otros programas abiertos |

## Muestra

| Archivo | Formato | Descripción | Tamaño |
|---|---|---|---:|
| `imagen_sin_compresion.bmp` | BMP | Mapa de bits sin compresión, 3700 × 3700 px, 24 bits | 39.17 MiB |
| `imagen_comprimida.jpg` | JPEG | Compresión con pérdida, 4740 × 4740 px, calidad 98 | 40.48 MiB |
| `video_menos_comprimido.avi` | AVI | Video sin compresión (rawvideo yuv420p), 640 × 360, 30 fps | 39.89 MiB |
| `video_comprimido_moderno.mp4` | MP4 | Video H.264, 1920 × 1080, 30 fps, 30 s | 40.40 MiB |

Los cuatro archivos son sintéticos (degradados, relieve, figuras geométricas, grano y el conjunto de Mandelbrot), generados por procedimiento. No provienen de terceros, así que no hay problemas de derechos de autor y cualquiera puede repetir el experimento con los mismos archivos.

El tamaño se igualó a propósito: si un archivo pesara 5 MB y otro 300 MB, la diferencia de tiempo mediría el volumen y no la estructura del formato.

## Entorno de prueba

| Elemento | Valor |
|---|---|
| Procesador | Intel Core i5-13420H |
| Memoria | 16 GB RAM |
| Almacenamiento | SSD (carpeta de trabajo en el disco local, no en USB ni en la nube) |
| Sistema operativo | Windows 11 (25H2) |
| Energía | Conectado a la corriente |
| Software | 7-Zip 26.06 (`7z.exe`) |
| Comando | `7z a -tzip -mm=Deflate -mx=9 -mmt=1 <salida.zip> <archivo>` |
| Fecha de medición | 14 de noviembre de 2026 |

## Procedimiento

1. **Prueba piloto:** 3 repeticiones por archivo para validar el script y el entorno.
2. **Calentamiento:** antes de medir cada archivo se hace una compresión que no se registra, para que el primer intento no salga inflado por la caché del disco.
3. **Corrida principal:** 20 repeticiones por archivo, 80 en total, ejecutadas por `scripts/medicion/Medir-Compresion.ps1` sin intervención humana. Cada ZIP se borra antes de la siguiente repetición.
4. **Registro:** el script guarda cada medición en CSV (tiempo, tamaños, porcentaje de compresión y código de salida de 7-Zip). Las 80 ejecuciones terminaron con código 0.
5. **Análisis:** `scripts/analisis/analisis.py`.

## Análisis estadístico

- **Descriptivo por archivo:** media, desviación estándar, coeficiente de variación, error absoluto (s/√n), error relativo, intervalo de confianza al 95 %, mínimo, máximo y mediana.
- **Control de calidad del dato:** se exigió CV < 10 %. Los cuatro archivos quedaron por debajo de 1.1 %.
- **Valores atípicos:** criterio del rango intercuartílico (1.5 × IQR). Se conservaron en el análisis; ninguno cambia las conclusiones.
- **Deriva:** regresión lineal del tiempo contra el número de intento. Solo el `.mp4` mostró pendiente significativa (+0.0076 s por intento, p = 0.007), compatible con el calentamiento del procesador.
- **Contraste de hipótesis:** prueba t de Welch (no supone varianzas iguales), imagen (n = 40) contra video (n = 40), y comparaciones por pares de archivos.
- **Relación con la compresibilidad:** correlación de Pearson entre el tiempo promedio y el porcentaje de tamaño final tras el ZIP.
- **Repetibilidad:** las medias de la prueba piloto difieren menos de 1 % de las de la corrida principal.

## Alcance

Las conclusiones valen para DEFLATE a nivel máximo en un solo hilo. Con otro algoritmo (LZMA, Zstandard), otro nivel o compresión multihilo los tiempos absolutos cambiarían. La muestra tiene un archivo por formato; para generalizar la hipótesis emergente (el tiempo crece cuanto menos comprimido está el archivo, sin importar si es imagen o video) se necesitan más archivos por formato y con distintos grados de compresión previa.

# Diccionario de datos

## `datos/crudos/mediciones_80.csv`

Salida directa del script de medición. Una fila por ejecución de 7-Zip (80 filas). Codificación UTF-8 con BOM, separador coma.

| Columna | Tipo | Unidad | Descripción |
|---|---|---|---|
| `No` | entero | — | Número del archivo en la muestra (1 a 4) |
| `TipoArchivo` | texto | — | `Imagen` o `Video` (variable independiente) |
| `NombreArchivo` | texto | — | Nombre del archivo comprimido |
| `Formato` | texto | — | Extensión: `.bmp`, `.jpg`, `.avi`, `.mp4` |
| `Repeticion` | entero | — | Número de intento, 1 a 20 |
| `Tiempo_s` | decimal | segundos | Tiempo de compresión (variable dependiente), 4 decimales |
| `Tiempo_ms` | decimal | milisegundos | El mismo tiempo en ms, 2 decimales |
| `BytesOriginal` | entero | bytes | Tamaño del archivo original |
| `BytesComprimido` | entero | bytes | Tamaño del ZIP resultante |
| `RatioPorc` | decimal | % | `BytesComprimido / BytesOriginal × 100`. Menor valor = más compresible |
| `CodigoSalida` | entero | — | Código de salida de 7-Zip. 0 = sin errores |

## `datos/crudos/prueba_piloto.csv`

Prueba piloto de 3 repeticiones por archivo, en el formato de la hoja de captura (una fila por archivo).

| Columna | Descripción |
|---|---|
| `T1 (s)`, `T2 (s)`, `T3 (s)` | Tiempo de cada repetición, en segundos |
| `Tiempo Promedio (s)` | Media de las tres repeticiones |
| `Desviacion Estandar` | Desviación estándar muestral, en segundos |
| `Tamano original (MiB)`, `Tamano ZIP (MiB)` | Tamaños en mebibytes (1 MiB = 1 048 576 bytes) |
| `Ratio (%)` | Tamaño ZIP / tamaño original × 100 |
| `Observaciones` | Incidencias anotadas durante la prueba |

## `datos/procesados/resumen_por_archivo.csv`

Generado por `scripts/analisis/analisis.py`. Una fila por formato.

| Columna | Descripción |
|---|---|
| `media_s`, `de_s`, `mediana_s` | Media, desviación estándar muestral y mediana, en segundos |
| `cv_pct` | Coeficiente de variación: DE / media × 100 |
| `error_abs_s` | Error absoluto (error estándar de la media): DE / √n |
| `error_rel_pct` | Error relativo: error absoluto / media × 100 |
| `ic95_s` | Semiamplitud del intervalo de confianza al 95 % (t de Student, n − 1 gl) |
| `min_s`, `intento_min`, `max_s`, `intento_max` | Extremos y el intento en que ocurrieron |
| `deriva_s_por_intento`, `deriva_p` | Pendiente de la recta tiempo contra intento y su valor p |
| `tam_original_mib`, `tam_zip_mib`, `ratio_pct` | Tamaños y porcentaje de compresión |
| `velocidad_mib_s` | Tamaño original / tiempo medio |
| `atipicos_iqr` | Intentos fuera de [Q1 − 1.5·IQR, Q3 + 1.5·IQR] |

## `datos/procesados/pruebas_t.csv`

Pruebas t de Welch. `rechaza_H0` es `True` cuando p < 0.05.

## `datos/procesados/estadisticas.json`

Todo lo anterior en un solo archivo, más la correlación tiempo contra porcentaje de compresión (`r_tiempo_vs_ratio`) y la comparación prueba piloto contra corrida principal (`piloto_vs_principal`).

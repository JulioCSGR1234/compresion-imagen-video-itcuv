#!/usr/bin/env bash
# =============================================================================
#  medir_compresion.sh  -  Version de respaldo para Linux
#  Universidad Veracruzana | Investigacion Aplicada a Tecnologias Computacionales
#  Protocolo: "Analisis experimental del tiempo de compresion en archivos
#              digitales de imagen y video"
#
#  Requisitos: p7zip-full  (sudo apt install p7zip-full)
#  Uso:        bash medir_compresion.sh
# =============================================================================
set -u

MUESTRA="${1:-./muestra}"
SALIDA="${2:-./resultados}"
REPS=20
NIVEL=9      # -mx=9  (Maxima). Debe ser el MISMO para los 4 archivos.
HILOS=1      # -mmt=1 (monohilo, menos varianza)

command -v 7z >/dev/null 2>&1 || { echo "ERROR: 7z no esta instalado. sudo apt install p7zip-full"; exit 1; }

mkdir -p "$SALIDA" "$SALIDA/_tmp"
STAMP=$(date +%Y%m%d_%H%M%S)
LARGO="$SALIDA/medidas_largo_$STAMP.csv"
FICHA="$SALIDA/ficha_entorno_$STAMP.txt"

# ---------------------------- Ficha del entorno ------------------------------
{
  echo "FICHA DEL ENTORNO DE PRUEBA"
  echo "============================================================"
  echo "Procesador                     : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
  echo "Frecuencia maxima (MHz)        : $(lscpu | grep -i 'CPU max MHz' | cut -d: -f2 | xargs)"
  echo "Nucleos / hilos                : $(nproc --all)"
  echo "Memoria RAM total              : $(free -h | awk '/^Mem:/{print $2}')"
  echo "Sistema Operativo              : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
  echo "Version exacta del kernel      : $(uname -r)"
  echo "Arquitectura                   : $(uname -m)"
  echo "Software de compresion         : 7-Zip (p7zip)"
  echo "Version del software           : $(7z 2>&1 | grep -m1 -oE '[0-9]+\.[0-9]+')"
  echo "Formato contenedor             : ZIP"
  echo "Algoritmo de compresion        : DEFLATE"
  echo "Nivel de compresion (-mx)      : $NIVEL"
  echo "Hilos (-mmt)                   : $HILOS"
  echo "Repeticiones por archivo       : $REPS"
  echo "Metodo de medicion             : date +%s%N (wall-clock, ns)"
  echo "Fecha y hora de la prueba      : $(date '+%Y-%m-%d %H:%M:%S')"
} | tee "$FICHA"

echo ""
echo ">> Cierra navegadores y procesos pesados. ENTER para iniciar las 80 ejecuciones."
read -r _

echo "No,TipoArchivo,NombreArchivo,Formato,Repeticion,Tiempo_s,Tiempo_ms,BytesOriginal,BytesComprimido,RatioPorc" > "$LARGO"

i=0
for spec in "1:Imagen:bmp" "2:Imagen:jpg" "3:Video:avi" "4:Video:mp4"; do
    IFS=: read -r NO TIPO EXT <<< "$spec"
    ARCHIVO=$(find "$MUESTRA" -maxdepth 1 -type f -iname "*.$EXT" | head -1)
    [ -z "$ARCHIVO" ] && { echo "ERROR: falta un archivo .$EXT en $MUESTRA"; exit 1; }
    NOMBRE=$(basename "$ARCHIVO")
    BYTES=$(stat -c%s "$ARCHIVO")
    DEST="$SALIDA/_tmp/salida_$NO.zip"

    echo ""
    echo "--- Archivo $NO/4: $NOMBRE ($TIPO, $(( BYTES / 1048576 )) MiB) ---"

    # Calentamiento no registrado
    rm -f "$DEST"; 7z a -tzip "-mx=$NIVEL" "-mmt=$HILOS" "$DEST" "$ARCHIVO" >/dev/null 2>&1; rm -f "$DEST"

    for r in $(seq 1 $REPS); do
        rm -f "$DEST"
        sync
        T0=$(date +%s%N)
        7z a -tzip "-mx=$NIVEL" "-mmt=$HILOS" "$DEST" "$ARCHIVO" >/dev/null 2>&1
        T1=$(date +%s%N)
        NS=$(( T1 - T0 ))
        ZB=$(stat -c%s "$DEST" 2>/dev/null || echo 0)
        S=$(awk -v n="$NS" 'BEGIN{printf "%.4f", n/1e9}')
        MS=$(awk -v n="$NS" 'BEGIN{printf "%.2f", n/1e6}')
        RT=$(awk -v a="$ZB" -v b="$BYTES" 'BEGIN{printf "%.2f", 100*a/b}')
        echo "$NO,$TIPO,$NOMBRE,.$EXT,$r,$S,$MS,$BYTES,$ZB,$RT" >> "$LARGO"
        printf "  T%-2s = %8s s\n" "$r" "$S"
    done
    rm -f "$DEST"
done

rm -rf "$SALIDA/_tmp"

echo ""
echo "=== Resumen por tipo de archivo (Tabla 4) ==="
awk -F, 'NR>1 {s[$2]+=$6; ss[$2]+=$6*$6; n[$2]++}
         END {for (t in s) {m=s[t]/n[t]; sd=sqrt((ss[t]-n[t]*m*m)/(n[t]-1));
              printf "  %-8s n=%-3d promedio=%.4f s   desv.est=%.4f\n", t, n[t], m, sd}}' "$LARGO"

echo ""
echo "Datos crudos : $LARGO"
echo "Ficha entorno: $FICHA"

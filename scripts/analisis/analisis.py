"""
Análisis estadístico del experimento de tiempo de compresión.

Lee las 80 mediciones de datos/crudos/mediciones_80.csv y genera:
  - datos/procesados/resumen_por_archivo.csv   (media, DE, CV, errores, IC 95 %, atípicos, deriva)
  - datos/procesados/pruebas_t.csv             (t de Welch entre categorías y entre archivos)
  - datos/procesados/estadisticas.json         (todo lo anterior en un solo archivo)
  - graficas/g1_barras.png, g2_estabilidad.png, g3_ratio.png

Uso, desde la raíz del repositorio:
    pip install -r scripts/analisis/requirements.txt
    python scripts/analisis/analisis.py
"""
import csv
import json
import math
import statistics as st
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
from scipy import stats

RAIZ = Path(__file__).resolve().parents[2]
CRUDOS = RAIZ / "datos" / "crudos"
PROC = RAIZ / "datos" / "procesados"
GRAF = RAIZ / "graficas"
PROC.mkdir(parents=True, exist_ok=True)
GRAF.mkdir(parents=True, exist_ok=True)

FORMATOS = [".bmp", ".jpg", ".avi", ".mp4"]
TIPO = {".bmp": "Imagen", ".jpg": "Imagen", ".avi": "Video", ".mp4": "Video"}
AZUL, NARANJA, AQUA, AMARILLO = "#2a78d6", "#eb6834", "#1baf7a", "#eda100"
MIB = 2 ** 20
ALFA = 0.05

# ---------------------------------------------------------------- lectura
filas = list(csv.DictReader(open(CRUDOS / "mediciones_80.csv", encoding="utf-8-sig")))
tiempos, meta = {}, {}
for f in filas:
    fmt = f["Formato"]
    tiempos.setdefault(fmt, []).append(float(f["Tiempo_s"]))
    meta[fmt] = dict(original=int(f["BytesOriginal"]), comprimido=int(f["BytesComprimido"]),
                     ratio=float(f["RatioPorc"]))
assert all(len(tiempos[k]) == 20 for k in FORMATOS), "Se esperaban 20 repeticiones por archivo"
assert all(f["CodigoSalida"] == "0" for f in filas), "Alguna ejecución de 7-Zip terminó con error"

# ---------------------------------------------------------------- por archivo
resumen = {}
for fmt in FORMATOS:
    v = tiempos[fmt]
    n, m, s = len(v), st.mean(v), st.stdev(v)
    ea = s / math.sqrt(n)                       # error absoluto (error estándar de la media)
    q1, q3 = np.percentile(v, [25, 75])
    iqr = q3 - q1
    atipicos = [(i + 1, x) for i, x in enumerate(v) if x < q1 - 1.5 * iqr or x > q3 + 1.5 * iqr]
    deriva = stats.linregress(range(1, n + 1), v)
    resumen[fmt] = dict(
        tipo=TIPO[fmt], n=n, media_s=m, de_s=s, cv_pct=s / m * 100,
        error_abs_s=ea, error_rel_pct=ea / m * 100,
        ic95_s=stats.t.ppf(0.975, n - 1) * ea,
        min_s=min(v), intento_min=v.index(min(v)) + 1,
        max_s=max(v), intento_max=v.index(max(v)) + 1,
        mediana_s=st.median(v),
        atipicos_iqr=atipicos,
        deriva_s_por_intento=deriva.slope, deriva_p=deriva.pvalue,
        tam_original_mib=meta[fmt]["original"] / MIB,
        tam_zip_mib=meta[fmt]["comprimido"] / MIB,
        ratio_pct=meta[fmt]["ratio"],
        velocidad_mib_s=meta[fmt]["original"] / MIB / m,
    )

# ---------------------------------------------------------------- pruebas t de Welch
def welch(a, b):
    t, p = stats.ttest_ind(a, b, equal_var=False)
    va, vb = st.variance(a) / len(a), st.variance(b) / len(b)
    gl = (va + vb) ** 2 / (va ** 2 / (len(a) - 1) + vb ** 2 / (len(b) - 1))
    return dict(media_a=st.mean(a), media_b=st.mean(b), t=t, gl=gl, p=p, rechaza_H0=bool(p < ALFA))

imagen = tiempos[".bmp"] + tiempos[".jpg"]
video = tiempos[".avi"] + tiempos[".mp4"]
pruebas = {"imagen_vs_video": welch(imagen, video)}
for a, b in [(".bmp", ".jpg"), (".avi", ".mp4"), (".bmp", ".mp4"), (".jpg", ".mp4")]:
    pruebas[f"{a[1:]}_vs_{b[1:]}"] = welch(tiempos[a], tiempos[b])

r_ratio = float(np.corrcoef([meta[f]["ratio"] for f in FORMATOS],
                            [resumen[f]["media_s"] for f in FORMATOS])[0, 1])

piloto = {}
for p in csv.DictReader(open(CRUDOS / "prueba_piloto.csv", encoding="utf-8-sig")):
    fmt = p["Formato"]
    pm = float(p["Tiempo Promedio (s)"])
    piloto[fmt] = dict(media_piloto_s=pm, diferencia_pct=(pm - resumen[fmt]["media_s"]) / resumen[fmt]["media_s"] * 100)

# ---------------------------------------------------------------- guardar
with open(PROC / "resumen_por_archivo.csv", "w", newline="", encoding="utf-8") as fh:
    cols = ["formato"] + [k for k in resumen[".bmp"] if k != "atipicos_iqr"] + ["atipicos_iqr"]
    w = csv.writer(fh)
    w.writerow(cols)
    for fmt in FORMATOS:
        r = resumen[fmt]
        w.writerow([fmt] + [round(r[k], 6) if isinstance(r[k], float) else r[k] for k in cols[1:-1]]
                   + ["; ".join(f"intento {i}: {x} s" for i, x in r["atipicos_iqr"]) or "ninguno"])

with open(PROC / "pruebas_t.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["comparacion", "media_a_s", "media_b_s", "t", "gl", "p", "rechaza_H0 (alfa=0.05)"])
    for k, r in pruebas.items():
        w.writerow([k, round(r["media_a"], 6), round(r["media_b"], 6), round(r["t"], 4),
                    round(r["gl"], 2), f"{r['p']:.3e}", r["rechaza_H0"]])

json.dump(dict(por_archivo=resumen, pruebas_t=pruebas, r_tiempo_vs_ratio=r_ratio, piloto_vs_principal=piloto),
          open(PROC / "estadisticas.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)

# ---------------------------------------------------------------- gráficas
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.edgecolor": "#9a9993",
                     "axes.spines.top": False, "axes.spines.right": False,
                     "xtick.color": "#52514e", "ytick.color": "#52514e"})
col_cat = {f: AZUL if TIPO[f] == "Imagen" else NARANJA for f in FORMATOS}
medias = [resumen[f]["media_s"] for f in FORMATOS]
m_img, m_vid = st.mean(imagen), st.mean(video)

# G1: barras con desviación estándar
fig, ax = plt.subplots(figsize=(6.4, 3.6), dpi=200)
ax.bar(FORMATOS, medias, yerr=[resumen[f]["de_s"] for f in FORMATOS], color=[col_cat[f] for f in FORMATOS],
       width=0.55, capsize=4, ecolor="#52514e", edgecolor="white", linewidth=2)
for x, v in zip(FORMATOS, medias):
    ax.text(x, v + 0.6, f"{v:.2f} s", ha="center", va="bottom", fontsize=9,
            bbox=dict(fc="white", ec="none", pad=1))
ax.axhline(m_img, color=AZUL, lw=1.2, ls="--")
ax.axhline(m_vid, color=NARANJA, lw=1.2, ls="--")
ax.set_ylabel("Tiempo promedio de compresión (s)")
ax.set_ylim(0, 38)
ax.grid(axis="y", color="#e6e5e0", lw=0.8)
ax.set_axisbelow(True)
ax.legend(handles=[Patch(color=AZUL, label="Imagen"), Patch(color=NARANJA, label="Video"),
                   Line2D([], [], color=AZUL, ls="--", label=f"Media imagen ({m_img:.2f} s)"),
                   Line2D([], [], color=NARANJA, ls="--", label=f"Media video ({m_vid:.2f} s)")],
          frameon=False, loc="upper left", fontsize=8.5)
fig.tight_layout()
fig.savefig(GRAF / "g1_barras.png")
plt.close(fig)

# G2: desviación porcentual de cada intento respecto a la media de su archivo
fig, ax = plt.subplots(figsize=(6.4, 3.6), dpi=200)
col_fmt = {".bmp": AZUL, ".jpg": AQUA, ".avi": NARANJA, ".mp4": AMARILLO}
for f in FORMATOS:
    m = resumen[f]["media_s"]
    ax.plot(range(1, 21), [(x - m) / m * 100 for x in tiempos[f]], color=col_fmt[f], lw=2,
            marker="o", ms=4, label=f"{f} (media {m:.2f} s)")
ax.axhline(0, color="#9a9993", lw=0.8)
ax.set_xlabel("Número de intento")
ax.set_ylabel("Desviación respecto a la media (%)")
ax.set_xticks(range(1, 21))
ax.set_ylim(-3, 5)
ax.grid(axis="y", color="#e6e5e0", lw=0.8)
ax.legend(frameon=False, fontsize=8, ncol=2, loc="upper right")
fig.tight_layout()
fig.savefig(GRAF / "g2_estabilidad.png")
plt.close(fig)

# G3: tiempo contra porcentaje de compresión logrado
fig, ax = plt.subplots(figsize=(6.4, 3.4), dpi=200)
for f in FORMATOS:
    x, y = meta[f]["ratio"], resumen[f]["media_s"]
    ax.scatter(x, y, s=70, color=col_cat[f], edgecolor="white", linewidth=2, zorder=3)
    ax.annotate(f"{f}  ({y:.2f} s)", (x, y), xytext=(8, -12 if f == ".mp4" else 4),
                textcoords="offset points", fontsize=8.5)
ax.set_xlabel("Tamaño final / tamaño original tras ZIP (%)  ← más compresible")
ax.set_ylabel("Tiempo promedio (s)")
ax.set_xlim(30, 108)
ax.set_ylim(0, 38)
ax.grid(color="#e6e5e0", lw=0.8)
ax.set_axisbelow(True)
ax.legend(handles=[Patch(color=AZUL, label="Imagen"), Patch(color=NARANJA, label="Video")],
          frameon=False, loc="upper right")
fig.tight_layout()
fig.savefig(GRAF / "g3_ratio.png")
plt.close(fig)

# ---------------------------------------------------------------- reporte en consola
print("Formato   Media (s)   DE (s)    CV (%)   MiB/s")
for f in FORMATOS:
    r = resumen[f]
    print(f"{f:8s} {r['media_s']:9.4f} {r['de_s']:8.4f} {r['cv_pct']:8.2f} {r['velocidad_mib_s']:7.2f}")
iv = pruebas["imagen_vs_video"]
print(f"\nImagen {iv['media_a']:.4f} s vs Video {iv['media_b']:.4f} s -> t = {iv['t']:.3f}, "
      f"gl = {iv['gl']:.1f}, p = {iv['p']:.3e}  ->  "
      f"{'se rechaza H0: hipótesis VERDADERA' if iv['rechaza_H0'] else 'no se rechaza H0'}")
print(f"Correlación tiempo vs. ratio: r = {r_ratio:.3f}")
print(f"\nResultados en {PROC.relative_to(RAIZ)}/ y gráficas en {GRAF.relative_to(RAIZ)}/")

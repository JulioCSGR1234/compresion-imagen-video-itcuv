# Archivos de la muestra

Los cuatro archivos de prueba pesan unos 40 MiB cada uno (160 MiB en total). Para no hacer pesado el repositorio, no se guardan aquí: están en la sección **Releases**, dentro de `Paquete_Experimental_Compresion.zip` (carpeta `muestra/`), junto con los scripts de medición.

| Archivo | Bytes | SHA-256 |
|---|---:|---|
| `imagen_sin_compresion.bmp` | 41 070 054 | `bcf93faea3a00acb920a134aa93bdebd80305ef9243f7cfc1dbe9e39590714aa` |
| `imagen_comprimida.jpg` | 42 447 426 | `7d9e37729641520051adcaba6b848ffb936a2b7e5418a1ad59726578048bc9a5` |
| `video_menos_comprimido.avi` | 41 828 314 | `518afffe025deb150ac9616d4d38f4ee8db6311c5f0dc43634e584bbfc2ac685` |
| `video_comprimido_moderno.mp4` | 42 359 278 | `df3a6c0ec21c91f73f1ce64a0a185a12cd7956c42af862a9a1c2080f272263a0` |

## Verificar que tienes los mismos archivos

**Windows (PowerShell):**

```powershell
Get-FileHash .\muestra\* -Algorithm SHA256
```

**Linux / macOS:**

```bash
sha256sum muestra/*
```

Si alguna huella no coincide, el archivo es distinto y los tiempos no serán comparables con los nuestros.

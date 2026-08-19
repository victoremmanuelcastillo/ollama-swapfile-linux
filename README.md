# Correr modelos de Ollama más grandes que tu RAM (Linux)

Script para Linux que agrega swap real en disco (btrfs-safe) para poder cargar en [Ollama](https://ollama.com) modelos que no entran en la RAM física de la máquina — sin comprar hardware nuevo. Probado corriendo un modelo de 18GB en una laptop con 7.6GB de RAM y sin GPU dedicada.

Como extra, el repo incluye un chat web mínimo para probar los modelos una vez cargados — es lo secundario, más abajo.

## Lo principal: `crear-swapfile-ollama.sh`

```bash
sudo bash crear-swapfile-ollama.sh
```

Qué hace, en orden:

1. `btrfs filesystem mkswapfile --size 32G /swapfile_ollama` — crea un archivo de 32GB ya formateado como swap, de forma segura para btrfs (ver por qué abajo).
2. `swapon /swapfile_ollama` — lo activa.
3. Lo agrega a `/etc/fstab` con prioridad baja (`pri=10`), para que el kernel prefiera usar zram (RAM comprimida, más rápido) antes de tocar disco, y para que el swap persista tras reiniciar.

Editá las variables `SWAPFILE` y `SIZE` al principio del script si querés otra ruta o tamaño.

**Requisitos:** Linux con `btrfs-progs` (para el subcomando `mkswapfile`) y systemd. Pensado y probado en un filesystem **btrfs** — en `ext4` el paso 1 cambia (`fallocate` + `mkswap` clásico sirve ahí sin problema, btrfs es el caso que necesita cuidado especial).

### Por qué no alcanza con `fallocate` + `mkswap` en btrfs

Un swapfile común puede fallar o corromperse en btrfs porque el filesystem le aplica copy-on-write y compresión por defecto, cosas incompatibles con un archivo de swap. `btrfs filesystem mkswapfile` (btrfs-progs ≥ 5.15 aprox.) crea el archivo ya con los atributos correctos. Si tu filesystem es btrfs, usá siempre esto en vez del método clásico.

## La prueba real: Qwen3.8-27B (18GB) en una laptop con 7.6GB de RAM

Hardware: laptop Linux, CPU Intel de 4 núcleos, GPU integrada (sin VRAM dedicada), 7.6GB RAM física, disco NVMe con filesystem btrfs.

**1. Diagnóstico de por qué no entraba tal cual:**
- `free -h` → RAM insuficiente para los 18GB del modelo.
- `lspci | grep -i vga` → GPU integrada, sin VRAM propia, descarta acelerar por GPU.
- `swapon --show` → solo había `zram` (swap comprimido *dentro de la misma RAM*, no agrega capacidad real para datos poco compresibles como pesos de un modelo).
- Conclusión: hacía falta swap real en disco.

**2. Crear el swap** con el script de arriba: pasó de 7.6GB de swap (solo zram) a **~39GB** (7.6GB zram + 32GB disco).

**3. Bajar y correr el modelo**, ya con espacio suficiente para paginar:
```bash
ollama pull smtek/Qwen3.8-27B:Q4_K_XL
ollama run smtek/Qwen3.8-27B:Q4_K_XL
```

**4. Resultado real:**

![Prueba de Qwen3.8-27B respondiendo "hola" en el chat web](./Captura%20de%20pantalla_20260819_151956.png)

Cargó y respondió, pero muy lento — ese "hola" tardó **~52 minutos** en total (0.15-0.32 tokens/seg). Con `vmstat 1` se confirma que el cuello de botella es I/O de disco (`wa` 40-48%, swap in/out de 130-190 MB/s constante), **no CPU** — el procesador pasa la mayoría del tiempo esperando páginas del modelo desde el NVMe, por eso ni se nota carga térmica real (el ventilador no sube).

Sirve para probar modelos grandes sin comprar hardware, pero no para uso interactivo — es demasiado lento. Con RAM suficiente (sin swap) el mismo modelo debería andar en el orden de 1-3 tokens/seg en un CPU modesto, y muchísimo más rápido con GPU/VRAM suficiente.

## Extra (opcional): chat web para probar los modelos

Esto es secundario — una forma cómoda de probar lo de arriba desde el navegador, no el punto central del repo.

```bash
./iniciar-chat.sh
```

Lista los modelos instalados en Ollama, elegís uno por número, lo precarga, y levanta un chat en `http://localhost:8080` con ese modelo ya seleccionado:

![Chat web con gemma3:1b respondiendo en español](./Captura%20de%20pantalla_20260819_152707.png)

**Cómo funciona:**
- `index.html` es una página estática (sin build, sin dependencias) que habla directo con la API de Ollama en `http://localhost:11434` (`GET /api/tags` para listar modelos, `POST /api/chat` con `stream: true` para el streaming de la respuesta).
- Un heartbeat (`HEAD /` cada 3s contra el servidor de la propia página) hace que el chat se deshabilite solo si el servidor se apaga.
- `iniciar-chat.sh` levanta `python3 -m http.server` en el puerto 8080 y precarga el modelo elegido con `keep_alive` largo. Un `trap` sobre `INT TERM HUP EXIT` limpia todo (mata el servidor, hace `ollama stop <modelo>`) sea que cierres con Ctrl+C, cierres la terminal, o el script termine por cualquier otra razón — no queda nada corriendo en segundo plano.

## Requisitos generales

- Linux (probado en una distro basada en Arch, con systemd y btrfs).
- [Ollama](https://ollama.com) instalado.
- Python 3 (solo si usás el chat web).

# Ollama Chat

Chat web mínimo para hablar con modelos locales de [Ollama](https://ollama.com) desde el navegador, sin dependencias ni build.

## Requisitos

- [Ollama](https://ollama.com) instalado y corriendo (`ollama serve`, o el servicio de systemd).
- Al menos un modelo bajado (`ollama pull <modelo>`).
- Python 3 (solo para servir el HTML estático).

## Uso

```bash
./iniciar-chat.sh
```

El script:

1. Lista los modelos que ya tenés instalados en Ollama y te deja elegir uno por número.
2. Precarga ese modelo en Ollama.
3. Levanta el chat en `http://localhost:8080` con el modelo ya seleccionado.

Con **Ctrl+C** en la terminal (o cerrando la terminal) se apaga el servidor y se descarga el modelo de memoria. La página del chat también detecta cuando el servidor se apaga y se deshabilita sola, para que no quede nada corriendo en segundo plano sin que te des cuenta.

## Cómo funciona

- **`index.html`** es una página estática (sin build, sin dependencias) que habla directo con la API de Ollama en `http://localhost:11434`:
  - `GET /api/tags` para listar los modelos instalados y llenar el `<select>`.
  - `POST /api/chat` con `stream: true` para mandar el mensaje y leer la respuesta token por token (el `body` es un `ReadableStream` que se va parseando línea por línea como JSON).
  - Un `setInterval` cada 3s hace un `HEAD /` contra el servidor que sirve la propia página (heartbeat). Si ese fetch falla (porque el servidor se apagó), la página se deshabilita sola.
  - El modelo a preseleccionar se pasa por query string (`?model=...`) y se lee con `URLSearchParams`.

- **`iniciar-chat.sh`**:
  1. Corre `ollama list`, parsea los nombres de modelo y arma un menú numerado.
  2. Con la elección, dispara un `POST /api/generate` con `prompt` vacío y `keep_alive` largo — esto hace que Ollama cargue el modelo en memoria de una, en vez de esperar al primer mensaje real.
  3. Levanta `python3 -m http.server` en el puerto 8080 (matando cualquier proceso previo en ese puerto con `fuser -k`) y guarda su PID.
  4. Imprime la URL del chat con el modelo ya en la query string.
  5. Queda en `wait` sobre el proceso del servidor. Un `trap` sobre `INT TERM HUP EXIT` corre una función de limpieza (con guarda para no duplicarse) que mata el servidor y hace `ollama stop <modelo>` — así, sea que apretés Ctrl+C, cierres la terminal, o el script termine por cualquier otra razón, no queda nada corriendo en segundo plano.

Servidor web (8080) y motor de inferencia (Ollama, puerto 11434) son procesos separados: el primero solo sirve el HTML/JS una vez; después de eso el navegador habla directo con Ollama. Por eso el heartbeat en el frontend es necesario — sin él, cerrar la terminal no alcanza para cortar una pestaña que ya cargó la página.

## Notas

Corriendo un modelo grande (ej. un 27B cuantizado) en una máquina sin suficiente RAM/VRAM, la respuesta puede tardar minutos — el cuello de botella pasa a ser el disco (swap), no el CPU. Las capturas en este repo son de esa prueba.

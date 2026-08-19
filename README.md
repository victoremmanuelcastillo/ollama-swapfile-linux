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

## Notas

Corriendo un modelo grande (ej. un 27B cuantizado) en una máquina sin suficiente RAM/VRAM, la respuesta puede tardar minutos — el cuello de botella pasa a ser el disco (swap), no el CPU. Las capturas en este repo son de esa prueba.

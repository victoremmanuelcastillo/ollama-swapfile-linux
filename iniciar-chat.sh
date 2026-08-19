#!/usr/bin/env bash
set -e

CHAT_DIR="$HOME/Proyectos/ollama-chat"
PORT=8080
OLLAMA_URL="http://localhost:11434"

echo "Modelos disponibles en Ollama:"
echo

mapfile -t MODELS < <(ollama list | tail -n +2 | awk '{print $1}')

if [ ${#MODELS[@]} -eq 0 ]; then
    echo "No hay modelos instalados. Corré 'ollama pull <modelo>' primero."
    exit 1
fi

for i in "${!MODELS[@]}"; do
    echo "$((i+1))) ${MODELS[$i]}"
done

echo
read -rp "Elegí un modelo (número): " CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#MODELS[@]}" ]; then
    echo "Opción inválida."
    exit 1
fi

MODEL="${MODELS[$((CHOICE-1))]}"
echo
echo "Cargando '$MODEL' en Ollama..."

curl -s "$OLLAMA_URL/api/generate" \
    -d "$(jq -n --arg m "$MODEL" '{model: $m, prompt: "", keep_alive: "60m"}')" \
    > /dev/null &

echo "Levantando servidor del chat en el puerto $PORT..."
fuser -k ${PORT}/tcp 2>/dev/null || true
sleep 1

cd "$CHAT_DIR"
python3 -m http.server "$PORT" > /tmp/ollama-chat-server.log 2>&1 &
SERVER_PID=$!
sleep 1

URL="http://localhost:${PORT}/?model=$(jq -rn --arg m "$MODEL" '$m|@uri')"

echo
echo "Modelo elegido: $MODEL"
echo "Chat listo en: $URL"
echo
echo "(la carga real del modelo en memoria sigue en segundo plano,"
echo " la primera respuesta puede tardar igual que antes)"
echo
echo "Ctrl+C acá cierra el servidor y descarga el modelo de la memoria."

CLEANED_UP=0
cleanup() {
    [ "$CLEANED_UP" = "1" ] && return
    CLEANED_UP=1
    kill "$SERVER_PID" 2>/dev/null || true
    ollama stop "$MODEL" 2>/dev/null || true
    echo "❌"
}
trap cleanup INT TERM HUP EXIT

wait "$SERVER_PID"

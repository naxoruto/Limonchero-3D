import os
import httpx
import subprocess

API_URL = "http://127.0.0.1:8000/stt"
WAV_FILE = "tmp_record.wav"

# --- CONFIGURACIÓN DE NIVELES DE PRONUNCIACIÓN ---
# Ajusta estos valores de 0 a 100 para ser más o menos estricto
THRESHOLD_BAD_WORD = 80        # Si una palabra tiene menos de esto, se marca como mal dicha
THRESHOLD_BAD_SENTENCE = 70    # Si el promedio es menor a esto, la frase entera es inentendible
THRESHOLD_GOOD_SENTENCE = 90   # Si el promedio es mayor o igual a esto, la pronunciación es buena
# -------------------------------------------------

def record_audio_toggle():
    print("\n🔴 PRESIONA [ENTER] para EMPEZAR a grabar...")
    input()
    
    print("🎤 GRABANDO... (Presiona [ENTER] nuevamente para DETENER)")
    # Lanzamos arecord en segundo plano (sin la limitación -d)
    # y redirigimos stderr a /dev/null para no ensuciar la salida
    p = subprocess.Popen([
        "arecord", 
        "-f", "cd", 
        "-c1", 
        "-r", "16000", 
        "-t", "wav", 
        "-q",
        WAV_FILE
    ], stderr=subprocess.DEVNULL)
    
    input()
    print("⏹️ Procesando grabación...")
    p.terminate()
    p.wait()

def test_stt():
    print("=== Probador Interactivo de STT y Pronunciación ===")
    print("Asegúrate de que el backend (main.py) esté corriendo en otra pestaña.")
    
    with httpx.Client() as client:
        while True:
            record_audio_toggle()
            
            if not os.path.exists(WAV_FILE):
                print("❌ Error: No se pudo crear el archivo de audio. Revisa tu micrófono.")
                continue
                
            print("⏳ Analizando pronunciación con Whisper...")
            try:
                with open(WAV_FILE, "rb") as f:
                    files = {"file": ("audio.wav", f, "audio/wav")}
                    res = client.post(API_URL, files=files, timeout=60.0)
                
                if res.status_code == 200:
                    data = res.json()
                    transcript = data.get("transcript", "")
                    clarity = data.get("clarity_score", 0)
                    words = data.get("words", [])
                    
                    print("\n" + "="*40)
                    print(f"📝 Transcripción: {transcript}")
                    print(f"🎯 Claridad total: {clarity}%")
                    
                    # Highlight specific bad words
                    bad_words = [w for w in words if w.get("probability", 100) < THRESHOLD_BAD_WORD]
                    if bad_words:
                        print(f"📉 Palabras mal pronunciadas (debajo de {THRESHOLD_BAD_WORD}%):")
                        for bw in bad_words:
                            print(f"   - '{bw['word']}' ({bw['probability']}%)")
                    
                    if clarity == 0 and "español" in transcript.lower():
                        print("🚨 RESULTADO: ¡HABLASTE EN ESPAÑOL!\n   Trataste de hacer trampa.")
                    elif transcript.strip() == "":
                        print("🤔 RESULTADO: No detectó ninguna voz.")
                    elif clarity < THRESHOLD_BAD_SENTENCE:
                        print("⚠️ RESULTADO: Pronunciación MALA o apenas entendible.")
                    elif clarity < THRESHOLD_GOOD_SENTENCE:
                        print("👍 RESULTADO: Pronunciación ACEPTABLE.")
                    else:
                        print("🌟 RESULTADO: Pronunciación EXCELENTE.")
                    print("="*40)
                        
                else:
                    print(f"❌ Error del servidor: {res.status_code} - {res.text}")
                    
            except Exception as e:
                print(f"❌ Error de red (¿Está el backend encendido?): {e}")
            finally:
                if os.path.exists(WAV_FILE):
                    os.remove(WAV_FILE)

if __name__ == "__main__":
    test_stt()

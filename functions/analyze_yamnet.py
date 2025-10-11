import sys
import tensorflow as tf
import numpy as np
import librosa
import pandas as pd
import os

#ใช้โมเดล TFLite แบบ Offline
MODEL_PATH = "yamnet.tflite"
CLASS_MAP_PATH = "yamnet_class_map.csv"
SAMPLE_RATE = 16000

# โหลดโมเดล
interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# โหลด class map
class_map = pd.read_csv(CLASS_MAP_PATH)['display_name'].tolist()

def classify_sound(wav_path: str):
    if not os.path.exists(wav_path):
        return "file_not_found"

    wav_data, sr = librosa.load(wav_path, sr=SAMPLE_RATE)
    if wav_data.ndim > 1:
        wav_data = np.mean(wav_data, axis=1)
    
    input_shape = input_details[0]['shape']
    chunk_size = input_shape[1]
    preds = []

    for i in range(0, len(wav_data) - chunk_size, chunk_size):
        segment = wav_data[i:i+chunk_size]
        input_tensor = np.expand_dims(segment.astype(np.float32), axis=0)
        interpreter.set_tensor(input_details[0]['index'], input_tensor)
        interpreter.invoke()
        preds.append(interpreter.get_tensor(output_details[0]['index'])[0])

    if not preds:
        return "too_short"

    avg_scores = np.mean(preds, axis=0)
    top_idx = np.argmax(avg_scores)
    predicted_label = class_map[top_idx]

    # 🔹 จัดกลุ่มเสียง
    if predicted_label in ["Snoring", "Teeth-grinding"]:
        return "snoring"
    elif predicted_label in ["Speech"]:
        return "speech"
    elif predicted_label in ["Sigh", "Cough", "Groan"]:
        return "vocalization"
    else:
        return "environment"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("unknown")
    else:
        label = classify_sound(sys.argv[1])
        print(label)

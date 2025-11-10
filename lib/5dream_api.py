# dream_api.py ก่อนเปลี่ยนโมเดล Ai
from fastapi import FastAPI
from pydantic import BaseModel
from pythainlp import word_tokenize
# from pythainlp.spell import correct
import requests
from googletrans import Translator
import time
import re
from datetime import datetime

app = FastAPI()
translator = Translator()

# พยายามใช้ get_corpus('thai_synonym') ถ้ามี ถ้าไม่มีก็ดาวน์โหลดไฟล์ data.csv จาก GitHub แล้ว parse
THAI_SYNONYM_DATA = []
import json
import os

CUSTOM_SYNONYM_PATH = r"C:\Users\ASUS\Project_Python\pythonProject\customDict1.json"
CUSTOM_SYNONYM_DICT = {}

if os.path.exists(CUSTOM_SYNONYM_PATH):
    try:
        with open(CUSTOM_SYNONYM_PATH, "r", encoding="utf-8") as f:
            raw_data = json.load(f)

        # ขยายให้เป็น bidirectional dictionary
        for key, syns in raw_data.items():
            # ใส่ key เดิมด้วย
            CUSTOM_SYNONYM_DICT.setdefault(key, list(set(syns)))
            # loop เพิ่ม mapping กลับ
            for s in syns:
                if s not in CUSTOM_SYNONYM_DICT:
                    CUSTOM_SYNONYM_DICT[s] = []
                # ใส่คำอื่นในกลุ่มเดียวกัน (ยกเว้นตัวเอง)
                CUSTOM_SYNONYM_DICT[s].extend([x for x in syns if x != s])
                if key not in CUSTOM_SYNONYM_DICT[s]:
                    CUSTOM_SYNONYM_DICT[s].append(key)
        # ลบซ้ำในแต่ละ list
        for k in CUSTOM_SYNONYM_DICT:
            CUSTOM_SYNONYM_DICT[k] = list(dict.fromkeys(CUSTOM_SYNONYM_DICT[k]))

        print(f"[DEBUG] Loaded bidirectional custom synonym dictionary ({len(CUSTOM_SYNONYM_DICT)} entries)")
    except Exception as e:
        print(f"[DEBUG] Failed to load custom synonym dictionary: {e}")
else:
    print("[DEBUG] Custom synonym file not found — skipping custom dictionary layer.")

try:
    from pythainlp.corpus import get_corpus
    try:
        data = get_corpus("thai_synonym")
        if isinstance(data, list):
            THAI_SYNONYM_DATA = [list(g) for g in data]
        else:
            # หากเป็น dict ให้เอา values
            try:
                THAI_SYNONYM_DATA = [list(v) for v in data.values()]
            except Exception:
                THAI_SYNONYM_DATA = []
        print("[DEBUG] Loaded thai_synonym via get_corpus():", len(THAI_SYNONYM_DATA), "groups")
    except Exception as e_get:
        print("[DEBUG] get_corpus('thai_synonym') failed:", e_get)
        raise e_get
except Exception:
    # fallback: ดาวน์โหลด raw data.csv จาก GitHub (ไฟล์ของ PyThaiNLP/thai-synonym)
    try:
        print("[DEBUG] Attempting to fetch thai-synonym data.csv from GitHub...")
        url = "https://raw.githubusercontent.com/PyThaiNLP/thai-synonym/master/data.csv"
        r = requests.get(url, timeout=15)
        r.raise_for_status()
        from io import StringIO
        import csv

        sio = StringIO(r.text)
        reader = csv.DictReader(sio)
        rows = list(reader)
        if rows:
            # หากมี column 'synonym' ให้ใช้คอลัมน์นั้น
            if "synonym" in rows[0]:
                for row in rows:
                    text = row.get("synonym", "")
                    if text:
                        group = [s.strip() for s in text.split("|") if s.strip()]
                        if group:
                            THAI_SYNONYM_DATA.append(group)
            else:
                # หากไม่มี header หรือชื่อคอลัมน์ต่างกัน ให้ fallback เอาคอลัมน์แรกของแต่ละ row
                for row in rows:
                    first = next(iter(row.values()))
                    if first:
                        group = [s.strip() for s in str(first).split("|") if s.strip()]
                        if group:
                            THAI_SYNONYM_DATA.append(group)
        else:
            # บางกรณีไฟล์ไม่มี header -> อ่านแบบ raw lines
            sio2 = StringIO(r.text)
            for line in sio2:
                line = line.strip()
                if not line:
                    continue
                group = [s.strip() for s in line.split("|") if s.strip()]
                if group:
                    THAI_SYNONYM_DATA.append(group)

        print("[DEBUG] Fetched thai-synonym groups from GitHub:", len(THAI_SYNONYM_DATA), "groups")
    except Exception as e_fetch:
        print("[DEBUG] Failed to load thai_synonym corpus from GitHub raw:", e_fetch)
        THAI_SYNONYM_DATA = []

def find_synonyms(word: str):

    results = []
    try:
        for group in THAI_SYNONYM_DATA:
            if word in group:
                for w in group:
                    if w and w != word:
                        results.append(w)
    except Exception as e:
        print(f"[DEBUG] find_synonyms error for '{word}': {e}")
        # คำพ้องจาก custom JSON
    try:
        if word in CUSTOM_SYNONYM_DICT:
            custom_syns = CUSTOM_SYNONYM_DICT[word]
            results.extend(custom_syns)
            print(f"[DEBUG] Custom synonyms for '{word}': {custom_syns}")
    except Exception as e:
        print(f"[DEBUG] find_synonyms() custom error for '{word}': {e}")

        # รวมผลและลบซ้ำ
    results = list(dict.fromkeys(results))

    return results

class DreamRequest(BaseModel):
    dream: str

# Endpoint เดิม Astrology
@app.post("/analyze")
async def analyze_dream(req: DreamRequest):
    dream_text = req.dream

    # 1. ตัดคำ
    tokens = word_tokenize(dream_text, engine="newmm")
    print("[DEBUG] Tokens:", tokens)

    # 2. แก้ typo
    # corrected_tokens = [correct(t) for t in tokens]

    # 3. หา synonym ไทย
    synonyms = set()
    for word in tokens:
        try:
            syns = find_synonyms(word)
            print(f"[DEBUG] Synonyms for '{word}':", syns)
            if syns:
                synonyms.update(syns)
        except Exception as e:
            print(f"[DEBUG] Error finding synonyms for '{word}': {e}")
        # ใส่คำเดิมด้วยเสมอ
        synonyms.add(word)

    #  แปลข้อความความฝันเป็นอังกฤษ
    try:
        translation = translator.translate(dream_text, src="th", dest="en")
        dream_text_en = translation.text
        print("[DEBUG] English translation:", dream_text_en)
    except Exception as e:
        print("[DEBUG] Translation error:", e)
        dream_text_en = dream_text

    # 4. Generate Image ด้วย Local Stable Diffusion
    try:
        response = requests.post(
            "http://127.0.0.1:7860/sdapi/v1/txt2img",
            json={
                "prompt": f"illustration in cartoon style of dream: {dream_text_en}, fantasy, soft colors, highly detailed",
                "steps": 20,
                "sampler_index": "Euler a"
            }
        )
        print("Stable Diffusion status:", response.status_code)

        if response.status_code == 200:
            try:
                data = response.json()
                image_base64 = data.get("images", [None])[0]
                if image_base64:
                    image_url = f"data:image/png;base64,{image_base64}"
                else:
                    image_url = "Stable Diffusion: no image returned"
            except Exception as e:
                image_url = f"Stable Diffusion JSON parse error: {e}"
        else:
            image_url = f"Stable Diffusion error: {response.text}"
    except Exception as e:
        image_url = f"Image generation failed: {e}"

    all_keywords = set(tokens) | synonyms

    return {
        "tokens": tokens,
        "matched_keywords": list(all_keywords),
        "image_url": image_url
    }

# Endpoint AI Model
@app.post("/analyze_ai")
async def analyze_dream_ai(req: DreamRequest):
    dream_text = req.dream

    # แปลข้อความความฝันเป็นอังกฤษ
    try:
        translation = translator.translate(dream_text, src="th", dest="en")
        dream_text_en = translation.text
        print("[DEBUG] English translation:", dream_text_en)
    except Exception as e:
        print("[DEBUG] Translation error:", e)
        dream_text_en = dream_text

    # 2. Generate Image ด้วย Stable Diffusion
    try:
        response = requests.post(
            "http://127.0.0.1:7860/sdapi/v1/txt2img",
            json={
                "prompt": f"surreal illustration of dream: {dream_text_en}, cinematic, detailed, vibrant colors",
                "steps": 20,
                "sampler_index": "Euler a"
            }
        )
        if response.status_code == 200:
            try:
                data = response.json()
                image_base64 = data.get("images", [None])[0]
                if image_base64:
                    image_url = f"data:image/png;base64,{image_base64}"
                else:
                    image_url = "Stable Diffusion: no image returned"
            except Exception as e:
                image_url = f"Stable Diffusion JSON parse error: {e}"
        else:
            image_url = f"Stable Diffusion error: {response.text}"
    except Exception as e:
        image_url = f"Image generation failed: {e}"

    # 3. เรียก LLaMA ผ่าน Ollama API
    # แยกการเจนคำทำนาย และเลขเด็ด
    try:
        # ทำนายความฝัน
        interpretation_prompt = (
            "คุณคือผู้เชี่ยวชาญด้านการทำนายฝันแบบไทย\n"
            "จงตอบเฉพาะเป็นภาษาไทยเท่านั้น ห้ามใช้ภาษาอื่น\n"
            "อย่าใส่เลขเด็ดหรือสัญลักษณ์ตัวเลขใด ๆ ในคำตอบนี้\n"
            "ให้คำทำนายมีความหมายชัดเจนและจบประโยคครบถ้วน\n"
            "ให้ตอบในรูปแบบข้อความสั้น ๆ ไม่เกิน 5 ประโยค\n\n"
            f"ความฝันของฉันคือ: {dream_text}\n\n"
            "คำตอบ:\n"
        )

        interp_response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.2",
                "prompt": interpretation_prompt,
                "temperature": 0.5,
                "stream": False,
                "options": {
                    "num_predict": 512,
                    "top_p": 0.9,
                    "top_k": 40
                }
            },
            timeout=180
        )

        if interp_response.status_code == 200:
            ai_interpretation = interp_response.json().get("response", "").strip()
        else:
            ai_interpretation = f"Ollama error (interpret): {interp_response.text}"

        # ส่วนที่ 2: สร้างเลขเด็ด
        number_prompt = (
            "คุณเป็นนักโหราศาสตร์ไทยที่เชี่ยวชาญการตีเลขจากความฝัน\n"
            "ให้แปลความฝันนี้ออกมาเป็นเลขเด็ดไม่เกิน 3 ชุด\n"
            "จงตอบเฉพาะตัวเลขอารบิกเท่านั้น เช่น 25, 526, 789\n"
            "ห้ามมีคำอธิบายเพิ่มเติมหรือคำไทยใด ๆ ในคำตอบ\n"
            "รูปแบบคำตอบที่ต้องการคือ:\n\n"
            "เลขเด็ด: 123, 45, 789\n\n"
            f"ความฝันของฉันคือ: {dream_text}\n\n"
            "คำตอบ:\n"
        )

        num_response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.2",
                "prompt": number_prompt,
                "temperature": 0.4,
                "stream": False,
                "options": {
                    "num_predict": 80,
                    "top_p": 0.9,
                    "top_k": 40
                }
            },
            timeout=90
        )

        if num_response.status_code == 200:
            ai_luckynumber = num_response.json().get("response", "").strip()
        else:
            ai_luckynumber = f"Ollama error (number): {num_response.text}"

    except Exception as e:
        ai_interpretation = f"error: {e}"
        ai_luckynumber = "-"

    return {
        "ai_interpretation": ai_interpretation,
        "ai_luckynumber": ai_luckynumber,
        "image_url": image_url
    }

# Run server
# cd pythonProject
# uvicorn dream_api:app --reload
# uvicorn dream_api:app --reload --host 0.0.0.0 --port 8000 (Android Emulator)
# http://127.0.0.1:8000/docs
# http://127.0.0.1:7860/

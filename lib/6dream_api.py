# api ใช้ model ai เดิม + แก้ให้เป็นตัว server ที่ส่งคำตอบไปให้ client ภายในเครือข่ายเดียวกัน + ฟังก์ชั่นเดิมทุกอย่าง
# dream_api.py
from fastapi import FastAPI
from pydantic import BaseModel
from pythainlp import word_tokenize
# from pythainlp.spell import correct
import httpx

from fastapi.middleware.cors import CORSMiddleware
from fastapi import Header, HTTPException, Depends, status
from typing import Optional, List
import requests  # ยังเก็บไว้ถ้าตรงไหนยังใช้อยู่ (แต่เราใช้ httpx เป็นหลักใน async)
from googletrans import Translator
import json
import os
import re
import time
from datetime import datetime

app = FastAPI()

translator = Translator()

THAI_SYNONYM_DATA = []

CUSTOM_SYNONYM_PATH = r"C:\Users\ASUS\Project_Python\pythonProject\customDict1.json"
CUSTOM_SYNONYM_DICT = {}

# โหลด custom dict (ถ้ามี) และขยายเป็น bidirectional mapping
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
        for k in list(CUSTOM_SYNONYM_DICT.keys()):
            CUSTOM_SYNONYM_DICT[k] = list(dict.fromkeys(CUSTOM_SYNONYM_DICT[k]))

        print(f"[DEBUG] Loaded bidirectional custom synonym dictionary ({len(CUSTOM_SYNONYM_DICT)} entries)")
    except Exception as e:
        print(f"[DEBUG] Failed to load custom synonym dictionary: {e}")
else:
    print("[DEBUG] Custom synonym file not found — skipping custom dictionary layer.")

# พยายามโหลด thai_synonym จาก pythainlp หรือ fallback ดาวน์โหลดจาก GitHub
try:
    from pythainlp.corpus import get_corpus
    try:
        data = get_corpus("thai_synonym")
        if isinstance(data, list):
            THAI_SYNONYM_DATA = [list(g) for g in data]
        else:
            try:
                THAI_SYNONYM_DATA = [list(v) for v in data.values()]
            except Exception:
                THAI_SYNONYM_DATA = []
        print("[DEBUG] Loaded thai_synonym via get_corpus():", len(THAI_SYNONYM_DATA), "groups")
    except Exception as e_get:
        print("[DEBUG] get_corpus('thai_synonym') failed:", e_get)
        raise e_get
except Exception:
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


# -----------------------------------------------------------------------------
def find_synonyms(word: str):
    """
    ค้นหาคำพ้องจาก THAI_SYNONYM_DATA และ CUSTOM_SYNONYM_DICT (ถ้ามี)
    คืนค่า list (อาจว่าง) — รวมเฉพาะคำที่ไม่ใช่คำเดิม
    """
    results = []
    try:
        for group in THAI_SYNONYM_DATA:
            if word in group:
                for w in group:
                    if w and w != word:
                        results.append(w)
    except Exception as e:
        print(f"[DEBUG] find_synonyms error for '{word}' (corpus): {e}")

    try:
        if word in CUSTOM_SYNONYM_DICT:
            custom_syns = CUSTOM_SYNONYM_DICT[word]
            results.extend(custom_syns)
            print(f"[DEBUG] Custom synonyms for '{word}': {custom_syns}")
    except Exception as e:
        print(f"[DEBUG] find_synonyms() custom error for '{word}': {e}")

    # unique + return
    results = list(dict.fromkeys(results))
    return results


class DreamRequest(BaseModel):
    dream: str

# Health endpoint (ตรวจสอบสถานะ server และเวลา)
@app.get("/health")
async def health():
    return {"status": "ok", "time": datetime.utcnow().isoformat()}


# Helper: ใช้ httpx.AsyncClient สำหรับเรียกบริการภายนอก (Stable Diffusion / Ollama)
# ทำให้ non-blocking กับ event loop
async def call_stable_diffusion(prompt_en: str, timeout: int = 60):
    url = "http://127.0.0.1:7860/sdapi/v1/txt2img"
    payload = {
        "prompt": f"{prompt_en}",
        "steps": 20,
        "sampler_index": "Euler a"
    }
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            r = await client.post(url, json=payload)
            r.raise_for_status()
            data = r.json()
            image_base64 = data.get("images", [None])[0]
            if image_base64:
                return f"data:image/png;base64,{image_base64}"
            else:
                return "Stable Diffusion: no image returned"
    except Exception as e:
        return f"Stable Diffusion failed: {e}"


async def call_ollama_generate(prompt: str, model: str = "llama3.2", max_predict: int = 512, timeout: int = 180):
    """
    Fallback call to Ollama HTTP API. Returns response string or raises HTTPException.
    """
    url = "http://localhost:11434/api/generate"
    body = {
        "model": model,
        "prompt": prompt,
        "temperature": 0.5,
        "stream": False,
        "options": {"num_predict": max_predict, "top_p": 0.9, "top_k": 40},
    }
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            r = await client.post(url, json=body)
            r.raise_for_status()
            return r.json().get("response", "").strip()
    except httpx.RequestError as re:
        raise HTTPException(status_code=503, detail=f"Ollama request failed: {re}")
    except httpx.HTTPStatusError as he:
        raise HTTPException(status_code=502, detail=f"Ollama returned bad status: {he.response.status_code}")


# Endpoint เดิม Astrology
@app.post("/analyze")
async def analyze_dream(req: DreamRequest):
    try:
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

        # แปลข้อความความฝันเป็นอังกฤษ (ยังใช้ googletrans แบบ synchronous)
        try:
            translation = translator.translate(dream_text, src="th", dest="en")
            dream_text_en = getattr(translation, "text", None) or str(translation)
            print("[DEBUG] English translation:", dream_text_en)
        except Exception as e:
            print("[DEBUG] Translation error:", e)
            dream_text_en = dream_text

        # 4. Generate Image ด้วย Local Stable Diffusion (เรียกแบบ async)
        image_url = await call_stable_diffusion(f"illustration in cartoon style of dream: {dream_text_en}, fantasy, soft colors, highly detailed", timeout=60)

        all_keywords = set(tokens) | synonyms

        return {
            "tokens": tokens,
            "matched_keywords": list(all_keywords),
            "image_url": image_url
        }
    except HTTPException:
        # ให้ HTTPException propagate (เช่นจาก call_ollama_generate)
        raise
    except Exception as e:
        print("[ERROR] analyze endpoint:", e)
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


# Endpoint AI Model
# (NEW)
@app.post("/analyze_ai")
async def analyze_dream_ai(req: DreamRequest):
    dream_text = req.dream

    # แปลข้อความ (ยังเป็น synchronous googletrans — ระวังความหน่วง ถ้าต้องการให้ non-blocking ให้รันใน thread)
    try:
        translation = translator.translate(dream_text, src="th", dest="en")
        dream_text_en = getattr(translation, "text", str(translation))
        print("[DEBUG] English translation:", dream_text_en)
    except Exception as e:
        print("[DEBUG] Translation error:", e)
        dream_text_en = dream_text

    # 1) Generate image (async helper)
    try:
        image_url = await call_stable_diffusion(
            f"surreal illustration of dream: {dream_text_en}, cinematic, detailed, vibrant colors",
            timeout=60
        )
    except Exception as e:
        image_url = f"Stable Diffusion failed: {e}"

    # 2) Prepare prompts
    interpretation_prompt = (
        "คุณคือผู้เชี่ยวชาญด้านการทำนายฝันแบบไทย\n"
        "จงตอบเฉพาะเป็นภาษาไทยเท่านั้น ห้ามใช้ภาษาอื่น\n"
        "อย่าใส่เลขเด็ดหรือสัญลักษณ์ตัวเลขใด ๆ ในคำตอบนี้\n"
        "ให้คำทำนายมีความหมายชัดเจนและจบประโยคครบถ้วน\n"
        "ให้ตอบในรูปแบบข้อความสั้น ๆ ไม่เกิน 5 ประโยค\n\n"
        f"ความฝันของฉันคือ: {dream_text}\n\n"
        "คำตอบ:\n"
    )

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

    # 3) เรียก Ollama ผ่าน async helper (non-blocking)
    try:
        ai_interpretation = await call_ollama_generate(interpretation_prompt, model="llama3.2", max_predict=512, timeout=180)
    except HTTPException:
        raise
    except Exception as e:
        ai_interpretation = f"Ollama error (interpret): {e}"

    try:
        ai_luckynumber = await call_ollama_generate(number_prompt, model="llama3.2", max_predict=80, timeout=90)
    except Exception as e:
        ai_luckynumber = f"Ollama error (number): {e}"

    return {
        "ai_interpretation": ai_interpretation,
        "ai_luckynumber": ai_luckynumber,
        "image_url": image_url
    }

# Run server
# cd pythonProject
# uvicorn dream_api:app --host 0.0.0.0 --port 8000 --reload (รัน uvicorn ให้ฟังทุก interface)
# uvicorn dream_api:app --reload
# uvicorn dream_api:app --reload --host 0.0.0.0 --port 8000 (Android Emulator)
# http://127.0.0.1:8000/docs
# http://127.0.0.1:7860/
# cd  C:\Users\ASUS\Project_Python\pythonProject
# .\.venv_llama\Scripts\Activate.ps1
# uvicorn dream_api:app --host 0.0.0.0 --port 8000 --reload
# curl -v http://100.104.205.64:8000/health

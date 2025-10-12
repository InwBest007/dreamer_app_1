# dream_api.py
from fastapi import FastAPI
from pydantic import BaseModel
from pythainlp import word_tokenize
# from pythainlp.spell import correct
from pythainlp.corpus import thai_synonym # ใช้ corpus.wordnet
import requests
from googletrans import Translator
import asyncio
# from openai import OpenAI   # เพิ่มสำหรับโมเดลทำนายฝัน GPT
# import os

app = FastAPI()
translator = Translator()
# client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class DreamRequest(BaseModel):
    dream: str

# ----------------------------
# Endpoint เดิม (Astrology)
# ----------------------------
@app.post("/analyze")
async def analyze_dream(req: DreamRequest):
    dream_text = req.dream

    # 1. ตัดคำ
    tokens = word_tokenize(dream_text, engine="newmm")

    # 2. แก้ typo
    # corrected_tokens = [correct(t) for t in tokens]

    # 3. หา synonym (ภาษาไทย) ด้วย thai_synonym
    synonyms = set()
    for word in tokens:
        try:
            syns = thai_synonym(word)
            if syns:
                synonyms.update(syns)
        except Exception:
            pass
        synonyms.add(word)

    # แปลข้อความความฝันเป็นอังกฤษ (async)
    try:
        translation = await asyncio.to_thread(
            lambda: translator.translate(dream_text, src="th", dest="en")
        )
        dream_text_en = translation.text
    except Exception as e:
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

# ----------------------------
# 🔹 Endpoint ใหม่ (AI Model)
# ----------------------------
@app.post("/analyze_ai")
async def analyze_dream_ai(req: DreamRequest):
    dream_text = req.dream

    # 1. แปลข้อความเป็นอังกฤษ
    try:
        translation = await asyncio.to_thread(
            lambda: translator.translate(dream_text, src="th", dest="en")
        )
        dream_text_en = translation.text
    except Exception:
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

    # 3. เรียก LLaMA (ผ่าน Ollama API) ให้ทำนายความฝัน
    try:
        ollama_response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.2",  # ใช้โมเดล LLaMA ที่โหลดด้วย ollama pull
                "prompt": f"คุณคือผู้เชี่ยวชาญด้านการทำนายฝันและการตีเลขเด็ด\n\nความฝัน: {dream_text}\n\nโปรดทำนายฝันนี้เป็นภาษาไทย และแนะนำเลขเด็ด 3-6 ตัวเลข",
                "temperature": 0.8,
                "stream": False, # ให้ได้ผลลัพธ์ทีเดียว

                "options": {
                    "num_predict": 256,  # จำกัด token output
                    "top_p": 0.9,  # ลด sampling complexity
                    "top_k": 40
                }
            }
        )

        if ollama_response.status_code == 200:
            gpt_reply = ollama_response.json().get("response", "").strip()
        else:
            gpt_reply = f"Ollama error: {ollama_response.text}"

        # แยกเลขเด็ดจากข้อความ
        lines = gpt_reply.strip().split("\n")
        ai_interpretation = "\n".join(lines[:-1]) if len(lines) > 1 else gpt_reply
        ai_luckynumber = lines[-1] if len(lines) > 1 else "-"
    except Exception as e:
        ai_interpretation = f"GPT error: {e}"
        ai_luckynumber = "-"

    return {
        "ai_interpretation": ai_interpretation,
        "ai_luckynumber": ai_luckynumber,
        "image_url": image_url
    }

# ----------------------------
# Run server
# ----------------------------
# cd pythonProject
# uvicorn dream_api:app --reload
# uvicorn dream_api:app --reload --host 0.0.0.0 --port 8000 (Android Emulator)
# http://127.0.0.1:8000/docs
# http://127.0.0.1:7860/

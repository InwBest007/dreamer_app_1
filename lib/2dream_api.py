# dream_api.py
from fastapi import FastAPI
from pydantic import BaseModel
from pythainlp import word_tokenize
# from pythainlp.spell import correct
from pythainlp.corpus import thai_synonym
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

# Endpoint เดิม Astrology
@app.post("/analyze")
async def analyze_dream(req: DreamRequest):
    dream_text = req.dream

    # 1. ตัดคำ
    tokens = word_tokenize(dream_text, engine="newmm")

    # 2. แก้ typo
    # corrected_tokens = [correct(t) for t in tokens]

    # 3. หา synonym ไทย
    synonyms = set()
    for word in tokens:
        try:
            syns = thai_synonym(word)
            if syns:
                synonyms.update(syns)
        except Exception:
            pass
        synonyms.add(word)

    # แปลข้อความความฝันเป็นอังกฤษ
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

# Endpoint AI Model
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

    # 3. เรียก LLaMA ผ่าน Ollama API
    # แยกการเจน คำทำนาย และเลขเด็ด
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

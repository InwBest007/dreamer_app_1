# dream_api.py ทำ nlp แบบ semantic + embedding
from fastapi import FastAPI
from pydantic import BaseModel
from pythainlp import word_tokenize
import thaispellcheck
import httpx
from fastapi import HTTPException
from typing import Optional, List
from deep_translator import GoogleTranslator
import json
import os
import re
import time
from datetime import datetime
import asyncio
import numpy as np
from sentence_transformers import SentenceTransformer
from numpy.linalg import norm

app = FastAPI()

translator = GoogleTranslator(source="th", target="en")

EMBED_MODEL = None
KEYWORD_EMB = None
KEYWORD_LIST = None
KEYWORD_INTERPS = None
KEYWORD_LUCKY = None


# -----------------------------------------------------------------------------
def init_semantic_engine():
    global EMBED_MODEL, KEYWORD_EMB, KEYWORD_LIST, KEYWORD_INTERPS, KEYWORD_LUCKY

    print("[SEMANTIC] Loading sentence embedding model...")
    EMBED_MODEL = SentenceTransformer("paraphrase-multilingual-mpnet-base-v2")

    print("[SEMANTIC] Loading keyword embeddings...")
    data = np.load(r"C:\Users\ASUS\Project_Python\dream_keyword_embeddings.npz", allow_pickle=True)
    KEYWORD_EMB = data["embeddings"]  # shape (N, dim)

    # normalize keyword embeddings หนึ่งครั้งตรงนี้
    KEYWORD_EMB = KEYWORD_EMB / np.clip(
        np.linalg.norm(KEYWORD_EMB, axis=1, keepdims=True),
        1e-8,
        None,
    )

    KEYWORD_LIST = data["keywords"].tolist()
    KEYWORD_INTERPS = data["interpretations"].tolist()
    KEYWORD_LUCKY = data["luckynumbers"].tolist()

    print(f"[SEMANTIC] Loaded {len(KEYWORD_LIST)} keywords.")


# เรียกตอน module ถูกโหลด (หรือจะผูกกับ event startup ก็ได้)
init_semantic_engine()


def semantic_match_sentence(
    sentence: str,
    top_k: int = 5,
    sim_threshold: float = 0.6,  
):
    if EMBED_MODEL is None or KEYWORD_EMB is None:
        print("[SEMANTIC] Engine not initialized.")
        return {}
    # 1) 
    s_emb = EMBED_MODEL.encode(
        [sentence],
        convert_to_numpy=True,
        normalize_embeddings=True
    )[0]  # shape (dim,)

    # 2) cosine similarity 
    sims = KEYWORD_EMB @ s_emb  

    # 3) เลือก index top 5
    top_idx = np.argsort(-sims)[:top_k]

    results: dict[str, dict] = {}

    for idx in top_idx:
        score = float(sims[idx])
        if score < sim_threshold:
            continue

        kw = KEYWORD_LIST[idx]
        interp = KEYWORD_INTERPS[idx]
        luck = KEYWORD_LUCKY[idx]
        
        results[kw] = {
            "keyword": kw,
            "interpretation": interp,
            "luckynumber": luck,
            "score": score,
        }

    # ถ้าไม่มีอะไรผ่าน threshold เลย -> fallback: เอา top_k ตัวบนสุดทั้งหมด
    if not results:
        print("[SEMANTIC] No keyword passed threshold. Using fallback top_k.")
        for idx in top_idx:
            score = float(sims[idx])
            kw = KEYWORD_LIST[idx]
            interp = KEYWORD_INTERPS[idx]
            luck = KEYWORD_LUCKY[idx]

            results[kw] = {
                "keyword": kw,
                "interpretation": interp,
                "luckynumber": luck,
                "score": score,
            }

    return results


class DreamRequest(BaseModel):
    dream: str


# Health endpoint (ตรวจสอบสถานะ server และเวลา)
@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/check_typo")
async def check_typo(req: DreamRequest):
        try:
            dream_text = req.dream

            # ตัดคำต้นฉบับ (เผื่ออยากใช้เป็น fallback)
            original_tokens = word_tokenize(dream_text, engine="newmm")

            # แก้คำผิดทั้งประโยค แล้ว tokenize ใหม่
            try:
                corrected_text = await asyncio.to_thread(
                    thaispellcheck.check,
                    dream_text,
                    autocorrect=True
                )
                corrected_tokens = word_tokenize(corrected_text, engine="newmm")
                print("[DEBUG][check_typo] Corrected text:", corrected_text)
                print("[DEBUG][check_typo] Corrected tokens:", corrected_tokens)
            except Exception as e:
                print("[DEBUG][check_typo] Spellcheck failed, fallback:", e)
                corrected_text = dream_text
                corrected_tokens = original_tokens

            # กรอง token ที่ว่างออก
            filtered_tokens = [
                t for t in corrected_tokens
                if isinstance(t, str) and t.strip()
            ]

            return {
                "original_text": dream_text,
                "corrected_text": corrected_text,
                "tokens": filtered_tokens,
                "changed": corrected_text != dream_text,
            }

        except Exception as e:
            print("[ERROR] check_typo endpoint:", e)
            raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


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

        # 2. แก้ typo (เช็คทั้งประโยค แล้ว tokenize ใหม่)
        try:
            corrected_text = await asyncio.to_thread(
                thaispellcheck.check,
                dream_text,
                autocorrect=True
            )
            corrected_tokens = word_tokenize(corrected_text, engine="newmm")
            print("[DEBUG] Corrected text:", corrected_text)
            print("[DEBUG] Corrected tokens:", corrected_tokens)
        except Exception as e:
            print("[DEBUG] Spellcheck failed, fallback:", e)
            corrected_text = dream_text
            corrected_tokens = tokens

        # 3. Semantic similarity matching (แทน synonym rule-based)
        semantic_results = semantic_match_sentence(corrected_text)

        semantic_keywords = list(semantic_results.keys())

        # ตอนนี้ใช้ semantic keywords เป็น matched keywords
        all_keywords = semantic_keywords

        # แปลข้อความ (ใช้ deep_translator แบบรันใน thread แยก)
        try:
            dream_text_en = await asyncio.to_thread(
                translator.translate,
                dream_text
            )
        except Exception as e:
            print("[DEBUG] Translation error:", e)
            dream_text_en = dream_text

        # 5. Generate Image
        image_url = await call_stable_diffusion(
            f"illustration in cartoon style of dream: {dream_text_en}, fantasy, soft colors, highly detailed",
            timeout=60
        )

        # 6. Return
        filtered_tokens = [
            t for t in corrected_tokens
            if isinstance(t, str) and t.strip()
        ]

        return {
            "tokens": filtered_tokens,
            "matched_keywords": all_keywords,
            "semantic_matches": list(semantic_results.values()),
            "image_url": image_url
        }

    except Exception as e:
        print("[ERROR] analyze endpoint:", e)
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


# Endpoint AI Model
# (NEW)
@app.post("/analyze_ai")
async def analyze_dream_ai(req: DreamRequest):
    dream_text = req.dream

    # แปลข้อความ (ใช้ deep_translator แบบรันใน thread แยก)
    try:
        dream_text_en = await asyncio.to_thread(
            translator.translate,
            dream_text
        )
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
        "คุณคือผู้เชี่ยวชาญด้านแปลความฝันในเชิงสัญลักษณ์\n"
        "จงตอบเฉพาะเป็นภาษาไทยเท่านั้น ห้ามใช้ภาษาอื่น\n"
        "อย่าใส่เลขเด็ดหรือสัญลักษณ์ตัวเลขใด ๆ ในคำตอบนี้\n" 
        "จงให้คำทำนายมีความหมายชัดเจนและจบประโยคครบถ้วน\n"
        "ให้ตอบในรูปแบบข้อความสั้น ๆ ไม่เกิน 5 ประโยค\n\n"
        f"ความฝันของฉันคือ: {dream_text}\n\n"
        "คำตอบ:\n"
    )

    number_prompt = (
        "คุณคือนักโหราศาสตร์ไทยที่เชี่ยวชาญการตีเลขจากความฝัน\n"
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

# cd  C:\Users\ASUS\Project_Python\pythonProject
# .\.venv_llama\Scripts\Activate.ps1
# python -c "import sys; print('python=', sys.executable); print('version=', sys.version)"
# curl -v http://100.104.205.64:8000/health
# python -m uvicorn dream_api:app --host 0.0.0.0 --port 8000 --reload

# uvicorn dream_api:app --host 0.0.0.0 --port 8000 --reload (รัน uvicorn ให้ฟังทุก interface)
# uvicorn dream_api:app --reload
# uvicorn dream_api:app --reload --host 0.0.0.0 --port 8000 (Android Emulator)
# http://127.0.0.1:8000/docs
# http://127.0.0.1:7860/

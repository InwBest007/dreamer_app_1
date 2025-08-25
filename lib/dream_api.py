from fastapi import FastAPI
from pydantic import BaseModel
from pythainlp import word_tokenize
from pythainlp.spell import correct
from pythainlp.corpus.wordnet import synsets  # ✅ ใช้ corpus.wordnet

app = FastAPI()

class DreamRequest(BaseModel):
    dream: str

@app.post("/analyze")
def analyze_dream(req: DreamRequest):
    dream_text = req.dream

    # 1. ตัดคำ
    tokens = word_tokenize(dream_text, engine="newmm")

    # 2. แก้ typo
    corrected_tokens = [correct(t) for t in tokens]

    # 3. หา synonym
    synonyms = set()
    for word in corrected_tokens:
        for syn in synsets(word, lang="tha"):
            synonyms.update([lemma.name() for lemma in syn.lemmas()])

    return {
        "tokens": corrected_tokens,
        "matched_keywords": list(synonyms)
    }

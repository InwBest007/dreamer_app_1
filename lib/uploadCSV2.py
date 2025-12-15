// อัปโหลดไฟล์ data extraction ไปยัง firebase ชื่อ collection dreamInt2
import firebase_admin
from firebase_admin import credentials, firestore
import csv

# เชื่อมต่อ Firebase
cred = credentials.Certificate(
    r"C:\Users\ASUS\Project_Python\pythonProject\dreamerdb-b0dc4-firebase-adminsdk-fbsvc-b7356791af.json"
)
firebase_admin.initialize_app(cred)

db = firestore.client()

# อัปโหลดข้อมูลใหม่จาก CSV
csv_path = r"C:\Users\ASUS\Project_Python\pythonProject\DBtxtDreamer_cleaned.csv"

with open(csv_path, newline='', encoding='utf-8-sig') as csvfile:
    reader = csv.DictReader(csvfile)

    count = 0
    for row in reader:ื่อ
        keyword = row["keyword"].strip()

        # ใช้ keyword เป็น document ID
        doc_ref = db.collection("dreamInt2").document(keyword)

        doc_ref.set({
            "keyword": keyword,
            "interpretation": row["interpretation"].strip(),
            "luckynumber": row["lucky_number"].strip()
        })

        count += 1

print(f"🎉 อัปโหลดข้อมูลใหม่สำเร็จทั้งหมด {count} records")

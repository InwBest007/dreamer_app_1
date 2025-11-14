- สรุป flow ทดสอบหน้าจอ input, result screen

1. ฝั่ง client (แอปมือถือ) ส่ง POST ไปที่ server proxy http://<SERVER_IP>:8000/analyze หรือ /analyze_ai (ไม่มี API key ใน header)

2. Server proxy จะเติม x-api-key ให้เอง และส่งต่อไปยัง upstream (TARGET_SERVER) หรือประมวลผลเอง (ขึ้นกับ config ของคุณ)

3. Server คืนผล (JSON) ให้ client → client แสดงผลใน UI


- การตั้งค่า Flutter client 

1. เปิด DreamInputScreen.dart

2. ตั้ง baseUrl ให้ชี้ไปที่ server ของคุณ ตัวอย่าง:

String baseUrl = "http://192.168.1.10:8000";

3. ไม่ต้อง ส่ง x-api-key ใน headers — proxy จะเติมให้

4. ตรวจสอบ timeout ใน request (โค้ดมี .timeout(const Duration(minutes: 3)) แล้ว — เหมาะสำหรับการทดสอบ)

5. รันแอปบน emulator / มือถือที่เชื่อมเครือข่ายเดียวกับ server


- ตัวอย่างการทดสอบ (curl)

1. Health:

curl -v http://192.168.1.10:8000/health


2. ทดสอบ analyze_ai ผ่าน proxy (client ไม่ต้องส่ง key):

curl -X POST "http://192.168.1.10:8000/analyze_ai" \
  -H "Content-Type: application/json" \
  -d '{"dream":"ฝันว่าตั้งท้องได้ลูกชาย"}'

ถ้า proxy ส่งต่อไปยัง upstream แล้ว upstream ต้องการ x-api-key proxy จะเติมจาก env ให้โดยอัตโนมัติ

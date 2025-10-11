import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import fetch from "node-fetch"; // ✅ นำเข้ากลับมา
import { DocumentSnapshot } from "firebase-admin/firestore";

admin.initializeApp();
const db = admin.firestore();

// 💡 URL ของ Cloud Run Service ที่ใช้ YAMNet 
const CLOUD_RUN_ANALYSIS_URL = "https://dreamer-yamnet-api-616465545953.asia-southeast1.run.app/analyze"; 

/**
 * 🎧 ฟังก์ชันเรียกใช้ Cloud Run API เพื่อเริ่มกระบวนการวิเคราะห์ YAMNet
 */
async function callAnalyzeApi(sessionId: string): Promise<boolean> {
  console.log(`📡 เรียก Cloud Run API สำหรับ Session: ${sessionId}`);
  try {
    const response = await fetch(CLOUD_RUN_ANALYSIS_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sessionId: sessionId }),
    });

    if (response.ok) {
      console.log(`✅ Cloud Run API ตอบกลับสำเร็จ (สถานะ 2xx)`);
      return true;
    } else {
      const errorText = await response.text();
      console.error(`🚨 Cloud Run API Failed: ${response.status} - ${errorText}`);
      
      // ถ้า Cloud Run ล้มเหลว ให้ตั้ง analyzed เป็น True เพื่อไม่ให้ฟังก์ชันนี้ถูกเรียกซ้ำ
      await db.collection("sessions").doc(sessionId).update({"analyzed": true, "error_reason": "Cloud Run call failed"});
      
      return false;
    }
  } catch (error) {
    console.error(`❌ Fetch Error to Cloud Run: ${error}`);
    return false;
  }
}


/**
 * 🔹 (Function 1: Safety Net) Trigger เมื่อ session ถูกสร้าง (type = pending)
 */
export const startAnalysis = functions
  .runWith({ timeoutSeconds: 60, memory: "256MB" }) 
  .region("asia-southeast1")
  .firestore.document("sessions/{sessionId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const sessionId = context.params.sessionId as string;
    
    // ถ้า Flutter App ไม่ได้เรียก Cloud Run สำเร็จ ฟังก์ชันนี้จะเรียกให้
    if (data?.analyzed === false) { 
      await callAnalyzeApi(sessionId);
    }
    return;
  });


/**
 * 🔹 สร้างสรุปข้อมูลของคลิปเสียงทั้งหมดใน session
 * (Logic การรวม Decibel และนับประเภทเสียง)
 */
function buildSummary(records: FirebaseFirestore.QueryDocumentSnapshot[]): any {
  const docs = [...records].sort((a, b) => {
    const ta = (a.get("timestamp")?.toMillis?.() ?? 0);
    const tb = (b.get("timestamp")?.toMillis?.() ?? 0);
    return ta - tb;
  });

  let totalDuration = 0;
  const totalClips = docs.length;
  let peakMaxDb = -Infinity;
  let sumMaxDb = 0;
  let dbCount = 0;

  const typeCounter: Record<string, { count: number; duration: number }> = {};
  const timeline: Array<any> = [];

  for (const d of docs) {
    const duration = Number(d.get("duration") ?? 0);
    const maxDecibel = Number(d.get("maxDecibel") ?? 0);
    const type = String(d.get("type") ?? "pending").toLowerCase();
    
    // คำนวณค่ารวม
    totalDuration += duration;
    if (maxDecibel > peakMaxDb) peakMaxDb = maxDecibel;
    if (maxDecibel > 0) { 
        sumMaxDb += maxDecibel;
        dbCount += 1;
    }

    // นับประเภทเสียง
    if (type !== "pending" && type !== "unknown" && type !== "error_on_analyze") {
        if (!typeCounter[type]) {
            typeCounter[type] = { count: 0, duration: 0 };
        }
        typeCounter[type].count += 1;
        typeCounter[type].duration += duration;
    }

    // เก็บข้อมูลไทม์ไลน์
    timeline.push({
      id: d.id,
      timestamp: d.get("timestamp"),
      duration: duration,
      maxDecibel: maxDecibel,
      type: type,
      url: d.get("filePath"), // ใช้ filePath เป็น URL สำหรับเล่น
    });
  }

  const avgMaxDecibel = dbCount > 0 ? sumMaxDb / dbCount : 0;

  return {
    meta: {
      totalClips: totalClips,
      totalDuration: totalDuration,
      avgMaxDecibel: avgMaxDecibel,
      peakMaxDecibel: peakMaxDb,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      version: 2, 
    },
    types: typeCounter,
    timeline: timeline,
  };
}


/**
 * 🔹 (Function 2) Trigger เมื่อ Cloud Run วิเคราะห์เสร็จ (analyzed: true)
 * ฟังก์ชันนี้มีหน้าที่ "สร้าง Summary"
 */
export const generateSummary = functions
  .runWith({ timeoutSeconds: 60, memory: "1GB" }) 
  .region("asia-southeast1")
  .firestore.document("sessions/{sessionId}")
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    const sessionId = context.params.sessionId as string;

    // 💡 เงื่อนไข Trigger: เมื่อ 'analyzed' เปลี่ยนจากไม่ใช่ True เป็น True
    const analysisJustFinished = before?.analyzed !== true && after?.analyzed === true;

    if (!analysisJustFinished) {
      console.log("⏩ ข้าม: ยังไม่ถึงขั้นตอนการสร้าง Summary");
      return;
    }
    
    console.log(`🧠 Cloud Run วิเคราะห์เสร็จแล้ว, เริ่มสร้าง Summary ให้ Session: ${sessionId}`);

    // 🔍 ดึงข้อมูลเสียงทั้งหมดใน session ที่วิเคราะห์เสร็จแล้ว
    const snap = await db.collection("sound_data")
      .where("sessionId", "==", sessionId)
      .get();

    console.log(`🔍 พบคลิปเสียงทั้งหมด: ${snap.size} ไฟล์`);

    if (snap.empty) {
      console.log("⚠️ ไม่พบเสียงใน session");
    }

    // 🧮 สร้าง summary
    const summary = buildSummary(snap.docs as FirebaseFirestore.QueryDocumentSnapshot[]);

    // ✅ เขียนสรุปกลับไปใน Firestore และเปลี่ยน type เป็น done
    await db.collection("sessions").doc(sessionId).set({
        type: "done", // 💡 เปลี่ยนสถานะเป็น 'done' เพื่อให้ Flutter แสดงผล
        summary: summary,
    }, { merge: true });

    console.log(`✅ Summary ถูกสร้างและอัปเดตสถานะเป็น 'done' สำเร็จ`);
    return;
  });
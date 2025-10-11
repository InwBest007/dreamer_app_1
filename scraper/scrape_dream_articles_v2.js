const puppeteer = require("puppeteer");
const db = require("./firebase");
const axios = require("axios");

// ดึง articleId จาก URL
function extractArticleId(url) {
  const parts = url.split('/');
  return parts[parts.length - 2] || null;
}

// ฟังก์ชัน scroll จอแบบ smooth (แทนการกด End)
async function scrollToLoadMore(page) {
  let previousCount = 0;
  let unchangedCount = 0;
  const maxUnchanged = 5;
  const maxScrollRounds = 65;

  for (let round = 1; round <= maxScrollRounds; round++) {
    // Scroll ลงล่าง
    await page.evaluate(() => {
      window.scrollBy(0, window.innerHeight * 1.5);
    });

    // รอให้ JS ในหน้าเว็บโหลดบทความใหม่
    await new Promise(resolve => setTimeout(resolve, 4000));

    // นับจำนวนบทความในหน้านี้
    const currentCount = await page.evaluate(() =>
      document.querySelectorAll("h3 > span > a").length
    );

    console.log(`🔁 Scroll รอบ ${round}: พบ ${currentCount} บทความ`);

    if (currentCount === previousCount) {
      unchangedCount++;
    } else {
      unchangedCount = 0;
      previousCount = currentCount;
    }

    if (unchangedCount >= maxUnchanged) {
      console.log("🛑 ไม่พบบทความใหม่เกินจำนวนรอบที่กำหนด → หยุด scroll");
      break;
    }
  }

  console.log("✅ Scroll จบแล้ว รวมบทความที่เจอ:", previousCount);
}

// ฟังก์ชันหลัก
async function scrapeDreams() {
  const startAll = Date.now(); // ⏱️ เริ่มจับเวลาโดยรวม

  const browser = await puppeteer.launch({
    headless: true,
    protocolTimeout: 300000,
    defaultViewport: null,
    args: ["--start-maximized"]
  });

  const page = await browser.newPage();

  const thaiAlphabet = 'ฝพฟภมยรลวศษสหฬอฮ';
  const snapshot = await db.collection("dream_articles_v2").get();
  const existingUrls = snapshot.docs.map(doc => doc.data().url); 

  console.log(`🔎 พบ URL ในฐานข้อมูลแล้ว ${existingUrls.length} รายการ`);

  for (const char of thaiAlphabet) {
    const startChar = Date.now(); // ⏱️ เริ่มจับเวลาของหมวดนี้

    const url = `https://www.sanook.com/horoscope/play/dream/alphabet/search/${char}/`;
    console.log(`\n📥 เริ่มดึงบทความหมวด "${char}" → ${url}`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    await scrollToLoadMore(page);

    const links = await page.evaluate(() => {
      const articles = [];
      document.querySelectorAll("h3 > span > a").forEach(el => {
        const title = el.innerText.trim();
        const url = el.href;
        if (title && url) {
          articles.push({ title, url });
        }
      });
      return articles;
    });

    console.log(`📌 พบทั้งหมด ${links.length} เรื่องในหมวด "${char}"`);

    for (const item of links) {
      if (existingUrls.includes(item.url)) {
        console.log(`⏭ ข้าม: ${item.title}`);
        continue;
      }

      try {
        const detailPage = await browser.newPage();
        await detailPage.goto(item.url, { waitUntil: "domcontentloaded" });

        const detail = await detailPage.evaluate(() => {
          const el1 = document.querySelector("#EntryReader_0");
          const el2 = document.querySelector(".detail");
          const content = el1?.innerText || el2?.innerText || "";

          const img = document.querySelector(".thumbnail img")?.src || "";
          return { content, imgUrl: img };
        });

        await detailPage.close();

        const articleId = extractArticleId(item.url);
        const desc = detail.content?.substring(0, 100) || "";

        await db.collection("dream_articles_v2").add({
          title: item.title,
          url: item.url,
          description: desc,
          content: detail.content || "",
          imagePath: detail.imgUrl || "",
          category: char,
          source: "sanook",
          createdAt: new Date()
        });

        console.log(`✅ บันทึก: ${item.title}`);
      } catch (err) {
        console.error(`❌ ERROR: ${item.url}`, err.message);
      }
    }

    const durationChar = ((Date.now() - startChar) / 1000).toFixed(2);
    console.log(`⏱️ ใช้เวลาดึงหมวด "${char}": ${durationChar} วินาที`);
  }

  await browser.close();

  const durationAll = ((Date.now() - startAll) / 1000).toFixed(2);
  console.log(`\n🎉 เสร็จสิ้น! ใช้เวลาทั้งหมด: ${durationAll} วินาที`);
}

scrapeDreams();

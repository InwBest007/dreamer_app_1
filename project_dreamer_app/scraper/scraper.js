const puppeteer = require("puppeteer");
const db = require("./firebase");
const axios = require("axios");
const fs = require("fs");

//สร้าง articleId จาก URL
function extractArticleId(url) {
    const parts = url.split('/');
    return parts[parts.length - 2] || null;
}

//ฟังก์ชันเลื่อนแบบกด End
async function scrollWithEndKey(page) {
    function delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    let lastCount = 0;
    let unchangedCount = 0;
    const maxUnchangedAttempts = 7;

    while (unchangedCount < maxUnchangedAttempts) {
        await page.keyboard.press("End");
        console.log("กด End ...");

        await delay(8000); // รอ 5 วิ ให้เว็บโหลดบทความใหม่

        const currentCount = await page.evaluate(() =>
            document.querySelectorAll("article.PostListWithDetail").length
        );

        console.log(`เจอบทความ ${currentCount} เรื่อง (ก่อนหน้านี้ ${lastCount})`);

        if (currentCount === lastCount) {
            unchangedCount++;
            console.log(`❌ ไม่มีบทความใหม่ (ครั้งที่ ${unchangedCount})`);
        } else {
            unchangedCount = 0;
            lastCount = currentCount;
            console.log("✅ โหลดบทความเพิ่มแล้ว");
        }
    }

    console.log("📌 ไม่เจอบทความใหม่ 5 รอบติดกัน → หยุดเลื่อน");
}

async function scrapeDreams() {
    const browser = await puppeteer.launch({
        headless: true,
        protocolTimeout: 300000,
        defaultViewport: null,
        args: ["--start-maximized"]
    });
    const page = await browser.newPage();

    // ✅ โหลดข้อมูลที่มีอยู่แล้วใน Firebase
    const snapshot = await db.collection("dream_articles").get();
    const existingUrls = snapshot.docs.map(doc => doc.data().url);
    console.log(`พบ ${existingUrls.length} ลิงก์ที่มีอยู่ในฐานข้อมูลแล้ว`);

    const thaiAlphabet = 'กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ';

    for (const char of thaiAlphabet) {
        console.log(`\n--- เริ่มดึงหมวด "${char}" ---`);
        const url = `https://www.sanook.com/horoscope/play/dream/alphabet/search/${char}/`;
        await page.goto(url, { waitUntil: "domcontentloaded" });

        await scrollWithEndKey(page);

        // ✅ ดึงลิสต์บทความ
        const links = await page.evaluate(() => {
            let items = [];
            document.querySelectorAll("h3 > span > a").forEach(el => {
                let title = el.innerText.trim();
                let url = el.href;
                if (title && url) items.push({ title, url });
            });
            return items;
        });

        console.log(`📌 เจอบทความทั้งหมด ${links.length} เรื่องในหมวด "${char}"`);

        const imgDir = "./dream_article_images";
        if (!fs.existsSync(imgDir)) {
            fs.mkdirSync(imgDir);
        }

        // ✅ วนเก็บรายละเอียดบทความ
        for (let item of links) {
            if (existingUrls.includes(item.url)) {
                console.log(`⏩ ข้าม "${item.title}" (มีแล้ว)`);
                continue;
            }

            try {
                const detailPage = await browser.newPage();
                await detailPage.goto(item.url, { waitUntil: "domcontentloaded" });

                const detail = await detailPage.evaluate(() => {
                    let desc = document.querySelector(".detail")?.innerText || "";
                    let imgUrl = document.querySelector(".thumbnail img")?.src || "";
                    return { desc, imgUrl };
                });

                let savedImgPath = "";
                const articleId = extractArticleId(item.url);

                if (detail.imgUrl && articleId) {
                    const filename = `${articleId}.jpg`;
                    savedImgPath = `${imgDir}/${filename}`;

                    const response = await axios({
                        url: detail.imgUrl.startsWith("http") ? detail.imgUrl : "https:" + detail.imgUrl,
                        responseType: "stream",
                    });
                    response.data.pipe(fs.createWriteStream(savedImgPath));

                    console.log(`✅ ดาวน์โหลดรูป ID "${articleId}" สำเร็จ`);
                }

                await db.collection("dream_articles").add({
                    title: item.title,
                    url: item.url,
                    description: detail.desc,
                    imagePath: savedImgPath,
                    category: char,
                    source: "sanook",
                    createdAt: new Date()
                });

                console.log(`📌 บันทึก "${item.title}" แล้ว`);
                await detailPage.close();
            } catch (err) {
                console.error("❌ Error scraping", item.url, err);
            }
        }
    }

    await browser.close();
    console.log("\n🎉 เก็บข้อมูลครบทุกหมวดแล้ว");
}

scrapeDreams();

const { chromium } = require("playwright");
const path = require("path");

const ok = (label) => console.log("  ✓ " + label);
function assert(cond, msg) { if (!cond) throw new Error("ASSERT FAILED: " + msg); }

(async () => {
  const browser = await chromium.launch({
    executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    args: ["--no-sandbox"],
  });
  const page = await browser.newPage({ viewport: { width: 412, height: 869 }, deviceScaleFactor: 2 });

  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));

  await page.goto("file://" + path.join(__dirname, "index.html"));
  await page.waitForTimeout(400);

  const snap = () => page.evaluate(() => window.__game.snap());

  // ---------- 1. pornire ----------
  console.log("\n[1] Pornire");
  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(250);
  let s = await snap();
  assert(s.state === "play", "state=play, got " + s.state);
  assert(s.room === 1, "room=1, got " + s.room);
  assert(s.enemies > 0, "camera 1 trebuie sa aiba inamici, got " + s.enemies);
  ok(`state=play, camera 1, ${s.enemies} inamici`);

  // ---------- 2. MECANICA CHEIE: nu trage in miscare ----------
  console.log("\n[2] Regula Archero: miscare => fara tragere");
  // golim orice proiectil existent lasand jucatorul sa stea, apoi ne miscam continuu
  await page.keyboard.down("a");
  await page.waitForTimeout(150); // lasam proiectilele vechi sa dispara
  let firedWhileMoving = 0;
  for (let i = 0; i < 14; i++) {
    await page.waitForTimeout(90);
    const st = await snap();
    firedWhileMoving = Math.max(firedWhileMoving, st.pBullets);
  }
  await page.keyboard.up("a");
  assert(firedWhileMoving === 0, `nu trebuie sa existe proiectile in miscare, dar am vazut ${firedWhileMoving}`);
  ok("0 proiectile emise pe toata durata miscarii (1.4s)");

  // ---------- 3. oprire => trage automat ----------
  console.log("\n[3] Oprire => tragere automata pe cel mai apropiat");
  let firedAfterStop = 0;
  for (let i = 0; i < 12; i++) {
    await page.waitForTimeout(100);
    const st = await snap();
    firedAfterStop = Math.max(firedAfterStop, st.pBullets);
    if (firedAfterStop > 0) break;
  }
  assert(firedAfterStop > 0, "dupa oprire trebuie sa apara proiectile");
  ok(`proiectile emise dupa oprire: ${firedAfterStop}`);

  // ---------- 4. miscarea chiar deplaseaza jucatorul ----------
  console.log("\n[4] Miscare pe taste");
  const before = await snap();
  await page.keyboard.down("d");
  await page.waitForTimeout(500);
  await page.keyboard.up("d");
  const after = await snap();
  assert(after.px > before.px, `x trebuie sa creasca spre dreapta: ${before.px} -> ${after.px}`);
  ok(`jucatorul s-a deplasat: x ${before.px} -> ${after.px}`);

  // ---------- 5. kills => XP => level up cu 3 carti ----------
  console.log("\n[5] Level-up cu 3 carti");
  await page.evaluate(() => window.__game.clearRoom());
  await page.waitForTimeout(120);
  await page.evaluate(() => window.__game.collectOrbs());
  await page.waitForTimeout(250);
  s = await snap();
  assert(s.state === "level", "trebuie sa se deschida ecranul de level-up, state=" + s.state);
  const cards = await page.locator("#cards .card").count();
  assert(cards === 3, "3 carti, got " + cards);
  ok(`level-up afisat, ${cards} carti, nivel ${s.level}`);

  await page.screenshot({ path: path.join(__dirname, "shot_levelup.png") });
  await page.locator("#cards .card").first().click();
  await page.waitForTimeout(200);
  s = await snap();
  assert(s.state === "play", "dupa alegere revine la joc, state=" + s.state);
  ok("putere aplicata, jocul continua");

  // ---------- 6. camera curatata => usa deschisa ----------
  console.log("\n[6] Usa se deschide cand camera e goala");
  await page.evaluate(() => window.__game.dropEnemies());
  await page.waitForTimeout(250);
  s = await snap();
  assert(s.doorOpen === true, "usa trebuie sa fie deschisa");
  ok("usa deschisa dupa curatarea camerei");

  await page.screenshot({ path: path.join(__dirname, "shot_door.png") });

  // ---------- 7. trecere prin usa => camera noua ----------
  console.log("\n[7] Trecerea prin usa genereaza camera urmatoare");
  const roomBefore = s.room;
  await page.evaluate(() => window.__game.setPos(225, 140));
  await page.keyboard.down("w");
  await page.waitForTimeout(700);
  await page.keyboard.up("w");
  await page.waitForTimeout(250);
  s = await snap();
  assert(s.room === roomBefore + 1, `camera ${roomBefore} -> ${roomBefore + 1}, got ${s.room}`);
  assert(s.enemies > 0, "camera noua trebuie sa aiba inamici, got " + s.enemies);
  assert(s.doorOpen === false, "usa trebuie sa fie inchisa in camera noua");
  ok(`camera ${roomBefore} -> ${s.room}, ${s.enemies} inamici noi, usa inchisa`);

  // ---------- 8. dauna si game over ----------
  console.log("\n[8] Moarte => ecran final");
  await page.evaluate(() => window.__game.hurt(9999));
  await page.waitForTimeout(300);
  s = await snap();
  assert(s.state === "over", "state=over, got " + s.state);
  const overVisible = await page.locator("#overOverlay").isVisible();
  assert(overVisible, "ecranul de final trebuie sa fie vizibil");
  ok("ecran de final afisat");

  // ---------- 9. restart ----------
  console.log("\n[9] Restart");
  await page.locator("#retryBtn").click();
  await page.waitForTimeout(300);
  s = await snap();
  assert(s.state === "play" && s.room === 1 && s.hp === s.maxHp, "restart curat, got " + JSON.stringify(s));
  ok("restart la camera 1, viata plina");

  // ---------- 10. gameplay live pentru captura ----------
  console.log("\n[10] Captura de gameplay");
  await page.waitForTimeout(1400);
  await page.screenshot({ path: path.join(__dirname, "shot_play.png") });
  ok("captura salvata");

  const real = errors.filter((e) => !/ERR_CONNECTION_RESET|net::ERR|fonts\.googleapis/.test(e));
  if (real.length) { console.log("\nERORI:", real); throw new Error("erori in consola: " + real.join(" | ")); }

  console.log("\n=== TOATE TESTELE AU TRECUT ===\n");
  await browser.close();
})().catch((e) => { console.error("\nTEST FAILED:", e.message); process.exit(1); });

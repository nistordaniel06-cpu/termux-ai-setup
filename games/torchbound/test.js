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

  await page.goto("file://" + path.join(__dirname, "www", "index.html"));
  await page.waitForTimeout(400);

  const snap = () => page.evaluate(() => window.__game.snap());
  // pornim de la un profil curat, ca testele sa nu depinda de rulari anterioare
  await page.evaluate(() => window.__game.wipeMeta());

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
  console.log("\n[2] Regula Archero: miscare => fara tragere (mod clasic)");
  await page.evaluate(() => window.__game.setMode("clasic"));
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

  // ---------- 3b. modurile de tragere ----------
  console.log("\n[3b] Mod HIBRID: apasarea trage din mers, cu dauna redusa");
  await page.evaluate(() => window.__game.setMode("hibrid"));
  await page.keyboard.down("a");
  await page.waitForTimeout(220);
  // fara apasare nu trebuie sa iasa niciun foc, desi ne miscam
  let idleWhileMoving = 0;
  for (let i = 0; i < 6; i++) { await page.waitForTimeout(90); idleWhileMoving = Math.max(idleWhileMoving, (await snap()).pBullets); }
  assert(idleWhileMoving === 0, `hibrid fara apasare nu trage, dar am vazut ${idleWhileMoving}`);
  ok("in mers, fara apasare: 0 focuri");

  // citim rezultatul in aceeasi evaluare, altfel proiectilul poate lovi un
  // inamic apropiat inainte de urmatorul snapshot si dispare din lista
  const shot = await page.evaluate(() => {
    const fired = window.__game.tapFire();
    const s = window.__game.snap();
    return { fired, dmg: s.lastDmg, weak: s.lastWeak, base: s.baseDmg, count: s.pBullets };
  });
  await page.keyboard.up("a");
  assert(shot.fired === true && shot.count > 0, "apasarea in mers trebuie sa traga");
  assert(shot.weak === true, "focul din mers trebuie marcat ca slabit");
  const expected = shot.base * 0.6;
  assert(Math.abs(shot.dmg - expected) < 0.01, `dauna din mers ${shot.dmg} trebuie sa fie 60% din ${shot.base} (=${expected})`);
  ok(`apasare in mers => ${shot.dmg} dauna, exact 60% din ${shot.base} de pe loc`);

  // apasatul repetat trebuie sa fie limitat de racire, nu infinit
  const spam = await page.evaluate(() => {
    let fired = 0;
    for (let i = 0; i < 10; i++) if (window.__game.tapFire()) fired++;
    return fired;
  });
  assert(spam === 0, `apasarea imediat repetata e blocata de racire, dar au trecut ${spam} focuri`);
  ok("apasatul repetat e limitat de racire (fara damage infinit)");

  console.log("\n[3c] Mod LIBER: trage automat si in mers");
  await page.evaluate(() => window.__game.setMode("liber"));
  await page.keyboard.down("a");
  let freeFired = 0;
  for (let i = 0; i < 10; i++) { await page.waitForTimeout(100); freeFired = Math.max(freeFired, (await snap()).pBullets); }
  await page.keyboard.up("a");
  assert(freeFired > 0, "modul liber trebuie sa traga si in miscare");
  ok(`in mers, automat: ${freeFired} focuri`);

  await page.evaluate(() => window.__game.setMode("hibrid"));

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

  // ---------- 11. progres permanent ----------
  console.log("\n[11] Cioburi, tabără și deblocări");
  await page.evaluate(() => window.__game.wipeMeta());
  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(200);

  // curatam doua camere si verificam ca se aduna cioburi si progres
  for (let r = 0; r < 2; r++) {
    await page.evaluate(() => window.__game.dropEnemies());
    await page.waitForTimeout(160);
    await page.evaluate(() => window.__game.setPos(225, 140));
    await page.keyboard.down("w");
    await page.waitForTimeout(600);
    await page.keyboard.up("w");
    await page.waitForTimeout(200);
  }
  s = await snap();
  assert(s.runShards > 0, "curatarea camerelor trebuie sa dea cioburi, got " + s.runShards);
  assert(s.totalRooms === 2, "doua camere curatate trebuie contorizate, got " + s.totalRooms);
  ok(`${s.runShards} cioburi in rundă, ${s.totalRooms} camere la total`);

  // la moarte cioburile intra in punga, cu bonusul de mod
  await page.evaluate(() => window.__game.setMode("clasic"));
  const beforeDeath = await snap();
  await page.evaluate(() => window.__game.hurt(9999));
  await page.waitForTimeout(300);
  s = await snap();
  const expectedShards = Math.round(beforeDeath.runShards * 1.25);
  assert(s.shards === expectedShards, `punga trebuie sa creasca cu ${expectedShards} (bonus clasic +25%), got ${s.shards}`);
  ok(`la moarte: +${s.shards} cioburi în pungă (bonus clasic aplicat)`);

  // deblocarile: ricoseul e blocat la inceput, apare dupa 8 camere
  await page.evaluate(() => window.__game.setTotalRooms(0));
  let locked = await page.evaluate(() => window.__game.unlocked("ricochet"));
  assert(locked === false, "ricoseul trebuie sa fie blocat la 0 camere");
  await page.evaluate(() => window.__game.setTotalRooms(8));
  let unlocked = await page.evaluate(() => window.__game.unlocked("ricochet"));
  assert(unlocked === true, "ricoseul trebuie deblocat la 8 camere");
  ok("deblocare: Ricoșeu blocat la 0 camere, deschis la 8");

  // cumparaturile din tabara se aplica pe eroul urmatoarei runde
  await page.evaluate(() => window.__game.grantShards(500));
  await page.evaluate(() => window.__game.openCamp("start"));
  await page.waitForTimeout(150);
  await page.screenshot({ path: path.join(__dirname, "shot_camp.png") });

  const purseBefore = (await snap()).shards;
  await page.locator("#shop .buy").first().click();   // Vigoare: +12 viață
  await page.waitForTimeout(150);
  s = await snap();
  assert(s.shards < purseBefore, `cumparatura trebuie sa scada punga: ${purseBefore} -> ${s.shards}`);
  ok(`cumpărat din tabără: ${purseBefore} -> ${s.shards} cioburi`);

  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(200);
  s = await snap();
  assert(s.maxHp === 112, `Vigoare trebuie sa dea 112 viață maximă, got ${s.maxHp}`);
  ok(`upgrade-ul se aplică pe runda următoare: ${s.maxHp} viață maximă`);

  // ---------- 12. camera de gardian ----------
  console.log("\n[12] Camera de gardian, la fiecare 5 camere");
  await page.evaluate(() => window.__game.buildRoomAt(5));
  await page.waitForTimeout(150);
  s = await snap();
  assert(s.enemies === 1, `camera de gardian trebuie sa aiba un singur inamic, got ${s.enemies}`);
  assert(s.enemyType === "boss", `inamicul trebuie sa fie de tip boss, got ${s.enemyType}`);
  ok("camera 5: un singur gardian pe hartă");

  await page.screenshot({ path: path.join(__dirname, "shot_boss.png") });

  const purseBeforeBoss = (await snap()).runShards;
  await page.evaluate(() => window.__game.clearRoom());
  await page.waitForTimeout(150);
  s = await snap();
  assert(s.runShards > purseBeforeBoss + 20, `moartea gardianului trebuie sa dea un bonus mare de cioburi, got ${s.runShards - purseBeforeBoss}`);
  ok(`gardian învins: +${s.runShards - purseBeforeBoss} cioburi în rundă (bonus de boss aplicat)`);

  const real = errors.filter((e) => !/ERR_CONNECTION_RESET|net::ERR|fonts\.googleapis/.test(e));
  if (real.length) { console.log("\nERORI:", real); throw new Error("erori in consola: " + real.join(" | ")); }

  console.log("\n=== TOATE TESTELE AU TRECUT ===\n");
  await browser.close();
})().catch((e) => { console.error("\nTEST FAILED:", e.message); process.exit(1); });

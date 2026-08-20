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
  // golim orice proiectil existent (start()-ul poate fi tras deja o data cat
  // jucatorul statea pe loc), apoi ne miscam continuu
  await page.evaluate(() => window.__game.clearBullets());
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
  // Ranger porneste cu tir dublu - unul poate rata tinta lovita de celalalt
  // si ramane in zbor, asa ca golim explicit inainte de verificarea de mai jos
  await page.evaluate(() => window.__game.clearBullets());
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

  // ---------- 13. sunet ----------
  console.log("\n[13] Comutator de sunet");
  const mutedBefore = await page.locator("#muteBtn").getAttribute("aria-pressed");
  assert(mutedBefore === "false", `sunetul trebuie sa fie pornit implicit, got ${mutedBefore}`);
  await page.locator("#muteBtn").click();
  const mutedAfter = await page.locator("#muteBtn").getAttribute("aria-pressed");
  assert(mutedAfter === "true", "click-ul trebuie sa opreasca sunetul");
  ok("comutatorul de sunet schimba starea la click");
  await page.locator("#muteBtn").click();   // il lasam pornit pentru restul rularii

  // ---------- 14. clase de erou ----------
  console.log("\n[14] Clase de erou");
  await page.evaluate(() => window.__game.wipeMeta());

  // Ranger e clasa implicita si trebuie sa ramana neschimbata numeric
  // (fara multiplicator), ca sa nu strice testele care presupun statisticile
  // de baza - diferenta lui vine din tirul dublu din start.
  s = await snap();
  assert(s.classId === "ranger", `clasa implicita trebuie sa fie ranger, got ${s.classId}`);
  assert(s.projCount === 2, `Ranger trebuie sa porneasca cu tir dublu, got ${s.projCount}`);
  ok(`Ranger implicit, tir dublu din start (projCount=${s.projCount})`);

  // Knight: viata multiplicata si atac corp la corp, fara proiectile.
  // Clasa nu mai e un comutator live - e fixata la crearea profilului, deci
  // testam prin sloturi separate, exact ca fluxul real.
  await page.evaluate(() => window.__game.createProfile(2, "Testerul", "knight"));
  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(200);
  s = await snap();
  assert(s.classId === "knight", `clasa trebuie sa fie knight, got ${s.classId}`);
  assert(s.maxHp === 155, `Knight trebuie sa aiba 155 viață maximă (100 × 1.55), got ${s.maxHp}`);
  assert(s.meleeRange > 0, "Knight trebuie sa aiba raza de atac corp la corp > 0");
  ok(`Knight: ${s.maxHp} viață maximă, atac corp la corp (rază ${s.meleeRange})`);

  // citim poziția și teleportăm în aceeași evaluare - altfel inamicul (care
  // urmărește jucătorul) se poate deplasa în intervalul dintre cele doua
  // evaluate()-uri separate, scoțându-l ocazional din raza de atac
  const nearest1 = await page.evaluate(() => {
    const e = window.__game.nearestEnemyPos();
    if (e) window.__game.setPos(e.x, e.y - 20);
    return e;
  });
  await page.waitForTimeout(700);
  const nearest2 = await page.evaluate(() => window.__game.nearestEnemyPos());
  s = await snap();
  assert(s.pBullets === 0, `Knight nu trebuie sa traga proiectile, got ${s.pBullets}`);
  assert(s.kills > 0 || nearest2.hp < nearest1.hp, "atacul corp la corp trebuie sa loveasca inamicul apropiat");
  ok("Knight lovește corp la corp în arc, fără proiectile");

  // Mage: ardere garantata din start, proiectile marcate distinct (violet)
  await page.evaluate(() => window.__game.createProfile(3, "Vraciul", "mage"));
  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(200);
  s = await snap();
  assert(s.classId === "mage", `clasa trebuie sa fie mage, got ${s.classId}`);
  assert(s.burn > 0, `Mage trebuie sa aiba ardere garantata din start, got ${s.burn}`);

  // interogam repetat, nu o singura data dupa o asteptare fixa - proiectilul
  // poate lovi tinta si disparea chiar in intervalul dintre verificari
  let mageBulletCls = null;
  for (let i = 0; i < 12; i++) {
    await page.waitForTimeout(80);
    const st = await snap();
    if (st.bulletCls) { mageBulletCls = st.bulletCls; break; }
  }
  assert(mageBulletCls === "mage", `proiectilele Mage trebuie marcate distinct, got ${mageBulletCls}`);
  ok(`Mage: ardere ${s.burn}/s din start, proiectile marcate corect`);

  await page.evaluate(() => window.__game.loadSlot(1));   // revenim la profilul implicit (Ranger)

  // ---------- 15. sloturi de salvare (profile izolate) ----------
  console.log("\n[15] Sloturi de salvare (profile izolate)");
  await page.evaluate(() => window.__game.wipeAllSlots());
  let sum = await page.evaluate(() => [1, 2, 3].map((n) => window.__game.slotSummary(n)));
  assert(sum.every((x) => x === null), "toate cele 3 sloturi trebuie sa fie goale dupa wipeAllSlots");
  ok("cele 3 sloturi pornesc goale");

  await page.evaluate(() => window.__game.openProfiles());
  await page.waitForTimeout(150);
  const slotCardCount = await page.locator("#slotList .slotCard").count();
  assert(slotCardCount === 3, `trebuie sa existe 3 carduri de slot, got ${slotCardCount}`);
  const emptyTexts = await page.locator("#slotList .slotCard .slotInfo").allTextContents();
  assert(emptyTexts.every((t) => t.includes("Niciun profil")), "sloturile goale trebuie sa afiseze 'Niciun profil salvat aici'");
  ok("ecranul de sloturi arata 3 sloturi goale, fiecare cu Profil Nou");

  // cream un profil prin ecranul real: clic pe "Profil Nou" al primului slot
  await page.locator("#slotList .slotCard").nth(0).locator("button").click();
  await page.waitForTimeout(150);
  assert(await page.locator("#createOverlay").isVisible(), "trebuie sa se deschida ecranul de creare profil");

  await page.fill("#nameInput", "Arthas");
  await page.locator('#createClasses .mode[data-class="knight"]').click();
  await page.locator("#createConfirmBtn").click();
  await page.waitForTimeout(150);

  assert(await page.locator("#startOverlay").isVisible(), "dupa creare trebuie sa ajungem in hub");
  const hubName = await page.locator("#hubName").textContent();
  const hubClass = await page.locator("#hubClass").textContent();
  assert(hubName === "Arthas", `numele afisat in hub trebuie sa fie Arthas, got ${hubName}`);
  assert(hubClass === "Knight", `clasa afisata in hub trebuie sa fie Knight, got ${hubClass}`);
  ok(`profil creat prin ecranul real: ${hubName} (${hubClass})`);

  sum = await page.evaluate(() => [1, 2, 3].map((n) => window.__game.slotSummary(n)));
  assert(sum[0] && sum[0].name === "Arthas" && sum[0].classId === "knight", "slotul 1 trebuie sa aiba profilul Arthas/knight");
  assert(sum[1] === null && sum[2] === null, "sloturile 2 si 3 trebuie sa ramana neatinse");
  ok("progresul e izolat: doar slotul 1 are date");

  // izolare intre profile: un profil nou nu vede cioburile altuia
  await page.evaluate(() => window.__game.start());
  await page.evaluate(() => window.__game.grantShards(150));
  const s1shards = (await page.evaluate(() => window.__game.snap())).shards;
  await page.evaluate(() => window.__game.createProfile(2, "Jaina", "mage"));
  const s2shards = (await page.evaluate(() => window.__game.snap())).shards;
  assert(s2shards === 0, `profilul nou din slotul 2 trebuie sa porneasca cu 0 cioburi, got ${s2shards}`);
  ok(`izolare confirmata: slotul 1 avea ${s1shards} cioburi, slotul 2 nou porneste cu ${s2shards}`);

  await page.evaluate(() => window.__game.loadSlot(1));
  const s1again = (await page.evaluate(() => window.__game.snap())).shards;
  assert(s1again === s1shards, `la reincarcarea slotului 1, cioburile trebuie pastrate: asteptam ${s1shards}, got ${s1again}`);
  ok("la revenirea in slot, progresul persista neschimbat");

  // stergerea unui profil, cu confirmare nativa
  page.once("dialog", (d) => d.accept());
  await page.evaluate(() => window.__game.openProfiles());
  await page.waitForTimeout(120);
  await page.locator("#slotList .slotCard").nth(0).locator('[data-act="wipe"]').click();
  await page.waitForTimeout(150);
  const afterWipe = await page.evaluate(() => window.__game.slotSummary(1));
  assert(afterWipe === null, "dupa stergere, slotul 1 trebuie sa redevina gol");
  ok("stergerea unui profil functioneaza (cu confirmare)");

  // ---------- 16. echipament (8 sloturi, recalculare dinamica) ----------
  console.log("\n[16] Echipament (8 sloturi, recalculare dinamica)");
  await page.evaluate(() => window.__game.wipeAllSlots());
  await page.evaluate(() => window.__game.createProfile(1, "Tester", "ranger"));
  await page.evaluate(() => window.__game.grantShards(1000));

  const eqBefore = await page.evaluate(() => window.__game.equipStats());
  assert(eqBefore.atk === 0 && eqBefore.hp === 0 && eqBefore.def === 0, "fara echipament, bonusurile trebuie sa fie 0");

  const bought = await page.evaluate(() => window.__game.buyItem("helm1"));
  assert(bought === true, "cumpararea coifului trebuie sa reuseasca cu fonduri suficiente");
  const eqAfter = await page.evaluate(() => window.__game.equipStats());
  assert(eqAfter.hp === 10 && eqAfter.def === 1, `coiful trebuie sa dea +10 HP/+1 DEF, got ${JSON.stringify(eqAfter)}`);
  ok(`cumparat si echipat prin hook: +${eqAfter.hp} HP, +${eqAfter.def} DEF`);

  await page.evaluate(() => window.__game.openEquip());
  await page.waitForTimeout(120);
  const eqHpTxt = await page.locator("#eqHp").textContent();
  assert(eqHpTxt === "+10", `ecranul de echipament trebuie sa arate +10 HP, got ${eqHpTxt}`);
  ok("ecranul de echipament reflecta totalul corect");

  await page.evaluate(() => window.__game.start());
  s = await snap();
  assert(s.maxHp === 110, `100 baza + 10 din coif = 110 viata maxima, got ${s.maxHp}`);
  ok(`statisticile eroului recalculate dinamic: ${s.maxHp} viață maximă`);

  await page.evaluate(() => window.__game.unequip("helm"));
  const eqUnequipped = await page.evaluate(() => window.__game.equipStats());
  assert(eqUnequipped.hp === 0, "dupa dezechipare, bonusul trebuie sa dispara");
  ok("dezechiparea elimina bonusul");

  // cumparare directa din ecran (nu prin hook), ca sa validam intreg fluxul de clic
  await page.evaluate(() => window.__game.openEquip());
  await page.waitForTimeout(120);
  await page.locator('#equipList .equipGroup:has-text("Papuci") .buy').first().click();
  await page.waitForTimeout(120);
  const eqHpTxt2 = await page.locator("#eqHp").textContent();
  assert(eqHpTxt2 === "+6", `dupa cumpararea cizmelor de piele din ecran, +6 HP, got ${eqHpTxt2}`);
  ok("cumpararea unui obiect direct din ecranul de Inventar functioneaza");

  // ---------- 17. talente permanente (deblocare pe ramuri) ----------
  console.log("\n[17] Talente permanente (deblocare pe ramuri)");
  await page.evaluate(() => window.__game.wipeAllSlots());
  await page.evaluate(() => window.__game.createProfile(1, "Tester", "ranger"));
  await page.evaluate(() => window.__game.grantShards(2000));

  let lockedBuy = await page.evaluate(() => window.__game.buyTalent("resist"));
  assert(lockedBuy === false, "Rezistență trebuie sa fie blocata inainte de Putere Atac");
  ok("Rezistență blocata fara Putere Atac");

  const boughtPower = await page.evaluate(() => window.__game.buyTalent("atkPower"));
  assert(boughtPower === true, "Putere Atac trebuie sa se cumpere");
  const unlockedBuy = await page.evaluate(() => window.__game.buyTalent("resist"));
  assert(unlockedBuy === true, "Rezistență trebuie deblocata dupa un nivel de Putere Atac");
  ok("Putere Atac deblochează Rezistență și Sănătate Maximă");

  const critLocked = await page.evaluate(() => window.__game.buyTalent("critChance"));
  assert(critLocked === false, "Șansă Critică trebuie blocata fara Viteza Atac");
  await page.evaluate(() => window.__game.buyTalent("atkSpeed"));
  const critUnlocked = await page.evaluate(() => window.__game.buyTalent("critChance"));
  assert(critUnlocked === true, "Șansă Critică trebuie deblocata dupa Viteza Atac");
  ok("Viteză Atac deblochează Șansă Critică");

  await page.evaluate(() => window.__game.start());
  s = await snap();
  assert(s.critChance > 0, `sansa critica trebuie aplicata pe erou, got ${s.critChance}`);
  assert(s.armor > 0, `armura din Rezistență trebuie aplicata pe erou, got ${s.armor}`);
  ok(`talentele se aplică pe erou: armură ${s.armor}, șansă critică ${(s.critChance * 100).toFixed(0)}%`);

  await page.evaluate(() => window.__game.openTalents());
  await page.waitForTimeout(120);
  const talentRows = await page.locator("#talentList .buy").count();
  assert(talentRows === 5, `trebuie sa existe 5 talente afisate, got ${talentRows}`);
  ok("ecranul de talente afiseaza toate cele 5 talente");

  // ---------- 18. selectia hartii (4 locatii, dificultate) ----------
  console.log("\n[18] Selecția hărții (4 locații, dificultate)");
  await page.evaluate(() => window.__game.wipeAllSlots());
  await page.evaluate(() => window.__game.createProfile(1, "Tester", "ranger"));

  s = await snap();
  assert(s.mapId === "forest", `harta implicita trebuie sa fie forest, got ${s.mapId}`);

  await page.evaluate(() => window.__game.openMaps());
  await page.waitForTimeout(120);
  const mapCardCount = await page.locator("#mapList .mapCard").count();
  assert(mapCardCount === 4, `trebuie sa existe 4 harti, got ${mapCardCount}`);
  ok("ecranul de hărți afișează toate cele 4 tărâmuri");

  await page.locator('#mapList .mapCard:has-text("Tărâmul Umbrelor")').click();
  await page.waitForTimeout(120);
  s = await snap();
  assert(s.mapId === "shadow", `dupa selectie, harta activa trebuie sa fie shadow, got ${s.mapId}`);
  ok("selecția hărții direct din ecran funcționează");

  // dificultatea afecteaza inamicii - camera 1 e mereu "melee", deci comparatia e directa
  await page.evaluate(() => window.__game.setMap("forest"));
  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(150);
  const forestHp = (await page.evaluate(() => window.__game.nearestEnemyPos())).maxHp;

  await page.evaluate(() => window.__game.setMap("shadow"));
  await page.evaluate(() => window.__game.start());
  await page.waitForTimeout(150);
  const shadowHp = (await page.evaluate(() => window.__game.nearestEnemyPos())).maxHp;

  assert(shadowHp > forestHp, `Tărâmul Umbrelor (×1.5) trebuie sa aiba inamici mai puternici decat Pădurea (×1.0): ${shadowHp} vs ${forestHp}`);
  ok(`dificultatea scalează inamicii: Pădure ${Math.round(forestHp)} HP vs Tărâmul Umbrelor ${Math.round(shadowHp)} HP`);

  const real = errors.filter((e) => !/ERR_CONNECTION_RESET|net::ERR|fonts\.googleapis/.test(e));
  if (real.length) { console.log("\nERORI:", real); throw new Error("erori in consola: " + real.join(" | ")); }

  console.log("\n=== TOATE TESTELE AU TRECUT ===\n");
  await browser.close();
})().catch((e) => { console.error("\nTEST FAILED:", e.message); process.exit(1); });

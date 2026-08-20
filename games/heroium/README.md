# Heroium

Action-roguelike top-down în stil Archero, într-o lume medievală întunecată.
Proiect Godot 4, orientat vertical (720×1280), gândit pentru telefon.

> **Luptă. Adună. Evoluează. Devino legendar.**

## Regula centrală

Te **miști** sau **ataci**, niciodată amândouă. Când ridici degetul de pe joystick,
eroul se oprește, își caută singur cea mai apropiată țintă și trage. Mișcarea e
deci mereu o alegere: eviți lovituri, dar renunți la daună.

Inelul din jurul eroului spune asta fără cuvinte: aprins înseamnă că stai și faci
daună, stins că te miști și nu faci. Regula trăiește într-un singur loc —
`hero.gd` decide, `hero_combat.gd` doar execută.

## Bucla de joc

1. Intri într-o cameră. Inamicii apar la distanță de tine, niciodată în față.
2. Îi cureți. Fiecare lasă un ciob de experiență, care vine singur spre tine.
3. La fiecare nivel primești **trei cărți** și alegi una.
4. Ultima cameră a locației e a **șefului**. După el, locația următoare.
5. Când cazi, rularea se pierde — dar monedele nu. Le cheltui în Tabără, pe
   talente permanente, și pornești din nou puțin mai tare.

Campania nu se termină după a patra locație: se reia ultima, dar treapta de
dificultate crește mai departe.

## Fuziunea abilităților

Combinațiile sunt descrise în resurse, nu în cod: fiecare `Ability` are
`fuses_with` și `fusion_result`. *Săgeată Perforantă* + *Meteor Infernal* =
*Săgeată Explozivă*. Ca să adaugi o evoluție nouă legi câmpurile în `.tres` —
nu se atinge nicio linie de GDScript.

Când o carte oferită fuzionează cu ceva ce ai deja, cartea o **spune**. Altfel
evoluția ar fi un accident fericit pe care jucătorul nu l-ar putea urmări.
Evoluțiile nu se oferă niciodată direct — rostul lor e să fie descoperite.

## Cine te atacă și cum

| Fel | Poartă |
|---|---|
| **Urmăritor** (schelet, liliac, cavaler) | vine drept, lovește prin contact |
| **Arcaș** (cultist) | ține distanța, țintește unde stai, apoi trage acolo |
| **Năvălitor** (demon) | te pândește, se încarcă, năvălește în linie |

Cei doi care nu se mulțumesc cu contactul își **anunță** lovitura printr-un semn
pe podea înainte s-o dea. Fără acea fracțiune de secundă, jocul ar fi greu în
sensul prost — cel în care mori fără să fi avut ce face.

## Structura

```
games/heroium/
├── project.godot              rezoluție verticală, input, layere, autoloaduri
├── addons/virtual_joystick/   MarcoFazioRandom/Virtual-Joystick-Godot (MIT)
├── scenes/
│   ├── ui/main_menu.tscn      scena de pornire: eroi + Tabăra
│   ├── main.tscn              rularea: podea, lume, erou, HUD, ecrane
│   ├── hero/hero.tscn         eroul cu componentele Combat / Health / Xp
│   ├── enemies/               inamicul și săgeata lui
│   ├── abilities/projectile.tscn
│   └── pickups/xp_orb.tscn
├── scripts/
│   ├── hero/                  mișcare, statistici, țintire, viață, nivel
│   ├── abilities/             abilitatea + regula de fuziune, în date
│   ├── enemies/               tipul de inamic (.tres) și cele trei purtări
│   ├── pickups/               ciobul de experiență
│   ├── systems/               arena, podeaua, locația, efectele, salvarea
│   ├── ui/                    HUD, cărți de nivel, pauză, final, meniu
│   └── visual/blob.gd         corpurile, desenate în cod
├── resources/
│   ├── heroes/                ranger, knight, mage
│   ├── abilities/             pachetul de cărți + evoluția
│   ├── enemies/               felurile de inamic și cei doi șefi
│   └── locations/             cele patru locații
└── tests/run_tests.gd         45 de verificări, rulate fără interfață
```

## Cum sunt împărțite statisticile

Fiecare statistică finală se compune din trei straturi, recalculate la fiecare
schimbare (`HeroStats.recalculate()`):

1. **baza clasei** — din `.tres`-ul eroului
2. **talentele permanente** — Calea Legendară, rămân între rulări
3. **abilitățile luate** — doar pentru rularea curentă

Nimic nu scrie direct în valorile finale. Altfel, un efect care expiră ar lăsa
bonusuri fantomă în urma lui — bug-ul clasic din jocurile cu buff-uri.

Apărarea reduce dauna procentual (`def / (def + 400)`), nu fix. Un inamic cu 850
apărare încasează ~68% din lovitură; oricât ar crește, nu devine invulnerabil.

## Eroii

| | ATK | HP | DEF | Viteză atac | Rază | Deblocare |
|---|---|---|---|---|---|---|
| **Ranger** | 125 | 550 | 35 | 1.8/s | 560 | din start |
| **Knight** | 165 | 950 | 90 | 1.1/s | 360 | 1500 monede |
| **Mage** | 190 | 430 | 25 | 1.0/s | 620 | 2500 monede |

Sunt valori de **bază**, la nivel 1 fără talente. Cifrele din conceptul vizual
(ATK 1250 / HP 4500 / DEF 850) corespund unui erou echipat, la câteva zeci de
niveluri de talente — nu valorilor de pornire.

## De ce e totul desenat în cod

Nu există fișiere de artă. Corpurile, podeaua, semnele de avertizare, scânteile
și toată interfața sunt desenate din GDScript.

Asta nu e o preferință de stil, e o alegere de siguranță: un `Sprite2D` fără
textură **nu desenează nimic și nu se plânge**, iar jocul a stat odată complet
gri exact din motivul ăsta. Formele desenate se văd întotdeauna. Când apare artă
adevărată, `Blob` se înlocuiește cu un `Sprite2D` și restul rămâne cum e.

## Teste

```bash
godot --headless --path games/heroium --script res://tests/run_tests.gd
```

Iese cu cod 1 dacă ceva a picat, și rulează în CI **înaintea** exportului — un
export reușit nu înseamnă un joc care merge, iar asta s-a văzut deja o dată.

Testele nu verifică cum arată jocul, ci lucrurile care se pot strica în tăcere:
că inamicii chiar apar, că eroul chiar trage și ucide, că fuziunea chiar are loc,
că un talent cumpărat chiar se simte în rulare.

> Șterg progresul salvat (`user://heroium_save.cfg`) la început și la sfârșit, ca
> rezultatele să nu depindă de cât a jucat cineva înainte.

## Rulare

Deschide `games/heroium/` ca proiect în **Godot 4.3+** și apasă Play. Pluginul
*Virtual Joystick* e deja activat în `project.godot`.

Buildul Web se face din GitHub Actions → *Build Heroium (Web)*, manual. Rezultatul
ajunge în `games/heroium/play/`, de unde îl servește GitHub Pages.

## Ce nu e făcut

Din conceptul vizual lipsesc, intenționat, părțile care cer un backend sau
magazin, nu cod de joc: Battle Pass, skin-uri, pachete cu monede, reclame, clan
și War Chest. La fel grila de echipament — sistemul de statistici o suportă
(stratul 3), dar nu există încă obiecte.

## Licență addon

`addons/virtual_joystick/` provine din
[MarcoFazioRandom/Virtual-Joystick-Godot](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot),
licență MIT — vezi `addons/virtual_joystick/LICENSE`.

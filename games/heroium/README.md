# Heroium

Action-roguelike top-down în stil Archero, într-o lume medievală întunecată.
Proiect Godot 4, orientat vertical (720×1280), gândit pentru telefon.

> **Luptă. Adună. Evoluează. Devino legendar.**

## Regula centrală

Te **miști** sau **ataci**, niciodată amândouă. Când ridici degetul de pe joystick,
eroul se oprește, își caută singur cea mai apropiată țintă și trage. Mișcarea e
deci mereu o alegere: eviți lovituri, dar renunți la daună.

Regula trăiește într-un singur loc — `hero.gd` decide, iar `hero_combat.gd` doar
execută. Dacă vrei s-o schimbi (de exemplu tragere manuală din mers), se schimbă
o singură linie.

## Structura

```
games/heroium/
├── project.godot              rezoluție verticală, acțiuni de input, layere de coliziune
├── addons/
│   └── virtual_joystick/      MarcoFazioRandom/Virtual-Joystick-Godot (MIT)
├── scenes/
│   ├── main.tscn              arena + erou + HUD cu joystick
│   ├── hero/hero.tscn         eroul cu componentele Combat și Health
│   └── abilities/projectile.tscn
├── scripts/
│   ├── hero/
│   │   ├── hero.gd            mișcare, citire input, regula mișcare-sau-atac
│   │   ├── hero_stats.gd      ATK / HP / DEF / crit, în trei straturi
│   │   ├── hero_class.gd      definiția unei clase (Ranger / Knight / Mage)
│   │   ├── hero_combat.gd     țintire automată, tragere, fuziunea abilităților
│   │   └── hero_health.gd     viață, cadre de grație, revenire
│   ├── abilities/
│   │   ├── ability.gd         abilitate + regula de fuziune, descrisă în date
│   │   └── projectile.gd      săgeata: perforare, ricoșeu, arsură, explozie
│   ├── enemies/enemy.gd       inamic de bază; boșii moștenesc de aici
│   └── systems/
│       ├── game_state.gd      autoload: monede, Calea Legendară, salvare
│       └── arena.gd           camera curentă: spawn, numărătoare, curățare
└── resources/heroes/          ranger.tres, knight.tres, mage.tres
```

## Cum sunt împărțite statisticile

Fiecare statistică finală se compune din trei straturi, recalculate la fiecare
schimbare (`HeroStats.recalculate()`):

1. **baza clasei** — din `.tres`-ul eroului
2. **talentele permanente** — Calea Legendară, rămân între rulări
3. **abilitățile și echipamentul** — doar pentru runda curentă

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

Sunt valori de **bază**, la nivel 1 fără echipament. Cifrele din conceptul vizual
(ATK 1250 / HP 4500 / DEF 850) corespund unui erou echipat, la câteva zeci de
nivele de talente — nu valorilor de pornire.

## Fuziunea abilităților

Combinațiile sunt descrise în resurse, nu în cod: fiecare `Ability` are
`fuses_with` și `fusion_result`. Ca să adaugi o evoluție nouă (de exemplu
*Săgeată Perforantă* + *Meteor Infernal* = *Săgeată Explozivă*) creezi trei
fișiere `.tres` și legi câmpurile — nu se atinge nicio linie de GDScript.

## Ce urmează

- [ ] Resursele de abilități (`resources/abilities/`) și primele lanțuri de fuziune
- [ ] Scenele de inamici: schelet, liliac, demon, arcaș
- [ ] Boss: Bătrânul Rege Căzut, cu atacuri telegrafiate
- [ ] HUD: bară de viață, XP, monede, sloturi de abilități pasive
- [ ] Cele patru locații și progresia de campanie
- [ ] Ecranul Calea Legendară pentru cheltuit monede

## Rulare

Deschide `games/heroium/` ca proiect în **Godot 4.3+**, activează pluginul
*Virtual Joystick* din `Project → Project Settings → Plugins`, apoi apasă Play.

Arena pornește goală până îi dai o `enemy_scene` în Inspector pe nodul `Main` —
eroul se mișcă și funcționează, dar nu are în ce trage.

> Notă: proiectul a fost scris fără Godot instalat pe mașina de build, deci
> scripturile n-au fost rulate în editor. Referințele `res://` sunt verificate
> automat, dar așteaptă-te la mici ajustări la prima deschidere.

## Licență addon

`addons/virtual_joystick/` provine din
[MarcoFazioRandom/Virtual-Joystick-Godot](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot),
licență MIT — vezi `addons/virtual_joystick/LICENSE`.

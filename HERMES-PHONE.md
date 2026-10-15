# Hermes pe telefon: Debian in Termux

Pentru instalarea existenta din Debian/proot, nu pentru pachetul nativ Termux.

## Ce arata capturile

- `root@localhost` si `pkg: command not found`: comanda Termux a fost executata in mediul Debian. Aici se foloseste APT pentru pachetele Debian; nu presupune ca `agent-browser` este un pachet APT.
- Configurarea browserului raporteaza `Managed agent-browser and Chromium are ready`. Acest mesaj nu demonstreaza ca browserul poate porni pe Android/proot; nu reinstala browserul pentru eroarea gateway.
- `systemctl --user ... daemon-reload` esueaza, apoi apare `Gateway inaccessible: service_manager_unavailable`. Urmatorul pas este pornirea manuala a gateway-ului, fara instalare ca serviciu.

## Ruleaza in Debian

Iesi din wizard cu Ctrl+C. Nu relua `hermes setup`.

```bash
bash hermes-phone.sh diagnose
bash hermes-phone.sh gateway
```

Gateway-ul ramane in prim-plan. Daca ramane pornit, deschide o a doua sesiune Termux, intra in aceeasi distributie Debian prin metoda pe care ai folosit-o deja, apoi:

```bash
source ~/.bashrc
hermes chat
```

Daca gateway-ul se opreste sau chat-ul esueaza, trimite eroarea exacta si rezultatul `diagnose`. Nu continua cu reinstalari si nu publica fisierele `.env`, `auth.json`, configuratiile cu chei sau loguri neverificate. Scriptul nu face upload si nu citeste aceste fisiere.

## Limite si validare

Scriptul nu instaleaza pachete, nu modifica configuratia si nu porneste `systemctl`. Modurile `gateway` si `chat` pornesc explicit comenzile cerute. Diagnosticul afiseaza mediul, calea executabilului, versiunea si ajutorul CLI; poate fi rulat inainte de orice modificare.

Verificare locala: sintaxa Bash si dispatch printr-un executabil Hermes simulat. Nu reprezinta un test pe Honor/Android, al autentificarii sau al modelului.

Documentatia oficiala indica `hermes gateway run` pentru rulare fara service manager. Pagina se refera la instalarea nativa Termux; folosirea comenzii in Debian este o incercare de diagnostic, nu o garantie de compatibilitate. La 15 octombrie 2026, pagina avertizeaza ca pachetul nativ Termux este defect; migrarea la acel pachet nu este o remediere confirmata.

Sursa: https://hermes-agent.nousresearch.com/docs/getting-started/termux

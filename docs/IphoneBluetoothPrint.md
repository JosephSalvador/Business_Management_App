# iPhone Bluetooth Thermal Printing & Bluefy Integration

## 1. Muhtasari na Changamoto ya Kiufundi (Background & Problem)

Mfumo wa **Jolinx Business OS** umeundwa kutoa risiti za haraka za madukani kwa kutumia printa za risiti za mkononi (Thermal Bluetooth Printers za 58mm na 80mm).

Kwenye vifaa vya **Android**, uchapishaji unafanya kazi 100% papo hapo kupitia **Classic Bluetooth (SPP / Serial Port Profile)**. Hata hivyo, kwenye vifaa vya **Apple (iPhone / iPad)** kuna vizuizi viwili vya kiusalama vilivyowekwa na Apple:
1. **Kizuizi cha MFi (Made for iPhone):** Apple inazuia iPhone kuunganishwa na Classic Bluetooth SPP isipokuwa printa iwe na chip maalum ya leseni ya Apple (MFi). Printa nyingi za bei nafuu za madukani (\$15–\$35) hazina chip hii.
2. **Kizuizi cha Safari (PWA Web Bluetooth):** Apple inazuia kivinjari cha Safari na PWA kufikia Bluetooth ya simu kwa kigezo cha faragha (privacy & fingerprinting).

---

## 2. Suluhisho Lililothibitishwa (The Solution: Bluefy Web BLE)

Printa za kisasa za mkononi (ikiwemo *Xprinter, Goojprt PT-210, MTP-II, POS-58, Peripage, na Netum*) zina teknolojia ya **Dual-Mode Bluetooth**:
* Zina **SPP** (kwa ajili ya Android).
* Zina **BLE (Bluetooth Low Energy / Bluetooth 4.0+)** (kwa ajili ya iPhone).

Apple **hairuhusu MFi kwenye BLE**—hivyo iPhone yoyote inaweza kuwasiliana na printa za BLE bila kipingamizi cha leseni ya Apple! Ili kuwezesha PWA/Web yetu kutumia BLE kwenye iPhone bila kulipia akaunti ya Apple Developer (\$99/mwaka), tunatumia kivinjari rasmi cha **Bluefy – Web BLE Browser** kilichopo bure kwenye Apple App Store.

---

## 3. Mwongozo wa Hatua kwa Hatua kwa Mtumiaji wa iPhone (Step-by-Step User Guide)

Mtumiaji mwenye iPhone (Duka / Muuzaji) anayependa kuchapa risiti kwa Bluetooth anapaswa kufuata hatua zifuatazo:

### Hatua ya 1: Sakinisha Bluefy kwenye iPhone
1. Fungua **Apple App Store** kwenye iPhone yako.
2. Tafuta: **`Bluefy - Web BLE Browser`** (Inatengenezwa na PNN Soft, ni ya bure 100%).
3. Bonyeza **Get / Pakua** kuisakinisha kwenye iPhone.

### Hatua ya 2: Hakikisha Printa Imewashwa na Ina Bluetooth BLE
1. Washa printa yako ya risiti ya mkononi (hakikisha ina chaji na karatasi ya 58mm au 80mm).
2. Printa nyingi za soko la Afrika Mashariki (kama *PT-210, MTP-II, Xprinter*) huwa tayari zina BLE 4.0+ ikiwa wazi.
3. *Angalizo:* Usijaribu ku-pair printa hii kwenye menyu ya kawaida ya *Settings > Bluetooth* ya iPhone, kwa sababu iPhone itaitafuta kama kifaa cha sauti (audio). Unganisho litafanyika moja kwa moja ndani ya mfumo wetu!

### Hatua ya 3: Fungua Jolinx Business OS Ndani ya Bluefy
1. Fungua programu ya **Bluefy** kwenye iPhone.
2. Kwenye sehemu ya anwani (URL bar) juu, andika anwani ya wavuti ya mfumo wako (mfano: `https://app.jolinx.co.tz`). *(Kumbuka: Web Bluetooth inahitaji muunganisho salama wa HTTPS).*
3. Ingia kwenye akaunti yako (Login) kwa namba yako ya simu/barua pepe na nenosiri.

### Hatua ya 4: Kufanya Mauzo na Kuchapa Risiti
1. Fanya mauzo kama kawaida kwenye skrini ya **POS**.
2. Ukishakamilisha mauzo (skrini ya **Sale Success**):
3. Bonyeza kitufe cha **"Chapa Risiti (Print Receipt)"**.
4. Bluefy itafungua kidirisha chenye ujumbe: *"app.jolinx.co.tz wants to pair with a Bluetooth device"*.
5. Kwenye orodha ya vifaa vitakavyotokea, chagua jina la printa yako (mfano: `MTP-II`, `POS-58`, `InnerPrinter`, au `Bluetooth Printer`).
6. Bonyeza **Pair**.
7. Risiti inatoka kwenye printa mara moja kiasilia!

---

## 4. Taarifa za Kiufundi za Printa Zinazofanya Kazi (Technical BLE Specifications)

Wakati mfumo wetu unapotuma bytes za ESC/POS kupitia Web Bluetooth, unawasiliana na GATT Services zifuatazo ambazo zipo kwenye printa zote za kawaida za Kichina na kimataifa:

| Kigezo | Thamani Zinazotumiwa na Printa (GATT UUIDs) |
| :--- | :--- |
| **Standard Thermal Service UUID** | `000018f0-0000-1000-8000-00805f9b34fb` au `0000ffe0-0000-1000-8000-00805f9b34fb` |
| **ISSC Proprietary BLE Service** | `49535343-fe7d-4ae5-8fa9-9fafd205e455` |
| **Write Characteristic UUID** | `00002af1-0000-1000-8000-00805f9b34fb`, `0000ffe1-0000-1000-8000-00805f9b34fb`, au `49535343-8841-43f4-a8d4-ecbe34729bb3` |
| **Kasi ya Kutuma (MTU Chunking)** | Data hutumwa kwa vipande vya kati ya **20 hadi 100 bytes** kwa kila sekunde chache ili kuzuia buffer overflow kwenye printa. |

---

## 5. Mbadala kwa Watumiaji Wasiotaka Kutumia Bluefy (Safari PWA Alternatives)
Kama mfanyabiashara anataka kutumia Safari ya kawaida bila Bluefy:
1. **Wi-Fi / Network Thermal Printer:** Duka linaweza kutumia printa ya risiti ya Wi-Fi/LAN. Mtumiaji anabonyeza print na inachapa kupitia AirPrint/IP port 9100.
2. **Kushare WhatsApp / PDF:** Kugusa kitufe kimoja cha "Shiriki" na kumtumia mteja risiti safi moja kwa moja kwenye WhatsApp yake bila kutumia karatasi.

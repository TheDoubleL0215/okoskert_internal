# Firestore Properties Dokumentáció

Ez a dokumentum tartalmazza az összes Firestore-ban tárolt property-t, amelyet az alkalmazás használ.

## Collections és Subcollections

### 1. `projects` Collection

#### Fő dokumentum mezők:

- **`teamId`** (String, kötelező)
  - A munkatér azonosítója, amelyhez a projekt tartozik

- **`projectName`** (String, kötelező)
  - A projekt neve

- **`customerName`** (String, kötelező)
  - A megrendelő neve

- **`customerPhone`** (String, opcionális)
  - A megrendelő telefonszáma (+36 formátumban)

- **`customerEmail`** (String, opcionális)
  - A megrendelő email címe

- **`projectLocation`** (String, opcionális)
  - A projekt helyszíne

- **`projectDescription`** (String, opcionális)
  - A projekt leírása

- **`projectType`** (List<String>, kötelező)
  - A projekt típusa(i) - lista formátumban

- **`projectStatus`** (String, kötelező)
  - A projekt státusza
  - Lehetséges értékek: `'ongoing'`, `'done'`, `'maintenance'`

- **`createdAt`** (Timestamp, automatikus)
  - A projekt létrehozásának ideje (FieldValue.serverTimestamp())

- **`updatedAt`** (Timestamp, automatikus)
  - A projekt utolsó frissítésének ideje (FieldValue.serverTimestamp())

#### Subcollections:

##### `projects/{projectId}/worklog` Subcollection

Munkanapló bejegyzések a projekthez:

- **`employeeName`** (String, kötelező)
  - A dolgozó ID-ja (user dokumentum ID)

- **`startTime`** (Timestamp, kötelező)
  - A munka kezdési ideje

- **`endTime`** (Timestamp, kötelező)
  - A munka befejezési ideje

- **`breakMinutes`** (int, opcionális, default: 0)
  - Szünet percekben

- **`date`** (DateTime/Timestamp, kötelező)
  - A munka dátuma (éjfél időpont)

- **`createdAt`** (Timestamp, automatikus)
  - A bejegyzés létrehozásának ideje (FieldValue.serverTimestamp())

- **`description`** (String, opcionális)
  - Leírás a munkáról

- **`updatedAt`** (Timestamp, opcionális)
  - A bejegyzés frissítésének ideje (FieldValue.serverTimestamp())

##### `projects/{projectId}/images` Subcollection

Projekt képek:

- **`url`** (String, kötelező)
  - A kép URL-je a Firebase Storage-ból

- **`sectionName`** (String, kötelező)
  - A kép szekciója
  - Lehetséges értékek: `'Munka előtt'`, `'Munka közben'`, `'Munka után'`, `'Egyéb'`

- **`uploadedAt`** (Timestamp, automatikus)
  - A kép feltöltésének ideje (FieldValue.serverTimestamp())

##### `projects/{projectId}/machineWorklog` Subcollection

Gépek óraállás bejegyzései projekthez kapcsolva:

- **`teamId`** (String, kötelező)
  - A munkatér azonosítója

- **`date`** (Timestamp, kötelező)
  - A bejegyzés dátuma

- **`previousHours`** (num, kötelező)
  - Az előző óraállás

- **`newHours`** (num, kötelező)
  - Az új óraállás

- **`machineId`** (String, kötelező)
  - A gép dokumentum ID-ja

- **`assignedProjectId`** (String, opcionális)
  - A projekt ID-ja, amelyhez a gép óraállása kapcsolódik

- **`createdAt`** (Timestamp, automatikus)
  - A bejegyzés létrehozásának ideje (FieldValue.serverTimestamp())

---

### 2. `calendar` Collection

Naptár bejegyzések:

- **`teamId`** (String, kötelező)
  - A munkatér azonosítója

- **`date`** (Timestamp, kötelező)
  - A bejegyzés dátuma (éjfél időpont)

- **`type`** (String, kötelező)
  - A bejegyzés típusa (pl. 'Jegyzet')

- **`title`** (String, kötelező)
  - A bejegyzés címe

- **`description`** (String, opcionális)
  - A bejegyzés leírása

- **`assignedEmployees`** (List<String>, opcionális)
  - A hozzárendelt munkatársak ID listája (user dokumentum ID-k)

- **`assignedProjects`** (List<String>, opcionális)
  - A hozzárendelt projektek ID listája

- **`priority`** (int, opcionális, default: 0)
  - Prioritás szint
  - Lehetséges értékek: `0` (Normál), `1` (Fontos), `2` (Sürgős)

- **`subtasks`** (List<Map<String, dynamic>>, opcionális)
  - Részfeladatok listája
  - Minden részfeladat tartalmazza:
    - **`title`** (String): A részfeladat címe
    - **`status`** (String): A részfeladat státusza (`'ongoing'` vagy `'done'`)

- **`createdAt`** (Timestamp, automatikus)
  - A bejegyzés létrehozásának ideje (FieldValue.serverTimestamp())

---

### 3. `materials` Collection

Alapanyagok:

- **`teamId`** (String, kötelező)
  - A munkatér azonosítója

- **`name`** (String, kötelező)
  - Az alapanyag neve

- **`quantity`** (double, kötelező)
  - A mennyiség

- **`unit`** (String, kötelező)
  - A mértékegység
  - Lehetséges értékek: `'m³'`, `'m²'`, `'db'`, `'kg'`, `'tonna'`

- **`date`** (Timestamp, kötelező)
  - Az alapanyag hozzáadásának dátuma

- **`projectId`** (String, opcionális)
  - A projekt ID-ja, amelyhez az alapanyag tartozik

- **`price`** (double, opcionális)
  - Az összesen ár (HUF)

- **`unitPrice`** (double, opcionális)
  - Az egységár (HUF/mértékegység)

- **`priceMode`** (String, opcionális)
  - Az ár módja
  - Lehetséges értékek: `'unitPrice'` (egységár alapú), `'customPrice'` (egyedi ár)

- **`createdAt`** (Timestamp, automatikus)
  - Az alapanyag létrehozásának ideje (FieldValue.serverTimestamp())

---

### 4. `machines` Collection

Gépek:

- **`teamId`** (String, kötelező)
  - A munkatér azonosítója

- **`name`** (String, kötelező)
  - A gép neve

- **`hours`** (double, kötelező)
  - A jelenlegi óraállás

- **`tmkMaintenanceHours`** (double, opcionális, default: 0)
  - TMK karbantartás óránkénti értéke

- **`maintenances`** (List<Map<String, dynamic>>, opcionális)
  - Karbantartások listája
  - Minden karbantartás tartalmazza:
    - **`name`** (String): A karbantartás neve
    - **`hours`** (double): A karbantartás óránkénti értéke

- **`createdAt`** (Timestamp, automatikus)
  - A gép létrehozásának ideje (FieldValue.serverTimestamp())

- **`updatedAt`** (Timestamp, automatikus)
  - A gép utolsó frissítésének ideje (FieldValue.serverTimestamp())

#### Subcollections:

##### `machines/{machineId}/workHoursLog` Subcollection

Gép óraállás bejegyzései:

- **`teamId`** (String, kötelező)
  - A munkatér azonosítója

- **`date`** (Timestamp, kötelező)
  - A bejegyzés dátuma

- **`previousHours`** (num, kötelező)
  - Az előző óraállás

- **`newHours`** (num, kötelező)
  - Az új óraállás

- **`machineId`** (String, kötelező)
  - A gép dokumentum ID-ja

- **`assignedProjectId`** (String, opcionális)
  - A projekt ID-ja, amelyhez a gép óraállása kapcsolódik

- **`createdAt`** (Timestamp, automatikus)
  - A bejegyzés létrehozásának ideje (FieldValue.serverTimestamp())

---

### 5. `workspaces` Collection

Munkatér beállítások:

- **`name`** (String, kötelező)
  - A munkahely neve

- **`address`** (String, kötelező)
  - A munkahely címe

- **`teamId`** (String, kötelező)
  - A munkatér egyedi azonosítója (6 karakteres alfanumerikus kód)

- **`createdAt`** (Timestamp, automatikus)
  - A munkatér létrehozásának ideje (FieldValue.serverTimestamp())

#### Subcollections:

##### `workspaces/{workspaceId}/workTypes` Subcollection

Munkatípusok:

- **`name`** (String, kötelező)
  - A munkatípus neve

- **`createdAt`** (Timestamp, automatikus)
  - A munkatípus létrehozásának ideje (FieldValue.serverTimestamp())

##### `workspaces/{workspaceId}/joinRequests` Subcollection

Csatlakozási kérelmek:

- **`userId`** (String, kötelező)
  - A felhasználó ID-ja (user dokumentum ID)

- **`name`** (String, kötelező)
  - A felhasználó neve

- **`email`** (String, kötelező)
  - A felhasználó email címe

- **`status`** (String, kötelező)
  - A kérelem státusza
  - Lehetséges értékek: `'pending'`

- **`createdAt`** (Timestamp, automatikus)
  - A kérelem létrehozásának ideje (FieldValue.serverTimestamp())

---

### 6. `users` Collection

Felhasználók:

- **`name`** (String, kötelező)
  - A felhasználó neve

- **`email`** (String, kötelező)
  - A felhasználó email címe

- **`teamId`** (String, opcionális)
  - A munkatér azonosítója, amelyhez a felhasználó tartozik

- **`role`** (int, opcionális)
  - A felhasználó szerepköre
  - Lehetséges értékek:
    - `1`: Admin
    - `2`: Építésvezető
    - `3`: Kertész

- **`createdAt`** (Timestamp, automatikus)
  - A felhasználó létrehozásának ideje (FieldValue.serverTimestamp())

---

## Összefoglaló táblázat

| Collection | Property | Típus | Kötelező | Leírás |
|------------|----------|-------|----------|--------|
| **projects** | teamId | String | ✓ | Munkatér azonosító |
| **projects** | projectName | String | ✓ | Projekt neve |
| **projects** | customerName | String | ✓ | Megrendelő neve |
| **projects** | customerPhone | String | | Megrendelő telefonszáma |
| **projects** | customerEmail | String | | Megrendelő email címe |
| **projects** | projectLocation | String | | Projekt helyszíne |
| **projects** | projectDescription | String | | Projekt leírása |
| **projects** | projectType | List<String> | ✓ | Projekt típusa(i) |
| **projects** | projectStatus | String | ✓ | Projekt státusza |
| **projects** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **projects** | updatedAt | Timestamp | ✓ | Frissítés ideje |
| **projects/worklog** | employeeName | String | ✓ | Dolgozó ID |
| **projects/worklog** | startTime | Timestamp | ✓ | Munka kezdési ideje |
| **projects/worklog** | endTime | Timestamp | ✓ | Munka befejezési ideje |
| **projects/worklog** | breakMinutes | int | | Szünet percekben |
| **projects/worklog** | date | Timestamp | ✓ | Munka dátuma |
| **projects/worklog** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **projects/worklog** | description | String | | Leírás |
| **projects/worklog** | updatedAt | Timestamp | | Frissítés ideje |
| **projects/images** | url | String | ✓ | Kép URL-je |
| **projects/images** | sectionName | String | ✓ | Kép szekciója |
| **projects/images** | uploadedAt | Timestamp | ✓ | Feltöltés ideje |
| **projects/machineWorklog** | teamId | String | ✓ | Munkatér azonosító |
| **projects/machineWorklog** | date | Timestamp | ✓ | Bejegyzés dátuma |
| **projects/machineWorklog** | previousHours | num | ✓ | Előző óraállás |
| **projects/machineWorklog** | newHours | num | ✓ | Új óraállás |
| **projects/machineWorklog** | machineId | String | ✓ | Gép ID |
| **projects/machineWorklog** | assignedProjectId | String | | Projekt ID |
| **projects/machineWorklog** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **calendar** | teamId | String | ✓ | Munkatér azonosító |
| **calendar** | date | Timestamp | ✓ | Bejegyzés dátuma |
| **calendar** | type | String | ✓ | Bejegyzés típusa |
| **calendar** | title | String | ✓ | Bejegyzés címe |
| **calendar** | description | String | | Bejegyzés leírása |
| **calendar** | assignedEmployees | List<String> | | Hozzárendelt munkatársak |
| **calendar** | assignedProjects | List<String> | | Hozzárendelt projektek |
| **calendar** | priority | int | | Prioritás (0-2) |
| **calendar** | subtasks | List<Map> | | Részfeladatok |
| **calendar** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **materials** | teamId | String | ✓ | Munkatér azonosító |
| **materials** | name | String | ✓ | Alapanyag neve |
| **materials** | quantity | double | ✓ | Mennyiség |
| **materials** | unit | String | ✓ | Mértékegység |
| **materials** | date | Timestamp | ✓ | Hozzáadás dátuma |
| **materials** | projectId | String | | Projekt ID |
| **materials** | price | double | | Összesen ár |
| **materials** | unitPrice | double | | Egységár |
| **materials** | priceMode | String | | Ár módja |
| **materials** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **machines** | teamId | String | ✓ | Munkatér azonosító |
| **machines** | name | String | ✓ | Gép neve |
| **machines** | hours | double | ✓ | Jelenlegi óraállás |
| **machines** | tmkMaintenanceHours | double | | TMK karbantartás |
| **machines** | maintenances | List<Map> | | Karbantartások |
| **machines** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **machines** | updatedAt | Timestamp | ✓ | Frissítés ideje |
| **machines/workHoursLog** | teamId | String | ✓ | Munkatér azonosító |
| **machines/workHoursLog** | date | Timestamp | ✓ | Bejegyzés dátuma |
| **machines/workHoursLog** | previousHours | num | ✓ | Előző óraállás |
| **machines/workHoursLog** | newHours | num | ✓ | Új óraállás |
| **machines/workHoursLog** | machineId | String | ✓ | Gép ID |
| **machines/workHoursLog** | assignedProjectId | String | | Projekt ID |
| **machines/workHoursLog** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **workspaces** | name | String | ✓ | Munkahely neve |
| **workspaces** | address | String | ✓ | Munkahely címe |
| **workspaces** | teamId | String | ✓ | Munkatér azonosító |
| **workspaces** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **workspaces/workTypes** | name | String | ✓ | Munkatípus neve |
| **workspaces/workTypes** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **workspaces/joinRequests** | userId | String | ✓ | Felhasználó ID |
| **workspaces/joinRequests** | name | String | ✓ | Felhasználó neve |
| **workspaces/joinRequests** | email | String | ✓ | Felhasználó email |
| **workspaces/joinRequests** | status | String | ✓ | Kérelem státusza |
| **workspaces/joinRequests** | createdAt | Timestamp | ✓ | Létrehozás ideje |
| **users** | name | String | ✓ | Felhasználó neve |
| **users** | email | String | ✓ | Felhasználó email |
| **users** | teamId | String | | Munkatér azonosító |
| **users** | role | int | | Felhasználó szerepköre |
| **users** | createdAt | Timestamp | ✓ | Létrehozás ideje |

---

## Megjegyzések

1. **Timestamp mezők**: A `createdAt` és `updatedAt` mezők általában `FieldValue.serverTimestamp()` értéket kapnak, amely a szerver oldali időbélyeget állítja be.

2. **Opcionális mezők**: Az opcionális mezők lehetnek `null` értékűek, vagy egyáltalán nem szerepelhetnek a dokumentumban.

3. **Lista mezők**: A lista típusú mezők (pl. `projectType`, `assignedEmployees`) üres listaként is tárolhatók.

4. **Subcollections**: A subcollections a szülő dokumentum alatt találhatók, például: `projects/{projectId}/worklog/{worklogId}`.

5. **ID mezők**: A dokumentumok ID-ja általában a Firestore automatikusan generálja az `.add()` metódus használatakor, vagy explicit módon megadható a `.doc(id)` metódussal.

---

*Utolsó frissítés: 2026. január 25.*

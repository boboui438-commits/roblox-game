# 🎮 NOOB ➜ GOD SIMULATOR

Un jeu Roblox **Simulator** complet, jouable, écrit intégralement en Luau :
collecte, transformations, pets, rebirths, 6 mondes, événements aléatoires,
succès, classements et sauvegarde DataStore.

> **Aucune asset externe requise.** Toute la map, tous les pets 3D et toute
> l'interface sont générés par code, à partir de primitives Roblox. Tu peux
> ouvrir le jeu et y jouer immédiatement.

| | |
|---|---|
| **Code Luau** | ~11 600 lignes, 39 fichiers |
| **Systèmes serveur** | 14 modules autonomes |
| **Mondes** | 1 lobby + 6 mondes thématiques générés |
| **Pets** | 26 pets, 7 raretés, 7 œufs, fusion |
| **Succès** | 24 |
| **Événements** | 6 événements aléatoires toutes les 5 min |
| **Fichier de place prêt** | `build/NoobToGodSimulator.rbxlx` |

---

## 1. Démarrer en 60 secondes

### Option A — Le plus rapide (fichier de place fourni)

1. Télécharge **`build/NoobToGodSimulator.rbxlx`**.
2. Ouvre **Roblox Studio** → `File` → `Open from File…` → sélectionne le fichier.
3. Appuie sur **Play** (F5). Le serveur génère la map au démarrage (~1 s).
4. Tu apparais dans le lobby puis tu es téléporté dans **Noob Island**. Clique
   sur les objets pour les absorber.

> Pour que les **sauvegardes** fonctionnent en Studio :
> `Game Settings` → `Security` → active **Enable Studio Access to API Services**.
> Sans ça, le jeu tourne quand même, mais en « mode invité » (aucune sauvegarde).

### Option B — Avec Rojo (édition en direct du code)

```bash
# 1. installe Rojo (https://rojo.space) puis :
rojo serve                     # dans le dossier du repo
# 2. dans Roblox Studio : installe le plugin Rojo, clique "Connect"
# 3. Play → le jeu se construit tout seul
```

Le fichier `default.project.json` mappe déjà `src/` vers la bonne hiérarchie.

### Régénérer le fichier `.rbxlx` après une modification du code

```bash
python3 tools/build_rbxlx.py     # -> build/NoobToGodSimulator.rbxlx
```

---

## 2. Comment on joue (boucle de jeu)

1. **Absorber** : clique / tape sur un objet → il disparaît dans une explosion de
   particules et tu gagnes de la **puissance** (⚡) + des **pièces** (🪙).
   Maintiens le clic pour absorber en rafale.
2. **Grandir** : ta puissance te fait passer par **10 transformations**
   (Noob → Beginner → Pro → Hacker → Titan → Monster → God → Cosmic →
   Universal → **Infinity**). Le personnage grossit vraiment et gagne aura,
   traînée et lumière.
3. **Acheter** : les pièces servent aux **améliorations** (multiplicateur de
   puissance, absorption automatique, aspirateur de zone, vitesse, slots de
   pets) et aux **œufs**.
4. **Collectionner** : 26 pets, 7 raretés (Common → Secret), fusion de 3 pets
   identiques pour monter leur niveau (×10 max).
5. **Rebirth** : tu sacrifie ta puissance contre un multiplicateur permanent,
   des pièces et de nouveaux titres/mondes (40 rebirths).
6. **Explorer** : 6 mondes de plus en plus rentables (jusqu'à ×12 000 de valeur
   par objet) avec chacun son œuf, son décor et son ambiance.
7. **Événements** : toutes les 5 minutes, un événement aléatoire pour tout le
   serveur (géant, pluie de pièces, gravité lunaire, objets dorés, chaos, chance).

---

## 3. Arborescence (identique à Roblox Studio)

Tout est généré depuis `src/`. Voici la correspondance **fichier → instance** :

```
ReplicatedStorage
└── Modules                      (ModuleScripts partagés client + serveur)
    ├── GameConfig      637 l.   Tous les réglages du jeu (objets, pets, œufs, monde, events…)
    ├── Formulas        304 l.   Toutes les formules (multiplicateurs, coûts, formatage, probabilités)
    ├── Net             167 l.   Registre des RemoteEvents/RemoteFunctions
    ├── ProfileTemplate 276 l.   Structure + migration/validation des sauvegardes
    ├── Signal           81 l.   Petit bus d'événements interne
    └── Util            190 l.   Utilitaires (deepCopy, weightedChoice, uid…)
└── Remotes                      (créé au runtime par Net.init())

ServerScriptService
├── Bootstrap.server.lua          Point d'entrée unique (ordre de démarrage)
└── Systems
    ├── DataManager     591 l.   Sauvegarde DataStore, verrou de session, autosave, leaderstats
    ├── WorldFactory    885 l.   Génère le lobby + les 6 mondes depuis du code
    ├── CollectSystem   530 l.   Apparition des objets, clics validés, auto-collect, aspirateur
    ├── PetSystem       519 l.   Œufs, inventaire, équipement, fusion, meilleurs pets
    ├── EventManager    396 l.   Les 6 événements aléatoires + compte à rebours
    ├── CharacterSystem 323 l.   Transformations (taille), auras, titres, vitesse
    ├── WorldManager    353 l.   Voyages, portails, déblocages, occupation des mondes
    ├── LeaderboardManager 237 l. Classement serveur + mondial (OrderedDataStore)
    ├── MonetizationSystem 189 l. Game Passes + Developer Products (ProcessReceipt)
    ├── DailyRewardSystem 174 l. Récompense quotidienne + gains hors-ligne
    ├── RebirthSystem   173 l.   Rebirth, coûts, titres, annonces
    ├── SettingsSystem  155 l.   Paramètres, sélection de titre, GetProfile
    ├── ShopSystem      130 l.   Achats d'améliorations (validés serveur)
    └── AchievementSystem 116 l. Les 24 succès et leurs récompenses

StarterPlayer.StarterPlayerScripts
├── ClientController.client.lua   LocalScript d'entrée : remotes, clic, démarrage UI
├── Controllers
│   ├── ClientState   208 l.   Miroir du profil serveur + signaux
│   ├── EffectsController 403 l. Particules, nombres flottants, shake, ambiances
│   ├── ClientState / PetFactory 166 l. Modèles 3D des pets (primitives)
│   ├── PetFollowController 154 l. Pets qui suivent le joueur
│   └── SoundController 143 l. Sons natifs Roblox + musique par monde
└── UI
    ├── UIController  354 l.   ScreenGui principale, modales, révélation d'œuf
    ├── UILib         679 l.   Bibliothèque de composants (boutons, modales, bars…)
    ├── UIConfig       80 l.   Thème (couleurs, polices, tailles)
    ├── HudUI         599 l.   HUD permanent (puissance, pièces, boutons, event)
    ├── ShopUI        370 l.   Boutique (améliorations, game passes, boosts)
    ├── PetsUI        469 l.   Œufs + inventaire + fusion
    ├── RebirthUI     235 l.   Écran de rebirth
    ├── WorldsUI      179 l.   Écran des mondes
    ├── LeaderboardUI 199 l.   Classements serveur/mondial
    ├── AchievementsUI 169 l.  Succès
    ├── SettingsUI    249 l.   Réglages + titres + statistiques
    └── DailyUI       150 l.   Récompense quotidienne
```

> 📄 Le détail script par script (rôle, connexions, comment le tester) est dans
> **[`docs/SCRIPTS.md`](docs/SCRIPTS.md)**.

---

## 4. Architecture & flux de données

```
   CLIENT                                  SERVEUR
   ──────                                  ───────
   clic sur un objet
        │ CollectRequest(part)
        ├──────────────────────────────►  CollectSystem : vérifie
        │                                  • la partie existe (registry)
        │                                  • la distance (≤ 260 studs)
        │                                  • le monde du joueur
        │                                  • la limite de requêtes/s
        │                                    ↓
        │                                  DataManager.addPower (autorité)
        │                                    ↓
        ◄──── ProfileUpdated(profil) ────── notify() (throttlé 0.1 s)
        ◄──── EffectBurst(pos, valeur) ──── effets
        │
   ClientState (affichage)
```

**Règle d'or** : le client **ne calcule jamais** de puissance, de pièce ou de
tirage d'œuf. Il envoie une intention, le serveur décide, puis renvoie l'état
(`ProfileUpdated`). Toutes les valeurs affichées viennent du serveur.

### Remotes disponibles (`ReplicatedStorage.Remotes`)

**Client → Serveur (RemoteEvents)**
`CollectRequest(part)` · `VacuumRequest()` · `BuyUpgrade(id)` ·
`OpenEgg(eggId, qty)` · `EquipPet(uid)` · `UnequipPet(uid)` · `EquipBestPets()` ·
`FusePet(petId)` · `RebirthRequest()` · `TravelWorld(index)` · `ClaimDaily()` ·
`ClaimAchievement(id)` · `SelectTitle(id)` · `SetSetting(key, value)` ·
`ClientReady()` · `PlayEmote(name)` · `ComparePower(userId)`

**Serveur → Client**
`ProfileUpdated(profil)` · `Notify(texte, couleur, icône)` ·
`EffectBurst(pos, couleur, valeur)` · `EventUpdate(id, endsAt)` ·
`EggResult(…)` · `LeaderboardData(…)` · `PlaySound(key)` · `CameraShake(n)` ·
`ScreenFlash(couleur)` · `SetWorld(index)` · `Transformation(tier)` ·
`DailyAvailable(bool)` · `BoostUpdate(mult, endsAt)` · `RebirthSuccess(n, coins)`

**RemoteFunctions** : `GetProfile()` · `GetLeaderboards()` · `GetServerInfo()`

---

## 5. Ce qui est implémenté, point par point

| Brief | État | Où |
|---|---|---|
| Collecte au clic / tap / maintien | ✅ | `ClientController` + `CollectSystem` |
| Absorption automatique (amélioration) | ✅ | `Formulas.autoCollectRadius` + boucle serveur |
| Aspirateur de zone (bonus) | ✅ | `CollectSystem.collectRadius` |
| Valeurs des objets (1 → 5 000) | ✅ | `GameConfig.ObjectTypes` |
| Effets visuels + sonores | ✅ | `EffectsController`, `SoundController` |
| 10 transformations (apparence, taille, aura, animations) | ✅ | `GameConfig.Transformations` + `CharacterSystem` |
| 7 raretés, 26 pets, modèles 3D, animation de suivi | ✅ | `GameConfig.Pets`, `PetFactory`, `PetFollowController` |
| Œufs multiples + probabilités affichées | ✅ | `GameConfig.Eggs`, `PetsUI` |
| Inventaire, équipement multiple, fusion, meilleurs pets | ✅ | `PetSystem`, `PetsUI` |
| Rebirth ×40, multiplicateur, récompenses, titres | ✅ | `RebirthSystem`, `RebirthUI` |
| 6 mondes différents (décor, objets, œuf, ambiance) | ✅ | `WorldFactory`, `WorldsUI` |
| Événements aléatoires (6) + compte à rebours | ✅ | `EventManager`, bannière du HUD |
| Classement serveur + mondial | ✅ | `LeaderboardManager` (+ panneau dans le lobby) |
| Titres au-dessus des joueurs | ✅ | `CharacterSystem.buildTitle` |
| Comparaison de puissance, récompenses quotidiennes, succès | ✅ | `SettingsSystem.compare`, `DailyRewardSystem`, `AchievementSystem` |
| UI moderne complète (puissance, pièces, rebirths, multiplicateur, tiers, shop, worlds, rebirth, settings) | ✅ | `HudUI` + 9 modales |
| Responsive téléphone / tablette / PC | ✅ | `UIScale` dynamique, boutons 84 px |
| Game Passes + Developer Products | ✅ (IDs à renseigner) | `MonetizationSystem` |
| DataStore + autosave + gestion d'erreurs + anti-perte | ✅ | `DataManager` |
| Sécurité (calculs serveur, validation des remotes) | ✅ | voir §8 |
| Optimisation mobile | ✅ | voir §9 |

---

## 6. Réglages d'équilibrage (tout dans `GameConfig`)

| Paramètre | Valeur | Où / effet |
|---|---|---|
| Valeurs des objets | 1 / 5 / 20 / 100 / 500 / 5 000 | `ObjectTypes` |
| Multiplicateur de valeur par monde | ×1 → ×12 000 | `Worlds[i].ValueMult` |
| Seuils des transformations | 0 → 10 000 000 | `Transformations[i].MinPower` |
| Coût du rebirth | `2500 × 1.85^rebirths` | `Rebirth.BaseCost/CostGrowth` |
| Multiplicateur de rebirth | `1 + rebirths × 0.35` | `Rebirth.MultPerRebirth` |
| Nombre de rebirths | 40 | `Rebirth.MaxRebirths` |
| Intervalle des événements | 300 s | `EventInterval` |
| Pièces gagnées | 12 % de la puissance | `Collect.CoinRatio` |
| Objets actifs par monde | 90 (34 si monde vide) | `Collect.MaxActivePerWorld` |
| Sauvegarde auto | 60 s | `Misc.SaveInterval` |
| Cooldown quotidien | 20 h | `DailyResetSeconds` |
| Gains hors-ligne max | 8 h | `MaxOfflineHours` |

Rien d'autre à toucher : le client lit ces valeurs pour l'affichage, le serveur
les applique.

---

## 7. Comment tester chaque système

> Astuce Studio : `Test` → `Start` avec **2 joueurs** pour voir le classement et
> les annonces de pets rares.

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Lance Play | Écran « NOOB ➜ GOD » puis HUD ; tu apparais à Noob Island |
| 2 | Clique sur un déchet | +1 ⚡ (×multiplicateur), particules, son, pièces |
| 3 | Maintiens le clic | Absorptions en rafale (limité à 22 req/s) |
| 4 | Bouton 🌪️ ASPIRER | Tous les objets dans 45 studs disparaissent, puis cooldown |
| 5 | Ouvre la Boutique → achète « Absorption automatique » | Niveau 1, les objets proches sont aspirés tout seuls |
| 6 | Bouton 🥚 Œufs → « Œuf du Noob » | Révélation animée d'un pet, badge « NOUVEAU » |
| 7 | Onglet Inventaire → ÉQUIPER | Le pet 3D apparaît et suit le joueur |
| 8 | Fusionner (collectionne 3 identiques) | 1 pet de niveau supérieur, multiplicateur augmenté |
| 9 | 🔄 Rebirth (puissance ≥ 2 500) | Animation, puissance remise à 0, multiplicateur, annonce serveur |
| 10 | 🌍 Mondes → Portail 2 | Message de verrou si non débloqué, sinon téléportation (fondu) |
| 11 | Atteins 1 500 ⚡ | Candy World se débloque automatiquement (toast + son) |
| 12 | Attends 5 min | Bannière d'événement + compte à rebours ; teste gravité/pièces |
| 13 | 📅 Quotidien | Récompense donnée une seule fois, cooldown affiché |
| 14 | ⚙️ Réglages | Les toggles s'appliquent (musique, particules, pets visibles) |
| 15 | 🏆 Classement | Ton nom apparaît, tri par puissance |
| 16 | Rejoins le lobby (pad retour) | Panneau top du serveur visible sur le mur |
| 17 | Quitte et rejoins (API activée) | Puissance, pièces, pets, rebirths et monde conservés |
| 18 | Regarde la console serveur | `[DataManager]`, `[CollectSystem]`, `[WorldFactory]`… sans erreur |

---

## 8. Sécurité (anti-exploit)

* **Autorité serveur** : puissance, pièces, rebirths, pets et succès sont
  calculés/validés uniquement côté serveur. `ProfileUpdated` est le seul canal
  d'information vers le client.
* **Clics** : `CollectSystem.tryCollect` vérifie que l'objet existe réellement
  dans le registre, que le joueur est bien dans le monde de l'objet, que la
  distance ≤ `ClickRadius` et qu'il n'y a pas de flood (bucket de 22 req/s).
* **Œufs** : tirage RNG serveur, prix débité côté serveur, uid générés côté
  serveur, 12 ouvertures/s maximum, plafond d'inventaire (200 pets).
* **Équipement/fusion** : vérifie la possession réelle (uid), le nombre
  d'emplacements, l'unicité des pets et le niveau maximal.
* **Sauvegarde** : verrou de session (`UpdateAsync` + `jobId`), refus d'écraser
  les données d'un autre serveur actif, copie de secours et **mode invité**
  (sauvegarde bloquée) si le chargement échoue → aucune perte possible.
* **Monétisation** : `ProcessReceipt` idempotent (`PurchaseId`), vérification
  des game passes serveur (`UserOwnsGamePassAsync`).

---

## 9. Performance (mobile)

* Objets actifs **par monde** : 90 si des joueurs y sont, **34 sinon** (les
  mondes vides sont vidés automatiquement).
* `StreamingEnabled = true` + `RequestStreamAroundAsync` avant chaque
  téléportation (pas de chute dans le vide).
* Particules/animation des objets : **client uniquement**, limitées aux objets à
  moins de 200 studs (70 max) et désactivables dans les réglages.
* Effets réseau : **un seul** remote par absorption (pas un par objet lors d'un
  aspirateur), notifications throttlées à 10/s par joueur.
* UI : aucune reconstruction périodique (seules les valeurs changent), `UIScale`
  adapté au viewport, 1 seule modale affichée à la fois.
* Aucun `while true do end` sans `task.wait` ; boucles serveur regroupées.

---

## 10. Monétisation (facultative, 3 minutes)

Le jeu est **100 % jouable gratuitement** ; tout est déjà branché, il ne manque
que tes IDs.

1. Va sur <https://create.roblox.com> → `Monetization` → **Passes** →
   crée les 5 passes (`Double Puissance`, `Auto Collect`, `Slots de Pets +3`,
   `VIP`, `Effets Exclusifs`).
2. `Monetization` → **Developer Products** → crée les 4 produits
   (`Boost ×3`, `Pack de pièces`, `Méga Pack`, `Œuf Chanceux`).
3. Copie les IDs dans `src/ReplicatedStorage/Modules/GameConfig.lua` :

```lua
GameConfig.GamePasses.DoublePower.Id = 123456789
GameConfig.DeveloperProducts.CoinPack.Id = 987654321
```

4. Rebranche / régénère le `.rbxlx` : l'onglet **👑 Game Passes** et
   **🚀 Boosts** de la boutique deviennent actifs.
   Tant que les IDs valent `0`, un message « non configuré » s'affiche et aucune
   erreur n'est levée.

**Musique** : renseigne `GameConfig.Worlds[i].MusicId = "rbxassetid://..."` pour
ajouter une musique par monde (sinon le jeu reste silencieux côté musique, sans
erreur). Les effets sonores, eux, utilisent des sons **natifs Roblox**
(`rbxasset://sounds/...`) : rien à importer.

---

## 11. Limites assumées (honnêteté)

* Les **modèles 3D** des pets et les **décors** sont générés à partir de
  primitives (pas de mesh custom) : c'est propre, léger et versionnable, mais
  moins détaillé qu'un pack d'assets acheté.
* Pas de **musique** par défaut (aucun asset audio embarqué) : emplacement prévu
  dans `GameConfig.Worlds[i].MusicId`.
* Pas de **badge/leaderboard Roblox natif** ni de **GlobalDataStore pour les
  events** : le classement mondial utilise `OrderedDataStore`.
* La **taille du personnage** utilise `Model:ScaleTo` (R6 et R15). Les
  accessoires très particuliers peuvent se déformer légèrement.
* Les **Game Passes/Products** nécessitent la création des IDs (étape 10) et
  l'activation des API en Studio pour être testés.
* Le **classement leaderstats** affiche la puissance dans un `IntValue` : au-delà
  de 2,1 milliards, le tableau natif plafonne (l'UI du jeu, elle, affiche la
  vraie valeur).

---

## 12. Outils de développement

```bash
# Vérifie la syntaxe Luau des 39 fichiers (nécessite Node)
npm i luau-parser && node tools/check_luau.js

# Régénère le fichier de place
python3 tools/build_rbxlx.py

# Vérifie la cohérence du GameConfig (pets/œufs/mondes/raretés)
python3 tools/validate_config.py
```

---

## 13. Idées pour aller plus loin

* Îles secrètes / boss à absorber en équipe
* Trading de pets entre joueurs (attention : DataStore + anti-duplication)
* Missions journalières et pass de saison
* Plus de pets et d'œufs : il suffit d'ajouter une entrée dans `GameConfig`
  (tout le reste — UI, tirages, fusion, affichage — s'adapte automatiquement)
* Codes promotionnels (DataStore + UI dédiée)

Bon développement — et n'oublie pas : **absorbe tout**. 🌀

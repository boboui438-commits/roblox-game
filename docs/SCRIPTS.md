# 📜 Documentation script par script

Pour chaque fichier : **nom exact**, **emplacement dans Roblox Studio**,
**rôle**, **connexions** et **comment le tester**.

Convention de nommage (compatible Rojo et avec `tools/build_rbxlx.py`) :

| Suffixe du fichier | Type d'instance | Nom dans l'Explorer |
|---|---|---|
| `Foo.server.lua` | `Script` | `Foo` |
| `Foo.client.lua` | `LocalScript` | `Foo` |
| `Foo.lua` | `ModuleScript` | `Foo` |

---

## 1. ReplicatedStorage.Modules (partagé client + serveur)

### `GameConfig` — ModuleScript
- **Emplacement** : `ReplicatedStorage.Modules.GameConfig`
- **Rôle** : la seule source de vérité pour l'équilibrage. Objets, 10
  transformations, 7 raretés, 26 pets, 7 œufs, 6 mondes (+ leurs objets), 6
  événements, 24 succès, récompenses quotidiennes, titres, Game Passes et
  Developer Products, et tous les réglages de collecte/rebirth.
- **Connexions** : requis par **tous** les autres modules. Le serveur l'utilise
  pour valider, le client pour afficher.
- **Test** : modifie `ObjectTypes.Trash.Power = 10`, relance : chaque déchet
  donne 10 ⚡. Modifie `Transformations[2].MinPower = 10` : tu passes Beginner
  après 10 ⚡.

### `Formulas` — ModuleScript
- **Emplacement** : `ReplicatedStorage.Modules.Formulas`
- **Rôle** : toutes les maths du jeu — `formatNumber` (1.23K, 4.5M…),
  `getTransformIndex`, `rebirthCost`, `rebirthMultiplier`, `petMultiplier`,
  `totalPowerMultiplier`, `upgradeCost`, `autoCollectRadius`,
  `vacuumRadius/Cooldown`, `walkSpeed`, `eggDisplayOdds`, `objectPower`.
- **Connexions** : `CollectSystem`, `DataManager`, `PetSystem`, `ShopSystem`,
  `RebirthSystem`, `DailyRewardSystem`, et côté client `HudUI`, `PetsUI`,
  `RebirthUI`, `ClientState`.
- **Test** : dans la barre de commande Studio (côté serveur) :
  ```lua
  local M = game.ReplicatedStorage.Modules
  print(require(M.Formulas).formatNumber(1234567)) -- 1.23M
  print(require(M.Formulas).rebirthCost(10))       -- coût du rebirth 11
  ```

### `Net` — ModuleScript
- **Emplacement** : `ReplicatedStorage.Modules.Net`
- **Rôle** : déclare la liste **complète** des RemoteEvents/RemoteFunctions et
  les crée côté serveur (`Net.init()`), les attend côté client (`Net.event()`,
  `Net.func()`). Ajouter un remote = ajouter une ligne dans `Net.RemoteEvents`.
- **Connexions** : appelé par `Bootstrap` (init) et par tous les systèmes.
- **Test** : après Play, `ReplicatedStorage.Remotes.Events` doit contenir
  31 RemoteEvents (16 client→serveur, 15 serveur→client) et
  `Remotes.Functions` 3 RemoteFunctions.

### `ProfileTemplate` — ModuleScript
- **Emplacement** : `ReplicatedStorage.Modules.ProfileTemplate`
- **Rôle** : structure d'une sauvegarde (`new()`), **migration et validation**
  (`migrate()`) — corrige les valeurs corrompues, supprime les pets inconnus,
  déduplique les uid, plafonne les niveaux — et version « publique »
  (`toPublic()`) envoyée au client (sans les champs internes).
- **Connexions** : `DataManager` (serveur), `ClientState` (valeurs par défaut
  côté client).
- **Test** : dans un serveur de test, écris une sauvegarde bidon avec un pet
  inexistant `{uid="x", id="Nope", level=99}` → au chargement, le pet est ignoré
  et un avertissement n'apparaît pas côté client.

### `Signal` — ModuleScript
- **Emplacement** : `ReplicatedStorage.Modules.Signal`
- **Rôle** : mini implémentation de signaux (`Connect`, `Fire`, `Once`,
  `DisconnectAll`) avec `pcall` dans les écouteurs pour qu'une erreur d'un
  listener ne casse pas le système.
- **Connexions** : `DataManager.Events`, `CollectSystem.Events`,
  `WorldManager.Events`, `EventManager.Events`, `PetSystem.Events`,
  `ClientState.Signals`.
- **Test** : `local S = require(...Signal).new(); S:Connect(function(v) print(v) end); S:Fire("ok")`.

### `Util` — ModuleScript
- **Emplacement** : `ReplicatedStorage.Modules.Util`
- **Rôle** : `deepCopy`, `deepMerge`, `weightedChoice` (tirages pondérés),
  `pickRandom`, `indexOf`, `removeValue`, `generateUid` (base36),
  `isValidNumber` (anti-NaN/infini), `debugTable`.
- **Test** : `Util.weightedChoice({A=99, B=1}, Random.new(1))` → renvoie presque
  toujours `A`.

---

## 2. ServerScriptService

### `Bootstrap` — Script
- **Emplacement** : `ServerScriptService.Bootstrap`
- **Rôle** : **point d'entrée unique**. 1) `Net.init()`, 2) `WorldFactory.buildAll()`,
  3) `start()` de chaque système dans l'ordre, 4) `DataManager.start()` **en
  dernier** (pour que tous les systèmes écoutent déjà `Loaded`), 5) `BindToClose`.
- **Connexions** : c'est lui qui instancie tout le reste.
- **Test** : la console doit afficher `===== NOOB TO GOD SIMULATOR v4 — démarrage =====`,
  `[WorldFactory] Map générée en …s`, chaque `[Système] Démarré`, puis
  `===== … prêt (12 systèmes actifs) =====`. Aucune ligne `❌`/`warn`.

### `DataManager` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.DataManager`
- **Rôle** : **toute la persistance**. Chargement (5 tentatives + backoff),
  verrou de session (`UpdateAsync` + `jobId`, anti-duplication entre serveurs),
  migration, `leaderstats`, autosave 60 s, sauvegarde à la déconnexion et à la
  fermeture, copie de secours (`_Backup`), **mode invité** (sauvegarde bloquée)
  si le chargement échoue + nouvelle tentative en arrière-plan.
  API : `getProfile`, `waitForProfile`, `addPower`, `addCoins`, `spendCoins`,
  `addStat`, `setStat`, `notify`, `save`, `getPowerMultiplier`.
- **Connexions** : requis par **tous** les systèmes serveur ; expose
  `Events.Loaded/Unloaded/Changed/PowerGained/Rebirth`.
- **Test** :
  1. Studio → `Security` → *Enable Studio Access to API Services*.
  2. Joue, absorbe, attends 5 s, **Stop**, relance : puissance conservée.
  3. Coupe l'accès API : console affiche `chargement impossible … mode invité`
     et le joueur peut jouer sans risquer d'écraser sa sauvegarde.

### `WorldFactory` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.WorldFactory`
- **Rôle** : génère **toute la map depuis du code** : lobby (sol, spawn, autel de
  rebirth, 6 portails, œuf gratuit, panneau du jeu, tableau des scores, statues)
  et les 6 mondes (plateforme, murs invisibles anti-chute, pad de retour,
  piédestal d'œuf, décor thématique : palmiers, bonbons, volcans, astéroïdes,
  cubes glitch, colonnes divines). Expose `getWorldInfo(i)` (centre, spawn, zone
  de spawn des objets) et `buildAll()`.
- **Connexions** : `Bootstrap` (construction), `CollectSystem` (zones),
  `WorldManager` (portails), `LeaderboardManager` (panneau), `RebirthSystem`.
- **Test** : après Play, `Workspace.Lobby` et `Workspace.Worlds.World1..6`
  existent ; `Workspace.Fallback` a disparu ; aucun joueur ne tombe dans le vide
  (murs invisibles à ±350 studs).

### `CollectSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.CollectSystem`
- **Rôle** : cœur du gameplay. Fait apparaître les objets par monde (pool
  dynamique 90/34), traite `CollectRequest` **avec validation** (registre,
  distance, monde, rate limit 22/s), gère l'**absorption automatique** (boucle
  0,25 s) et l'**aspirateur de zone** (cooldown serveur), récompense puissance +
  pièces, déclenche les effets, et rafraîchit les objets (respawn 6 s).
- **Connexions** : `DataManager` (autorité), `Formulas` (valeurs/rayons),
  `WorldFactory` (zones), `EventManager` (chance d'objets dorés via
  `CollectSystem.goldenChance`), `WorldManager` (occupation des mondes).
- **Test** : clique un objet → il disparaît et réapparaît ailleurs ~6 s plus
  tard. Envoie une fausse requête depuis la console client
  (`Net.event("CollectRequest"):FireServer(workspace.Collectibles:GetChildren()[1])`
  depuis un objet à 500 studs) → refusée (aucun gain).

### `PetSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.PetSystem`
- **Rôle** : **tirages d'œufs** (RNG serveur pondéré, raretés améliorées pendant
  *Lucky Time*), prix et prérequis, génération d'uid, inventaire (max 200),
  équipement (limite d'emplacements), `EquipBestPets`, **fusion** de 3 pets
  identiques de même niveau (max niveau 10), attribution d'un pet garanti
  (Developer Product), annonces des pets Mythical/Secret à tout le serveur.
- **Connexions** : `DataManager`, `Formulas`, `GameConfig`, `MonetizationSystem`,
  `EventManager` (`PetSystem.luckyMultiplier`), UI via remotes.
- **Test** : `OpenEgg("BasicEgg", 3)` depuis l'UI → 3 révélations, pièces
  débitées une fois. Collectionne 3 mêmes pets, `FUSIONNER` → 1 pet niveau 2
  (multiplicateur ×1.25). Équipe 4 pets avec 3 emplacements → refusé.

### `RebirthSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.RebirthSystem`
- **Rôle** : rebirth validé serveur (coût `2500 × 1.85^n`, max 40), remise à zéro
  de la puissance, multiplicateur permanent, pièces, déblocage de titres tous les
  5 rebirths, annonce à tout le serveur, effets.
- **Connexions** : `DataManager`, `WorldManager.checkUnlocks`,
  `CharacterSystem.refresh`, `AchievementSystem`.
- **Test** : avec 2 500 ⚡, clique Rebirth → puissance 0, `×1.35` affiché,
  `+425` pièces, tout le serveur reçoit la notification.

### `CharacterSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.CharacterSystem`
- **Rôle** : applique la **transformation** au personnage : `Model:ScaleTo`
  (taille par tier), aura en particules, lumière, traînée (tier ≥ 4 ou
  cosmétique), titre au-dessus de la tête avec la puissance, vitesse de
  déplacement (amélioration), et **mode Géant** (`sizeMultiplier`). Réapplique
  tout après un respawn.
- **Connexions** : `DataManager` (profil), `Formulas` (tier/vitesse),
  `EventManager` (Giant Mode), `RebirthSystem`, `SettingsSystem` (titre).
- **Test** : atteins 1 000 ⚡ → le personnage grandit, une aura verte apparaît,
  un son de transformation joue, le titre au-dessus de la tête change.

### `WorldManager` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.WorldManager`
- **Rôle** : voyages validés (`TravelWorld`), placement du personnage après
  spawn, `RequestStreamAroundAsync` avant téléportation, portails (Touched) et
  pads de retour, **déblocage automatique** des mondes (puissance + rebirths),
  comptage des joueurs par monde (utilisé pour n'activer les objets que dans les
  mondes occupés).
- **Connexions** : `WorldFactory`, `CollectSystem`, `DataManager`.
- **Test** : marche sur le portail 2 avec < 1 500 ⚡ → rien (message). Dépasse
  1 500 ⚡ → toast « Candy World débloqué » puis le portail fonctionne.

### `EventManager` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.EventManager`
- **Rôle** : lance un événement aléatoire toutes les 5 min pendant 45–75 s :
  Giant Mode (taille ×1.8, puissance ×1.5), Money Rain (pièces physiques qui
  tombent), Low Gravity (gravité /4), Golden Objects (objets dorés ×5),
  Chaos Mode (mini-effets en chaîne), Lucky Time (gains ×2, pets rares ×2).
  Diffuse `EventUpdate` (id + fin) et nettoie **toujours** ses effets.
- **Connexions** : `CollectSystem` (`goldenChance`), `CharacterSystem`
  (`sizeMultiplier`), `PetSystem` (`luckyMultiplier`), `DataManager`
  (`eventMultiplier`), HUD via `EventUpdate`.
- **Test** : réduis `GameConfig.EventInterval = 20` et `EventDuration = 10`,
  relance : enchaînement rapide, bannière + compte à rebours, gravité restaurée à
  la fin (196.2).

### `LeaderboardManager` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.LeaderboardManager`
- **Rôle** : classement **serveur** (tri en mémoire, top 25) et **mondial**
  (`OrderedDataStore`, top 25, noms mis en cache), mise à jour du panneau
  SurfaceGui du lobby (top 10) et push `LeaderboardData` toutes les 8 s.
- **Connexions** : `DataManager`, `Net` (`GetLeaderboards`).
- **Test** : à 2 joueurs, le plus puissant est 1er dans 🏆 ; le panneau du lobby
  se met à jour en ~8 s.

### `SettingsSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.SettingsSystem`
- **Rôle** : paramètres joueur (7 booléens whitelistés), sélection de titre
  (uniquement les titres débloqués), `ClientReady`, `GetProfile`, `GetServerInfo`,
  comparaison de puissance et emotes (`PlayEmote`).
- **Connexions** : `DataManager`, `CharacterSystem` (titre), `Net`.
- **Test** : décoche « Particules » → l'effet s'applique et reste après un
  rejoin. Choisis un titre verrouillé → refusé silencieusement.

### `ShopSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.ShopSystem`
- **Rôle** : achats d'améliorations (`PowerMult`, `CoinMult`, `AutoCollect`,
  `Vacuum`, `WalkSpeed`, `PetSlots`) avec vérification du niveau max, du prix et
  débit **atomique** des pièces, anti-spam 5 achats/s.
- **Connexions** : `DataManager.spendCoins`, `PetSystem.validateEquipped`,
  `CharacterSystem.refresh`.
- **Test** : achète `WalkSpeed` → vitesse 17,5 ; `PetSlots` → 4 emplacements
  immédiatement utilisables ; spam du bouton → plafonné.

### `AchievementSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.AchievementSystem`
- **Rôle** : vérifie les 24 succès toutes les 2 s à partir des statistiques
  réelles, accorde la récompense en pièces, notifie, et expose `getList()`
  (progressions) pour l'UI.
- **Connexions** : `DataManager.addStat` (rempli par `CollectSystem`,
  `PetSystem`, `RebirthSystem`, `DailyRewardSystem`, `WorldManager`).
- **Test** : absorbe 1 objet → « Premier succès » + 50 pièces ; 100 objets →
  « Petit glouton ».

### `DailyRewardSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.DailyRewardSystem`
- **Rôle** : récompense quotidienne sur 7 jours (série, cooldown 20 h, boost ou
  œuf offert le 5e/7e jour) et **gains hors-ligne** plafonnés à 8 h si
  l'absorption automatique est débloquée.
- **Connexions** : `DataManager`, `PetSystem` (œuf offert), HUD via
  `DailyAvailable`/`BoostUpdate`.
- **Test** : réclame → +250 pièces ; relance → bouton « ⏳ dans 20:00 » ;
  simule une absence en modifiant `daily.lastClaim` dans le DataStore.

### `MonetizationSystem` — ModuleScript
- **Emplacement** : `ServerScriptService.Systems.MonetizationSystem`
- **Rôle** : vérifie les **Game Passes** (`UserOwnsGamePassAsync`, appliqués par
  `Formulas.totalPowerMultiplier` et les slots de pets) et traite les
  **Developer Products** (`ProcessReceipt` idempotent : boost ×3, packs de
  pièces, œuf légendaire garanti). Désactivé proprement si les IDs valent `0`.
- **Connexions** : `DataManager`, `PetSystem`, `GameConfig`.
- **Test** : IDs à 0 → la boutique affiche « non configuré » ; après ajout des
  IDs et publication, achète un pack de pièces → crédité une seule fois.

---

## 3. StarterPlayer.StarterPlayerScripts (client)

### `ClientController` — LocalScript (entrée)
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.ClientController`
- **Rôle** : démarre l'UI, les contrôleurs d'effets/sons/pets, branche **tous**
  les remotes sur `ClientState`, gère la **collecte** (raycast au clic, tap,
  maintien = auto-clic 11/s, secours « objet le plus proche » à 48 studs),
  envoie `ClientReady` + `GetProfile`.
- **Connexions** : `Net`, `ClientState`, `UIController`, `EffectsController`,
  `PetFollowController`, `SoundController`.
- **Test** : clique dans le vide près d'un objet → il est quand même absorbé ;
  clique sur un bouton d'UI → **aucune** absorption (le clic est « game
  processed »).

### `Controllers/ClientState` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.Controllers.ClientState`
- **Rôle** : miroir local du profil + état (monde, event, classements, boost,
  cooldown) et signaux (`Profile`, `Event`, `World`, `EggResult`, `Boost`…).
  Fournit des getters d'affichage (`getTier`, `getTierProgress`,
  `getPowerMultiplier`, `getPetSlots`, `isWorldUnlocked`…).
- **Test** : dans la console client, `State.getTier().Name` doit correspondre au
  tier affiché dans le HUD.

### `Controllers/EffectsController` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.Controllers.EffectsController`
- **Rôle** : explosions de particules + nombres flottants à chaque absorption,
  flash d'écran, **secousse de caméra** (RenderStep), fondu au changement de
  monde, **ambiance par monde** (Atmosphere/brouille locale), animation des
  objets proches (flottement/rotation, 70 max à 200 studs) et des portails.
- **Test** : coupe « Effets visuels » dans Réglages → plus de particules ni de
  flottement, mais la collecte fonctionne.

### `Controllers/PetFactory` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.Controllers.PetFactory`
- **Rôle** : construit un pet 3D à partir de primitives (corps selon la forme,
  tête, yeux, ailes si Rare+, couronne si Légendaire+, particules si Mythique+,
  lumière, étiquette nom/rareté/multiplicateur). Aucune asset.
- **Test** : `require(...PetFactory).create("GalaxyDragon", 3).Parent = workspace` →
  un dragon violet lumineux apparaît à l'origine.

### `Controllers/PetFollowController` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.Controllers.PetFollowController`
- **Rôle** : instancie/supprime les modèles selon les pets équipés (clé = uid,
  recréé si le niveau change), les fait tourner autour du joueur avec lissage,
  respecte le réglage « Afficher mes pets ».
- **Test** : équipe 3 pets → 3 modèles qui orbitent ; change de monde → ils
  suivent ; décoche le réglage → disparaissent.

### `Controllers/SoundController` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.Controllers.SoundController`
- **Rôle** : 20 sons (absorption, doré, vacuum, téléport, rebirth, achat,
  succès, événement…) via des **sons natifs Roblox**, volume/pitch aléatoire
  léger, musique par monde si `MusicId` est renseigné, respecte les réglages.
- **Test** : coupe « Effets sonores » → silence total hors musique.

### `UI/UIController` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.UI.UIController`
- **Rôle** : crée le **ScreenGui `MainUI`** (ResetOnSpawn, IgnoreGuiInset),
  l'écran de chargement, la pile de toasts, le HUD, gère la **pile de modales**
  (une seule ouverte) et leur rafraîchissement (2×/s, sans reconstruction), et
  la **révélation animée** des pets obtenus.
- **Test** : ouvre Boutique puis Œufs → la première se ferme ; l'écran de
  chargement disparaît dès le profil reçu.

### `UI/UILib` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.UI.UILib`
- **Rôle** : bibliothèque maison : `panel`, `card`, `button` (survol/press
  animés + son), `iconButton`, `label`, `title`, `bar`/`setBar`, `list`, `grid`,
  `scroll`, `modal`/`showModal`/`closeModal`, `toast`, `pulse`,
  `animateNumber`, `gradient`, `stroke`, `padding`, `tween`.
- **Test** : n'importe quel écran sert de démo ; `UILib.toast("Test")` depuis la
  console client affiche un toast.

### `UI/UIConfig` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.UI.UIConfig`
- **Rôle** : thème (palette, polices natives, rayons, tailles de modales) +
  `toHex`/`fromHex`.
- **Test** : change `Colors.Gold` → toute l'UI change de couleur d'accent.

### `UI/HudUI` — ModuleScript
- **Emplacement** : `StarterPlayer.StarterPlayerScripts.UI.HudUI`
- **Rôle** : HUD permanent — carte Puissance (compteur animé + multiplicateur),
  Pièces, Rebirths, barre de transformation, bannière d'événement avec compte à
  rebours, 9 boutons (Boutique, Œufs, Pets, Rebirth, Mondes, Classement, Succès,
  Quotidien, Réglages), bouton ASPIRER avec recharge, indicateurs auto-collect et
  boost. `UIScale` recalculé selon le viewport.
- **Test** : redimensionne la fenêtre → l'UI reste lisible ; attends un
  événement → la bannière apparaît et décompte.

### `UI/ShopUI` — ModuleScript
- **Rôle** : boutique à 3 onglets (Améliorations / Game Passes / Boosts) avec
  prix, niveau, boutons d'achat et états (abordable, maxé, possédé).
- **Test** : bouton grisé sans pièces, actif dès assez de pièces ; achats
  immédiatement reflétés dans le HUD.

### `UI/PetsUI` — ModuleScript
- **Rôle** : onglet **Œufs** (prix, prérequis, **probabilités de chaque rareté**,
  Ouvrir / Ouvrir ×3) et onglet **Inventaire** (tri par rareté/niveau,
  emplacements X/Y, équiper/retirer, fusion 3 identiques, « meilleurs pets »).
- **Test** : pourcentages affichés = ceux du serveur (`Formulas.eggDisplayOdds`) ;
  `MEILLEURS` équipe bien les plus gros multiplicateurs.

### `UI/RebirthUI` — ModuleScript
- **Rôle** : carte de rebirth (niveau actuel/max, multiplicateur actuel → suivant,
  coût, progression, récompense), explication, paliers de titres.
- **Test** : la barre se remplit à mesure que tu collectes ; le bouton devient
  rose à 100 %.

### `UI/WorldsUI` — ModuleScript
- **Rôle** : liste des 6 mondes + lobby, prérequis, valeur des objets, œuf du
  monde, bouton Voyager (état : débloqué / verrouillé / « tu es ici »).
- **Test** : le monde courant est marqué, les autres affichent leurs prérequis.

### `UI/LeaderboardUI` — ModuleScript
- **Rôle** : onglets « Ce serveur » / « Mondial », médailles, surlignage de ta
  ligne, rafraîchissement via le signal (scroll préservé).
- **Test** : à 2 joueurs, le classement serveur se réordonne en < 8 s.

### `UI/AchievementsUI` — ModuleScript
- **Rôle** : 24 succès avec icône, description, barre de progression et
  récompense ; compteur global en haut.
- **Test** : la progression augmente en temps réel pendant que tu absorbes.

### `UI/SettingsUI` — ModuleScript
- **Rôle** : 7 interrupteurs (musique, sons, effets, particules, secousse,
  nombres flottants, pets visibles), sélection de titre, bloc de statistiques
  détaillées.
- **Test** : chaque toggle persiste après reconnexion (sauvegardé serveur).

### `UI/DailyUI` — ModuleScript
- **Rôle** : 7 cartes de récompense (jour courant surligné, jours réclamés/à
  venir), bouton avec cooldown, série en cours.
- **Test** : après réclamation, le bouton passe en « ⏳ DANS 20:00 ».

---

## 4. Ordre de démarrage (à respecter si tu réorganises)

```
Bootstrap
 ├─ Net.init()
 ├─ WorldFactory.buildAll()
 ├─ CollectSystem.start()      -- remotes de collecte + spawn des objets
 ├─ CharacterSystem.start()
 ├─ PetSystem.start()
 ├─ ShopSystem.start()
 ├─ RebirthSystem.start()
 ├─ AchievementSystem.start()
 ├─ DailyRewardSystem.start()
 ├─ EventManager.start()
 ├─ LeaderboardManager.start()
 ├─ SettingsSystem.start()
 ├─ MonetizationSystem.start()
 ├─ WorldManager.start()
 └─ DataManager.start()       -- EN DERNIER : charge les joueurs
BindToClose → DataManager.shutdown()
```

**Pourquoi DataManager en dernier ?** Parce qu'il déclenche `Events.Loaded` pour
chaque joueur : si les autres systèmes n'ont pas encore connecté leurs écouteurs,
ils manquent l'événement et le joueur ne reçoit ni son profil ni ses récompenses
quotidiennes.

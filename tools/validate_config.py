#!/usr/bin/env python3
"""
Vérifie la cohérence de GameConfig.lua sans avoir à lancer Roblox :

 • chaque pet référencé dans un œuf existe
 • chaque rareté utilisée existe
 • chaque objet de monde existe dans WorldObjectTypes / ObjectTypes
 • Objects et ObjectWeights d'un monde décrivent les mêmes clés
 • chaque œuf de monde et de EggOrder existe
 • chaque statistique utilisée par un succès existe

Utilisation :  python3 tools/validate_config.py
Code de sortie 1 si une incohérence est trouvée.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "ReplicatedStorage", "Modules", "GameConfig.lua")


def read_config() -> str:
    with open(CONFIG, encoding="utf-8") as handle:
        return handle.read()


def table_block(source: str, name: str) -> str:
    start = source.index("GameConfig.%s = {" % name)
    begin = source.index("{", start)
    depth = 0
    for index in range(begin, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[begin:index + 1]
    raise ValueError("bloc non terminé : " + name)


def child_keys(block: str):
    return set(re.findall(r"\n\t(\w+)\s*=\s*\{", block))


def main() -> int:
    source = read_config()
    problems = []

    pet_ids = child_keys(table_block(source, "Pets"))
    rarities = child_keys(table_block(source, "Rarities"))
    eggs_block = table_block(source, "Eggs")
    egg_ids = child_keys(eggs_block)
    object_types = child_keys(table_block(source, "WorldObjectTypes")) | child_keys(table_block(source, "ObjectTypes"))
    worlds_block = table_block(source, "Worlds")
    achievements = table_block(source, "Achievements")

    # 1) pets : rareté valide
    pets_block = table_block(source, "Pets")
    for pet, body in re.findall(r"\n\t(\w+)\s*=\s*\{(.*?)\n\t\}", pets_block, re.S):
        found = re.search(r'Rarity = "(\w+)"', body)
        if not found or found.group(1) not in rarities:
            problems.append("pet %s : rareté invalide" % pet)

    # 2) œufs : taux, pools, pets, raretés
    for egg, body in re.findall(r"\n\t(\w+)\s*=\s*\{(.*?)\n\t\},?\n", eggs_block, re.S):
        rates = re.search(r"Rates = \{([^}]*)\}", body)
        if not rates:
            problems.append("œuf %s : pas de Rates" % egg)
            continue
        rate_rarities = set(re.findall(r"(\w+)\s*=", rates.group(1)))
        for rarity in rate_rarities:
            if rarity not in rarities:
                problems.append("œuf %s : rareté inconnue %s" % (egg, rarity))
        pool = re.search(r"Pool = \{(.*)", body, re.S)
        if not pool:
            problems.append("œuf %s : pas de Pool" % egg)
            continue
        for rarity, pet_list in re.findall(r"\n\t\t\t(\w+) = \{([^}]*)\}", pool.group(1)):
            if rarity not in rate_rarities:
                problems.append("œuf %s : pool %s sans taux correspondant" % (egg, rarity))
            for pet in re.findall(r'"(\w+)"', pet_list):
                if pet not in pet_ids:
                    problems.append("œuf %s : pet inconnu %s" % (egg, pet))

    # 3) mondes : objets, poids, œuf
    for index, body in re.findall(r"\n\t\tIndex = (\d+),(.*?)\n\t\}", worlds_block, re.S):
        objects = re.search(r"Objects = \{([^}]*)\}", body)
        weights = re.search(r"ObjectWeights = \{([^}]*)\}", body)
        egg = re.search(r'Egg = "(\w+)"', body)
        if objects:
            object_keys = set(re.findall(r'"(\w+)"', objects.group(1)))
            for object_id in object_keys:
                if object_id not in object_types:
                    problems.append("monde %s : objet inconnu %s" % (index, object_id))
            if weights:
                weight_keys = set(re.findall(r"(\w+)\s*=\s*\d", weights.group(1)))
                if object_keys != weight_keys:
                    problems.append(
                        "monde %s : Objects / ObjectWeights différents (%s)"
                        % (index, sorted(object_keys ^ weight_keys))
                    )
        if egg and egg.group(1) not in egg_ids:
            problems.append("monde %s : œuf inconnu %s" % (index, egg.group(1)))

    # 4) EggOrder
    for order_block in re.findall(r"GameConfig\.EggOrder = \{([^}]*)\}", source):
        for egg in re.findall(r'"(\w+)"', order_block):
            if egg not in egg_ids:
                problems.append("EggOrder : œuf inconnu %s" % egg)

    # 5) succès : statistiques valides
    valid_stats = {
        "collected", "eggsOpened", "legendaryPets", "mythicalPets", "secretPets",
        "fusions", "vacuums", "dailies", "events", "streak", "rebirths",
        "bestPower", "maxWorld",
    }
    for stat in re.findall(r'Stat = "(\w+)"', achievements):
        if stat not in valid_stats:
            problems.append("succès : statistique inconnue %s" % stat)

    if problems:
        for problem in problems:
            print("❌ " + problem)
        print("\n%d incohérence(s) dans GameConfig." % len(problems))
        return 1

    print(
        "✅ GameConfig cohérent — %d pets, %d œufs, %d raretés, %d objets de monde."
        % (len(pet_ids), len(egg_ids), len(rarities), len(object_types))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

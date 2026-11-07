#!/usr/bin/env python3
"""
Génère un fichier de place Roblox (.rbxlx) directement ouvrable dans
Roblox Studio, à partir de l'arborescence `src/`.

    python3 tools/build_rbxlx.py            -> build/NoobToGodSimulator.rbxlx
    python3 tools/build_rbxlx.py --out X    -> fichier de sortie personnalisé

Convention de nommage des fichiers (identique à Rojo) :
    xxx.server.lua  -> Script      (suffixe retiré du nom)
    xxx.client.lua  -> LocalScript (suffixe retiré du nom)
    xxx.lua         -> ModuleScript

Arborescence source :
    src/ReplicatedStorage/...      -> ReplicatedStorage
    src/ServerScriptService/...    -> ServerScriptService
    src/StarterPlayer/StarterPlayerScripts/... -> StarterPlayer.StarterPlayerScripts
    src/StarterGui/...             -> StarterGui

Aucune dépendance externe (Python 3.8+ uniquement).
"""
from __future__ import annotations

import argparse
import os
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

SERVICE_MAP = {
    "ReplicatedStorage": "ReplicatedStorage",
    "ServerScriptService": "ServerScriptService",
    "StarterGui": "StarterGui",
}

_referent = 0


def next_referent() -> str:
    global _referent
    _referent += 1
    return "RBX%04X" % _referent


def xml_text(value: str) -> str:
    """Échappe une chaîne pour l'insérer dans un élément XML."""
    return escape(value, {'"': "&quot;"})


def add_props(parent: ET.Element, props: list[tuple[str, str, str]]) -> None:
    """props = [(tag, name, value)] ; tag ∈ string/bool/int/float/token/ProtectedString"""
    for tag, name, value in props:
        el = ET.SubElement(parent, tag)
        el.set("name", name)
        el.text = value


def script_kind(filename: str) -> tuple[str, str]:
    if filename.endswith(".server.lua"):
        return "Script", filename[: -len(".server.lua")]
    if filename.endswith(".client.lua"):
        return "LocalScript", filename[: -len(".client.lua")]
    if filename.endswith(".lua"):
        return "ModuleScript", filename[: -len(".lua")]
    raise ValueError("extension inattendue : " + filename)


def make_script_item(class_name: str, name: str, source: str) -> ET.Element:
    item = ET.Element("Item", {"class": class_name, "referent": next_referent()})
    props = ET.SubElement(item, "Properties")
    add_props(props, [
        ("string", "Name", name),
        ("ProtectedString", "Source", source),
        ("bool", "Disabled", "false"),
    ])
    if class_name == "Script":
        # 0 = Legacy (le script tourne uniquement côté serveur dans ServerScriptService)
        add_props(props, [("token", "RunContext", "0")])
    return item


def make_folder_item(name: str) -> ET.Element:
    item = ET.Element("Item", {"class": "Folder", "referent": next_referent()})
    props = ET.SubElement(item, "Properties")
    add_props(props, [("string", "Name", name)])
    return item


def add_directory(parent_item: ET.Element, directory: str) -> None:
    """Ajoute récursivement le contenu d'un dossier comme enfants d'un Item."""
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            folder = make_folder_item(entry)
            add_directory(folder, path)
            parent_item.append(folder)
        elif entry.endswith(".lua"):
            class_name, name = script_kind(entry)
            with open(path, "r", encoding="utf-8") as handle:
                source = handle.read()
            parent_item.append(make_script_item(class_name, name, source))


def add_part_props(props: ET.Element, name: str, size, position, color, material=256,
                   transparency=0.0, anchored=True, can_collide=True) -> None:
    add_props(props, [("string", "Name", name)])

    frame = ET.SubElement(props, "CoordinateFrame")
    frame.set("name", "CFrame")
    for tag, value in zip(("X", "Y", "Z"), position):
        ET.SubElement(frame, tag).text = str(value)
    for row in range(3):
        for col in range(3):
            ET.SubElement(frame, "R%d%d" % (row, col)).text = "1" if row == col else "0"

    size_el = ET.SubElement(props, "Vector3")
    size_el.set("name", "Size")
    for tag, value in zip(("X", "Y", "Z"), size):
        ET.SubElement(size_el, tag).text = str(value)

    r, g, b = color
    packed = (int(r) & 0xFF) | ((int(g) & 0xFF) << 8) | ((int(b) & 0xFF) << 16) | (255 << 24)
    add_props(props, [
        ("Color3uint8", "Color3uint8", str(packed)),
        ("token", "Material", str(material)),
        ("bool", "Anchored", "true" if anchored else "false"),
        ("bool", "CanCollide", "true" if can_collide else "false"),
        ("bool", "Locked", "false"),
        ("float", "Transparency", str(transparency)),
    ])


def build_workspace() -> ET.Element:
    item = ET.Element("Item", {"class": "Workspace", "referent": next_referent()})
    props = ET.SubElement(item, "Properties")
    add_props(props, [
        ("string", "Name", "Workspace"),
        ("bool", "StreamingEnabled", "true"),
        ("int", "StreamingMinRadius", "256"),
        ("int", "StreamingTargetRadius", "1024"),
        ("bool", "FilteringEnabled", "true"),
        ("float", "Gravity", "196.2"),
        ("float", "FallenPartsDestroyHeight", "-300"),
    ])

    # --- Filet de sécurité : sol + spawn si le générateur de map échouait ---
    fallback = make_folder_item("Fallback")
    props = fallback.find("Properties")

    baseplate = ET.SubElement(fallback, "Item", {"class": "Part", "referent": next_referent()})
    base_props = ET.SubElement(baseplate, "Properties")
    add_part_props(base_props, "Baseplate", (400, 4, 400), (0, -2, 0), (120, 200, 255), material=272)

    spawn = ET.SubElement(fallback, "Item", {"class": "SpawnLocation", "referent": next_referent()})
    spawn_props = ET.SubElement(spawn, "Properties")
    add_part_props(spawn_props, "LobbySpawn", (24, 1, 24), (0, 1, 90), (90, 220, 255), material=288,
                   transparency=0.35, can_collide=True)
    add_props(spawn_props, [
        ("bool", "Neutral", "true"),
        ("float", "Duration", "0"),
        ("bool", "AllowTeamChangeOnTouch", "false"),
    ])
    item.append(fallback)
    return item


def build_lighting() -> ET.Element:
    item = ET.Element("Item", {"class": "Lighting", "referent": next_referent()})
    props = ET.SubElement(item, "Properties")

    def color(name: str, rgb):
        el = ET.SubElement(props, "Color3")
        el.set("name", name)
        for tag, value in zip(("R", "G", "B"), rgb):
            ET.SubElement(el, tag).text = "%.4f" % (value / 255.0)

    add_props(props, [
        ("string", "Name", "Lighting"),
        ("float", "Brightness", "2.5"),
        ("float", "ClockTime", "14"),
        ("float", "GeographicLatitude", "41.7"),
        ("bool", "GlobalShadows", "true"),
        ("bool", "Outlines", "false"),
        ("float", "EnvironmentDiffuseScale", "0.4"),
        ("float", "EnvironmentSpecularScale", "0.4"),
        ("float", "ExposureCompensation", "0"),
        ("float", "FogStart", "0"),
        ("float", "FogEnd", "5000"),
    ])
    color("Ambient", (120, 130, 150))
    color("OutdoorAmbient", (140, 150, 170))
    color("FogColor", (200, 220, 255))

    atmosphere = ET.SubElement(item, "Item", {"class": "Atmosphere", "referent": next_referent()})
    atmo_props = ET.SubElement(atmosphere, "Properties")
    add_props(atmo_props, [
        ("string", "Name", "Atmosphere"),
        ("float", "Density", "0.32"),
        ("float", "Offset", "0.1"),
        ("float", "Glare", "0.2"),
        ("float", "Haze", "1.4"),
    ])
    for name, rgb in (("Color", (200, 220, 255)), ("Decay", (120, 150, 200))):
        el = ET.SubElement(atmo_props, "Color3")
        el.set("name", name)
        for tag, value in zip(("R", "G", "B"), rgb):
            ET.SubElement(el, tag).text = "%.4f" % (value / 255.0)
    return item


def build_players() -> ET.Element:
    item = ET.Element("Item", {"class": "Players", "referent": next_referent()})
    props = ET.SubElement(item, "Properties")
    add_props(props, [
        ("string", "Name", "Players"),
        ("bool", "CharacterAutoLoads", "true"),
        ("float", "RespawnTime", "3"),
    ])
    return item


def build() -> ET.Element:
    root = ET.Element("roblox", {
        "xmlns:xmime": "http://www.w3.org/2005/05/xmlmime",
        "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd",
        "version": "4",
    })

    root.append(build_workspace())
    root.append(build_lighting())
    root.append(build_players())

    # ReplicatedStorage.Modules
    if os.path.isdir(os.path.join(SRC, "ReplicatedStorage")):
        rs = ET.Element("Item", {"class": "ReplicatedStorage", "referent": next_referent()})
        props = ET.SubElement(rs, "Properties")
        add_props(props, [
            ("string", "Name", "ReplicatedStorage"),
            ("bool", "Disabled", "false"),
        ])
        add_directory(rs, os.path.join(SRC, "ReplicatedStorage"))
        root.append(rs)

    # ServerScriptService
    if os.path.isdir(os.path.join(SRC, "ServerScriptService")):
        sss = ET.Element("Item", {"class": "ServerScriptService", "referent": next_referent()})
        props = ET.SubElement(sss, "Properties")
        add_props(props, [
            ("string", "Name", "ServerScriptService"),
        ])
        add_directory(sss, os.path.join(SRC, "ServerScriptService"))
        root.append(sss)

    # StarterPlayer.StarterPlayerScripts
    starter_player_scripts = os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts")
    if os.path.isdir(starter_player_scripts):
        sp = ET.Element("Item", {"class": "StarterPlayer", "referent": next_referent()})
        props = ET.SubElement(sp, "Properties")
        add_props(props, [("string", "Name", "StarterPlayer")])

        sps = ET.SubElement(sp, "Item", {"class": "StarterPlayerScripts", "referent": next_referent()})
        sps_props = ET.SubElement(sps, "Properties")
        add_props(sps_props, [("string", "Name", "StarterPlayerScripts")])
        add_directory(sps, starter_player_scripts)
        root.append(sp)

    # StarterGui
    starter_gui = os.path.join(SRC, "StarterGui")
    if os.path.isdir(starter_gui) and os.listdir(starter_gui):
        sg = ET.Element("Item", {"class": "StarterGui", "referent": next_referent()})
        props = ET.SubElement(sg, "Properties")
        add_props(props, [("string", "Name", "StarterGui")])
        add_directory(sg, starter_gui)
        root.append(sg)

    return root


def indent(elem: ET.Element, level: int = 0) -> None:
    pad = "\n" + "  " * level
    if len(elem):
        if not (elem.text and elem.text.strip()):
            elem.text = pad + "  "
        for child in elem:
            indent(child, level + 1)
        if not (elem[-1].tail and elem[-1].tail.strip()):
            elem[-1].tail = pad
    elif level and not (elem.tail and elem.tail.strip()):
        elem.tail = pad


def main() -> int:
    parser = argparse.ArgumentParser(description="Génère un fichier .rbxlx depuis src/")
    parser.add_argument("--out", default=os.path.join(ROOT, "build", "NoobToGodSimulator.rbxlx"))
    args = parser.parse_args()

    if not os.path.isdir(SRC):
        print("❌ dossier src/ introuvable", file=sys.stderr)
        return 1

    root = build()
    indent(root)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write('<?xml version="1.0" encoding="utf-8"?>\n')
        handle.write(ET.tostring(root, encoding="unicode"))
        handle.write("\n")

    size_kb = os.path.getsize(args.out) / 1024.0
    print("✅ %s (%.1f Ko)" % (args.out, size_kb))
    return 0


if __name__ == "__main__":
    sys.exit(main())

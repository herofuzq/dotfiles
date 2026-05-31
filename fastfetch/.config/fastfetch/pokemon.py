#!/usr/bin/env python3
"""Pokefetch — 随机宝可梦精灵图 + fastfetch 系统信息"""

import json, re, os, random, subprocess, sys, tempfile

CONFIG_FILE = os.path.expanduser("~/.config/fastfetch/config.jsonc")

# ========== 宝可梦数据库（编号 + 名字） ==========
POKEDEX = {
    1: "bulbasaur", 2: "ivysaur", 3: "venusaur", 4: "charmander",
    5: "charmeleon", 6: "charizard", 7: "squirtle", 8: "wartortle",
    9: "blastoise", 10: "caterpie", 11: "metapod", 12: "butterfree",
    13: "weedle", 14: "kakuna", 15: "beedrill", 16: "pidgey",
    17: "pidgeotto", 18: "pidgeot", 19: "rattata", 20: "raticate",
    21: "spearow", 22: "fearow", 23: "ekans", 24: "arbok",
    25: "pikachu", 26: "raichu", 27: "sandshrew", 28: "sandslash",
    29: "nidoran-f", 30: "nidorina", 31: "nidoqueen", 32: "nidoran-m",
    33: "nidorino", 34: "nidoking", 35: "clefairy", 36: "clefable",
    37: "vulpix", 38: "ninetales", 39: "jigglypuff", 40: "wigglytuff",
    41: "zubat", 42: "golbat", 43: "oddish", 44: "gloom",
    45: "vileplume", 46: "paras", 47: "parasect", 48: "venonat",
    49: "venomoth", 50: "diglett", 51: "dugtrio", 52: "meowth",
    53: "persian", 54: "psyduck", 55: "golduck", 56: "mankey",
    57: "primeape", 58: "growlithe", 59: "arcanine", 60: "poliwag",
    61: "poliwhirl", 62: "poliwrath", 63: "abra", 64: "kadabra",
    65: "alakazam", 66: "machop", 67: "machoke", 68: "machamp",
    69: "bellsprout", 70: "weepinbell", 71: "victreebel", 72: "tentacool",
    73: "tentacruel", 74: "geodude", 75: "graveler", 76: "golem",
    77: "ponyta", 78: "rapidash", 79: "slowpoke", 80: "slowbro",
    81: "magnemite", 82: "magneton", 83: "farfetchd", 84: "doduo",
    85: "dodrio", 86: "seel", 87: "dewgong", 88: "grimer",
    89: "muk", 90: "shellder", 91: "cloyster", 92: "gastly",
    93: "haunter", 94: "gengar", 95: "onix", 96: "drowzee",
    97: "hypno", 98: "krabby", 99: "kingler", 100: "voltorb",
    101: "electrode", 102: "exeggcute", 103: "exeggutor", 104: "cubone",
    105: "marowak", 106: "hitmonlee", 107: "hitmonchan", 108: "lickitung",
    109: "koffing", 110: "weezing", 111: "rhyhorn", 112: "rhydon",
    113: "chansey", 114: "tangela", 115: "kangaskhan", 116: "horsea",
    117: "seadra", 118: "goldeen", 119: "seaking", 120: "staryu",
    121: "starmie", 122: "mr-mime", 123: "scyther", 124: "jynx",
    125: "electabuzz", 126: "magmar", 127: "pinsir", 128: "tauros",
    129: "magikarp", 130: "gyarados", 131: "lapras", 132: "ditto",
    133: "eevee", 134: "vaporeon", 135: "jolteon", 136: "flareon",
    137: "porygon", 138: "omanyte", 139: "omastar", 140: "kabuto",
    141: "kabutops", 142: "aerodactyl", 143: "snorlax", 144: "articuno",
    145: "zapdos", 146: "moltres", 147: "dratini", 148: "dragonair",
    149: "dragonite", 150: "mewtwo", 151: "mew",
    # 精选后续世代热门宝可梦
    152: "chikorita", 155: "cyndaquil", 158: "totodile",
    169: "crobat", 172: "pichu", 175: "togepi", 179: "mareep",
    181: "ampharos", 183: "marill", 196: "espeon", 197: "umbreon",
    200: "misdreavus", 208: "steelix", 212: "scizor", 214: "heracross",
    222: "corsola", 227: "skarmory", 228: "houndour", 229: "houndoom",
    243: "raikou", 244: "entei", 245: "suicune", 246: "larvitar",
    248: "tyranitar", 249: "lugia", 250: "ho-oh", 251: "celebi",
    252: "treecko", 255: "torchic", 258: "mudkip",
    280: "ralts", 282: "gardevoir", 292: "shedinja",
    302: "sableye", 303: "mawile", 304: "aron", 306: "aggron",
    334: "altaria", 349: "feebas", 350: "milotic",
    359: "absol", 373: "salamence", 376: "metagross",
    380: "latias", 381: "latios", 382: "kyogre", 383: "groudon",
    384: "rayquaza", 385: "jirachi", 386: "deoxys",
    390: "chimchar", 393: "piplup", 403: "shinx",
    443: "gible", 445: "garchomp", 447: "riolu", 448: "lucario",
    461: "weavile", 468: "togekiss", 470: "leafeon", 471: "glaceon",
    479: "rotom", 483: "dialga", 484: "palkia", 487: "giratina",
    491: "darkrai", 492: "shaymin", 493: "arceus",
    495: "snivy", 498: "tepig", 501: "oshawott",
    570: "zorua", 571: "zoroark", 587: "emolga",
    607: "litwick", 609: "chandelure", 610: "axew",
    635: "hydreigon", 637: "volcarona", 638: "cobalion",
    643: "reshiram", 644: "zekrom", 646: "kyurem",
    653: "fennekin", 656: "froakie", 658: "greninja",
    700: "sylveon", 704: "goomy", 706: "goodra",
    716: "xerneas", 717: "yveltal", 719: "diancie",
    722: "rowlet", 725: "litten", 728: "popplio",
    778: "mimikyu", 785: "tapu-koko", 791: "solgaleo", 792: "lunala",
    800: "necrozma", 807: "zeraora",
    810: "grookey", 813: "scorbunny", 816: "sobble",
    869: "alcremie", 880: "dracozolt", 887: "dragapult",
    888: "zacian", 889: "zamazenta", 890: "eternatus",

}

# ========== 随机形态选项 ==========
SPECIAL_FORMS = {
    "mega": "--mega",
    "mega_x": "--mega-x",
    "mega_y": "--mega-y",
    "gmax": "--gmax",
    "alolan": "--alolan",
    "hisui": "--hisui",
    "galar": "--galar",
}


def main():
    # 随机宝可梦
    num, name = random.choice(list(POKEDEX.items()))

    # 构建 pokeget 参数
    args = [name]

    # 30% 概率闪光
    if random.random() < 0.3:
        args.append("--shiny")
        name_label = f"★ {name}"
    else:
        name_label = name

    # 10% 概率特殊形态
    if random.random() < 0.1:
        form_key = random.choice(list(SPECIAL_FORMS.keys()))
        args.append(SPECIAL_FORMS[form_key])
        name_label += f" ({form_key})"

    # 获取精灵图
    result = subprocess.run(["pokeget"] + args + ["--hide-name"],
                            capture_output=True, text=True, timeout=10)
    if result.returncode != 0 or not result.stdout.strip():
        # 回退：只用名字
        result = subprocess.run(["pokeget", name, "--hide-name"],
                                capture_output=True, text=True, timeout=10)
    sprite = result.stdout
    if not sprite.strip():
        subprocess.run(["fastfetch", "-c", CONFIG_FILE, "--logo", "none"])
        return

    # 精灵图下方追加名字（居中）
    sprite_width = max((len(re.sub(r'\x1b\[[0-9;]*m', '', line))
                        for line in sprite.split('\n')), default=0)
    label = f"No.{num:03d} {name_label}"
    label_pad = max(0, (sprite_width - len(label)) // 2)
    sprite = sprite.rstrip('\n') + f"\n{' ' * label_pad}{label}"

    # 测量高度
    sprite_height = sprite.count('\n') + 1

    r = subprocess.run(["fastfetch", "-c", CONFIG_FILE, "--logo", "none"],
                       capture_output=True, text=True, timeout=10)
    info_height = r.stdout.count('\n') + 1

    # 动态生成配置（垂直居中）
    with open(CONFIG_FILE) as f:
        text = f.read()
    text = re.sub(r'^\s*//.*$', '', text, flags=re.MULTILINE)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    cfg = json.loads(text)

    if sprite_height > info_height:
        top_blank = (sprite_height - info_height) // 2
        blank = {"key": " ", "type": "custom"}
        for _ in range(top_blank):
            cfg["modules"].insert(0, dict(blank))

    tmp = os.path.join(tempfile.gettempdir(), "pokefetch_config.json")
    with open(tmp, 'w') as f:
        json.dump(cfg, f)

    # 显示
    p = subprocess.Popen(["fastfetch", "-c", tmp, "--file-raw", "-",
                           "--logo-padding-top", "0",
                           "--logo-padding-left", "1",
                           "--logo-padding-right", "2"],
                          stdin=subprocess.PIPE)
    p.communicate(input=sprite.encode())


if __name__ == "__main__":
    main()

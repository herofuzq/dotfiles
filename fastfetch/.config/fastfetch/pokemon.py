#!/usr/bin/env python3
"""Pokefetch — 随机宝可梦精灵图 + fastfetch 系统信息"""

import json, re, os, random, subprocess, tempfile

CONFIG_FILE = os.path.expanduser("~/.config/fastfetch/config.jsonc")

# ========== 宝可梦数据库（编号 + 英文名） ==========
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

# ========== 中文名映射 ==========
NAME_ZH = {
    1: "妙蛙种子", 2: "妙蛙草", 3: "妙蛙花", 4: "小火龙",
    5: "火恐龙", 6: "喷火龙", 7: "杰尼龟", 8: "卡咪龟",
    9: "水箭龟", 10: "绿毛虫", 11: "铁甲蛹", 12: "巴大蝶",
    13: "独角虫", 14: "铁壳蛹", 15: "大针蜂", 16: "波波",
    17: "比比鸟", 18: "大比鸟", 19: "小拉达", 20: "拉达",
    21: "烈雀", 22: "大嘴雀", 23: "阿柏蛇", 24: "阿柏怪",
    25: "皮卡丘", 26: "雷丘", 27: "穿山鼠", 28: "穿山王",
    29: "尼多兰", 30: "尼多娜", 31: "尼多后", 32: "尼多朗",
    33: "尼多力诺", 34: "尼多王", 35: "皮皮", 36: "皮可西",
    37: "六尾", 38: "九尾", 39: "胖丁", 40: "胖可丁",
    41: "超音蝠", 42: "大嘴蝠", 43: "走路草", 44: "臭臭花",
    45: "霸王花", 46: "派拉斯", 47: "派拉斯特", 48: "毛球",
    49: "摩鲁蛾", 50: "地鼠", 51: "三地鼠", 52: "喵喵",
    53: "猫老大", 54: "可达鸭", 55: "哥达鸭", 56: "猴怪",
    57: "火暴猴", 58: "卡蒂狗", 59: "风速狗", 60: "蚊香蝌蚪",
    61: "蚊香君", 62: "蚊香泳士", 63: "凯西", 64: "勇基拉",
    65: "胡地", 66: "腕力", 67: "豪力", 68: "怪力",
    69: "喇叭芽", 70: "口呆花", 71: "大食花", 72: "玛瑙水母",
    73: "毒刺水母", 74: "小拳石", 75: "隆隆石", 76: "隆隆岩",
    77: "小火马", 78: "烈焰马", 79: "呆呆兽", 80: "呆壳兽",
    81: "小磁怪", 82: "三合一磁怪", 83: "大葱鸭", 84: "嘟嘟",
    85: "嘟嘟利", 86: "小海狮", 87: "白海狮", 88: "臭泥",
    89: "臭臭泥", 90: "大舌贝", 91: "刺甲贝", 92: "鬼斯",
    93: "鬼斯通", 94: "耿鬼", 95: "大岩蛇", 96: "催眠貘",
    97: "引梦貘人", 98: "大钳蟹", 99: "巨钳蟹", 100: "霹雳电球",
    101: "顽皮雷弹", 102: "蛋蛋", 103: "椰蛋树", 104: "卡拉卡拉",
    105: "嘎啦嘎啦", 106: "飞腿郎", 107: "快拳郎", 108: "大舌头",
    109: "瓦斯弹", 110: "双弹瓦斯", 111: "独角犀牛", 112: "钻角犀兽",
    113: "吉利蛋", 114: "蔓藤怪", 115: "袋兽", 116: "墨海马",
    117: "海刺龙", 118: "角金鱼", 119: "金鱼王", 120: "海星星",
    121: "宝石海星", 122: "魔墙人偶", 123: "飞天螳螂", 124: "迷唇姐",
    125: "电击兽", 126: "鸭嘴火兽", 127: "凯罗斯", 128: "肯泰罗",
    129: "鲤鱼王", 130: "暴鲤龙", 131: "拉普拉斯", 132: "百变怪",
    133: "伊布", 134: "水伊布", 135: "雷伊布", 136: "火伊布",
    137: "多边兽", 138: "菊石兽", 139: "多刺菊石兽", 140: "化石盔",
    141: "镰刀盔", 142: "化石翼龙", 143: "卡比兽", 144: "急冻鸟",
    145: "闪电鸟", 146: "火焰鸟", 147: "迷你龙", 148: "哈克龙",
    149: "快龙", 150: "超梦", 151: "梦幻",
    152: "菊草叶", 155: "火球鼠", 158: "小锯鳄",
    169: "叉字蝠", 172: "皮丘", 175: "波克比", 179: "咩利羊",
    181: "电龙", 183: "玛力露", 196: "太阳伊布", 197: "月亮伊布",
    200: "梦妖", 208: "大钢蛇", 212: "巨钳螳螂", 214: "赫拉克罗斯",
    222: "太阳珊瑚", 227: "盔甲鸟", 228: "戴鲁比", 229: "黑鲁加",
    243: "雷公", 244: "炎帝", 245: "水君", 246: "幼基拉斯",
    248: "班基拉斯", 249: "洛奇亚", 250: "凤王", 251: "时拉比",
    252: "木守宫", 255: "火稚鸡", 258: "水跃鱼",
    280: "拉鲁拉丝", 282: "沙奈朵", 292: "脱壳忍者",
    302: "勾魂眼", 303: "大嘴娃", 304: "可可多拉", 306: "波士可多拉",
    334: "七夕青鸟", 349: "丑丑鱼", 350: "美纳斯",
    359: "阿勃梭鲁", 373: "暴飞龙", 376: "巨金怪",
    380: "拉帝亚斯", 381: "拉帝欧斯", 382: "盖欧卡", 383: "固拉多",
    384: "烈空坐", 385: "基拉祈", 386: "代欧奇希斯",
    390: "小火焰猴", 393: "波加曼", 403: "小猫怪",
    443: "圆陆鲨", 445: "烈咬陆鲨", 447: "利欧路", 448: "路卡利欧",
    461: "玛狃拉", 468: "波克基斯", 470: "叶伊布", 471: "冰伊布",
    479: "洛托姆", 483: "帝牙卢卡", 484: "帕路奇亚", 487: "骑拉帝纳",
    491: "达克莱伊", 492: "谢米", 493: "阿尔宙斯",
    495: "藤藤蛇", 498: "暖暖猪", 501: "水水獭",
    570: "索罗亚", 571: "索罗亚克", 587: "电飞鼠",
    607: "烛光灵", 609: "水晶灯火灵", 610: "牙牙",
    635: "三首恶龙", 637: "火神蛾", 638: "勾帕路翁",
    643: "莱希拉姆", 644: "捷克罗姆", 646: "酋雷姆",
    653: "火狐狸", 656: "呱呱泡蛙", 658: "甲贺忍蛙",
    700: "仙子伊布", 704: "黏黏宝", 706: "黏美龙",
    716: "哲尔尼亚斯", 717: "伊裴尔塔尔", 719: "蒂安希",
    722: "木木枭", 725: "火斑喵", 728: "球球海狮",
    778: "谜拟丘", 785: "卡璞·鸣鸣", 791: "索尔迦雷欧", 792: "露奈雅拉",
    800: "奈克洛兹玛", 807: "捷拉奥拉",
    810: "敲音猴", 813: "炎兔儿", 816: "泪眼蜥",
    869: "霜奶仙", 880: "雷鸟龙", 887: "多龙巴鲁托",
    888: "苍响", 889: "藏玛然特", 890: "无极汰那",
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

# 形态中文名
FORM_ZH = {
    "mega": "超级进化",
    "mega_x": "超级进化X",
    "mega_y": "超级进化Y",
    "gmax": "超极巨化",
    "alolan": "阿罗拉的样子",
    "hisui": "洗翠的样子",
    "galar": "伽勒尔的样子",
}


def main():
    # 随机宝可梦
    num, name = random.choice(list(POKEDEX.items()))
    zh_name = NAME_ZH.get(num, name)

    # 构建 pokeget 参数
    args = [name]

    # 30% 概率闪光
    shiny = random.random() < 0.3
    if shiny:
        args.append("--shiny")

    # 10% 概率特殊形态
    form_key = None
    if random.random() < 0.1:
        form_key = random.choice(list(SPECIAL_FORMS.keys()))
        args.append(SPECIAL_FORMS[form_key])

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

    # 构建中文标签
    label_parts = []
    if shiny:
        label_parts.append("★")
    label_parts.append(zh_name)
    if form_key:
        label_parts.append(f"（{FORM_ZH.get(form_key, form_key)}）")
    name_label = "".join(label_parts)

    # 清理精灵图尾部空白行 + 每行尾随空格（减少右侧无意义间隔）
    sprite = sprite.rstrip('\n')
    sprite_lines = [line.rstrip() for line in sprite.split('\n')]
    while sprite_lines and not re.sub(r'\x1b\[[0-9;]*m', '', sprite_lines[-1]).strip():
        sprite_lines.pop()
    sprite = '\n'.join(sprite_lines)

    # 精灵图下方追加名字（居中）
    sprite_width = max((len(re.sub(r'\x1b\[[0-9;]*m', '', line))
                        for line in sprite_lines), default=0)
    label = f"No.{num:03d} {name_label}"
    label_pad = max(0, (sprite_width - len(label)) // 2)
    sprite = sprite + f"\n{' ' * label_pad}{label}"

    # 测量高度（含精灵名标签行）
    sprite_height = sprite.count('\n') + 1

    r = subprocess.run(["fastfetch", "-c", CONFIG_FILE, "--logo", "none"],
                       capture_output=True, text=True, timeout=10)
    info_height = r.stdout.rstrip('\n').count('\n') + 1

    # 动态生成配置（垂直居中）
    with open(CONFIG_FILE) as f:
        text = f.read()
    text = re.sub(r'^\s*//.*$', '', text, flags=re.MULTILINE)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    cfg = json.loads(text)

    # 修复 shell 显示：用实际 $SHELL 替换
    real_shell = os.path.basename(os.environ.get('SHELL', 'unknown'))
    for module in cfg["modules"]:
        if module.get("type") == "shell":
            module["type"] = "custom"
            module["format"] = real_shell
            break

    # 修复终端显示：从环境变量检测真正的终端模拟器
    real_term = os.environ.get('TERM_PROGRAM', '')
    if real_term in ('iTerm.app',):   real_term = 'iTerm2'
    elif real_term == 'Apple_Terminal': real_term = 'Terminal'
    elif real_term == 'WarpTerminal':   real_term = 'Warp'
    if not real_term:
        term = os.environ.get('TERM', '')
        for name in ('ghostty', 'kitty', 'alacritty', 'wezterm', 'hyper', 'contour'):
            if name in term:
                real_term = name.capitalize()
                break
    if not real_term:
        real_term = os.environ.get('LC_TERMINAL', '') or 'unknown'
    for module in cfg["modules"]:
        if module.get("type") == "terminal":
            module["type"] = "custom"
            module["format"] = real_term
            break

    # Logo padding 设置（新版 fastfetch 需通过 modules 中的 logo 条目）
    logo_module = {
        "type": "logo",
        "padding": {"top": 0, "bottom": 0, "left": 1, "right": 0}
    }
    # 如果 modules 中已有 logo 条目则替换，否则插入到最前面
    existing_logo_idx = next((i for i, m in enumerate(cfg["modules"]) if m.get("type") == "logo"), None)
    if existing_logo_idx is not None:
        cfg["modules"][existing_logo_idx] = logo_module
    else:
        cfg["modules"].insert(0, logo_module)

    if sprite_height > info_height:
        top_blank = (sprite_height - info_height) // 2
        blank = {"key": " ", "type": "custom"}
        # 插在 logo 模块之后（logo 模块总在最前面）
        for i in range(top_blank):
            cfg["modules"].insert(1 + i, dict(blank))

    tmp = os.path.join(tempfile.gettempdir(), "pokefetch_config.json")
    with open(tmp, 'w') as f:
        json.dump(cfg, f)

    # 显示（logo padding 已在 JSON 配置中通过 modules logo 条目设置）
    p = subprocess.Popen(["fastfetch", "-c", tmp, "--file-raw", "-"],
                          stdin=subprocess.PIPE)
    p.communicate(input=sprite.encode())


if __name__ == "__main__":
    main()

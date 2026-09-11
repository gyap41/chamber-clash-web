"""Refresh the reference tables from the Godot catalog, prices and cell shapes.

Run from any directory: python tools/export_item_catalog.py
The hand-written bag/shape guide above the weapon section is retained.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def shapes(path, constant):
    body = re.search(rf"const {constant} := \{{(.*?)\n\}}", read(path), re.S)[1]
    result = {}
    for key, cells in re.findall(r'("[A-Z]+"|\d+):\s*\[([^\]]+)\]', body):
        points = [(int(x), int(y)) for x, y in re.findall(r"Vector2i\((\d+),\s*(\d+)\)", cells)]
        width = max(x for x, _ in points) + 1
        height = max(y for _, y in points) + 1
        drawing = "/".join("".join("#" if (x, y) in points else "." for x in range(width)) for y in range(height))
        result[key.strip('"')] = f"{len(points)}・`{drawing}`"
    return result


def main():
    catalog = json.loads(read("data/catalog.json"))
    shop = read("scripts/catalog/shop_catalog.gd")
    prices = {kind: json.loads(re.search(rf"const {kind}_PRICES := (\[[^\]]+\])", shop)[1]) for kind in ("WEAPON", "RELIC")}
    defaults = shapes("scripts/catalog/weapon_shapes.gd", "RARITY_SHAPES")
    weapons = shapes("scripts/catalog/weapon_shapes.gd", "SHAPES")
    relics = shapes("scripts/catalog/relic_shapes.gd", "SHAPES")
    path = ROOT / "docs/design/ITEM_CATALOG.md"
    heading = read("docs/design/ITEM_CATALOG.md").split("## 現行武器")[0]
    weapon_count = len(catalog["guns"])
    relic_count = len(catalog["relics"])
    common_count = sum(not gun.get("exclusive", False) for gun in catalog["guns"])
    lines = [heading.rstrip(), "", f"## 現行武器{weapon_count}種", "",
             "間隔は秒、弾速はpx/秒。弾数×威力は直接射撃分。分裂・追射・爆発・継続ダメージは含まない。",
             "ホチキスバーストの3発は時間差の直接射撃。エコードラム・カーボンコピーの追射は特徴欄を参照。",
             "装填は基礎1.15秒×キャラ補正。レリックで変化する。ワイドマガジン装備時は表の弾倉上限に+2。",
             f"初期専用8種は無料・抽選外・売却0G。通常入手{common_count}種はレアに応じてショップ／補給から取得する。",
             "フィールド武器は取得時に控えへ入り、次の準備で配置してから使える。所持済み・控え8個満杯では取得不可。弾薬補給は弾薬箱。", "",
             "|ID|名称|レア|間隔|弾速|弾数×威力|弾倉/予備|占有・形状|価格G|特徴|",
             "|---|---|---|---:|---:|---|---|---|---|---|",]
    for index, gun in enumerate(catalog["guns"]):
        price = "初期専用" if gun.get("exclusive") else prices["WEAPON"][index]
        count = gun.get("count", 1) * gun.get("burst_count", 1)
        shape = weapons.get(str(index), defaults[gun["rarity"]])
        lines.append(f'|{index}|{gun["name"]}|{gun["rarity"]}|{gun["rate"]}|{gun["speed"]}|{count}×{gun["damage"]}|{gun["mag"]}/{gun["stock"]}|{shape}|{price}|{gun["desc"]}|')
    lines += ["", f"## 現行レリック{relic_count}種", "", f"ショップは各1/{relic_count}の均等抽選。フィールド仮取得は1ラウンド1個。",
              "同種重複可能なのは18/19のみ。新規15種は同種重複不可。重複品も個体ごとにマスを使う。", "",
              "|ID|名称|効果|占有・形状|価格G|同種重複|", "|---|---|---|---|---:|---|"]
    for index, relic in enumerate(catalog["relics"]):
        shape = relics.get(str(index), "1・`#`")
        stack = "可・加算" if relic.get("stackable") else "不可"
        lines.append(f'|{index}|{relic["name"]}|{relic["desc"]}|{shape}|{prices["RELIC"][index]}|{stack}|')
    lines += ["", "## 現行キャラと初期武器", "", "初期武器は無料で控えへ保証する。各キャラの2マス専用武器を配置して出撃できる。",
              "移動はpx/秒、装填は基礎1.15秒への倍率、回避はクールダウン秒。", "",
              "|キャラ|役割|HP|移動|装填倍率|回避待ち|パルス回数|現在の初期武器|", "|---|---|---:|---:|---:|---:|---:|---|"]
    for ch in catalog["characters"]:
        gun = catalog["guns"][ch["gun"]]
        lines.append(f'|{ch["name"]}|{ch["role"]}|{ch["hp"]}|{ch["speed"]}|{ch["reload"]}|{ch["dodge"]}|{ch["blanks"]}|{gun["name"]}（ID {ch["gun"]}）|')
    lines += ["", "性能は試作値。人間による対戦バランスは未評価。追加武器の絵は既存アトラスを仮利用している。",
              "表の更新: `python tools/export_item_catalog.py`。カタログ・価格・形状を変更したら再出力する。バッグ説明は手動更新。"]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

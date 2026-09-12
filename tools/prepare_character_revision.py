"""Write reviewed character identities and revision prompts; no network calls."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/settings/character-revision-2026-09-12'
CHARACTERS = [
('01-sora', 'ソラ', 'Human scout with tousled brown hair and forehead goggles, blue short jacket, ivory shirt, tan work trousers. Preserve the original scout identity, not navy hair or a monocular.'),
('02-kohaku', 'コハク', 'Anthropomorphic orange fox, NOT a human. Large pointed fox ears, white muzzle and cheek fur, black nose, expressive fox face and one fluffy orange tail with a white tip. Green short hooded work top, brown trousers. No human hair, goggles or human face. Keep the tail compact in the chibi.'),
('03-bolt', 'ボルト', 'Friendly nonhuman guard robot, rounded ivory head with ONE large circular blue optical eye, dark round ear housing and short antenna. Ivory rounded armor, black joints, compact orange back module. NOT a box head or a horizontal eye slit.'),
('04-mei', 'メイ', 'Human mechanic with copper-red twin braids, tan work cap and forehead goggles, yellow shirt and blue work overalls. Preserve braids rather than a single bun. Compact tools and practical work boots.'),
('05-luna', 'ルナ', 'Human arcanist with silver-lilac bob and blue eyes. Preserve a recognizable dark blue pointed witch hat with gold crescent, matching blue cape with crescent motif, ivory tunic and dark leggings. In chibi shorten the cape and tunic, keep face clear, hide leggings almost completely beneath hem. Do not replace witch hat with only a hair clip; no exposed long trouser legs.'),
('06-rattle', 'ラトル', 'Animated SKELETON gunslinger, NOT a living human. Ivory skull face with dark eye sockets, visible skeletal hands, brown broad-brimmed cowboy hat, short rust-red poncho with gold trim, dark trousers and brown boots. Friendly expressive skull, no gore, no flesh, hair or moustache.'),
('07-crow', 'クロウ', 'Anthropomorphic CROW bird-person heavy gunner, NOT a human. Blue-black feathered head, prominent dark beak, feather crest and compact tail feathers. Orange scarf, blue-gray work jacket, olive trousers and brown boots, broad sturdy torso. Preserve avian face and feathers, no human face or human hair.'),
]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    common = '''
Use case: stylized-concept. Create ONE square character setting sheet. Left 38%: natural-proportion full-body front three-quarter view. Middle 38%: matching full-body rear view. Right 24%: compact game chibi. Empty gutters, warm plain off-white paper, no annotations except character name. Normal views about 80% sheet height, chibi about 35%. Human normal versions are adults around 6 heads tall; retain nonhuman anatomy for fox, skeleton, bird and robot. Show coherent front/back costume construction.
Reference roles: original fighters sheet defines THIS character's species, face, signature colors and identifying accessories; approved in-game Rina image defines ONLY chibi proportions, clean outlines and cel shading. Do not copy Rina's goggles, face, hair or costume onto other characters. A previous draft, if provided, is only a secondary costume-construction reference and must not override identity.
Chibi construction: oversized head, extremely short bean torso, two tiny separate rounded shoes immediately below the hem. Almost no exposed thighs or shins; no visible knee anatomy, no long trouser section between waist and feet. Follow in-game Rina proportions, not the taller prior setting-sheet chibis. Keep a readable separation between left and right shoe and attach both naturally under the body. Each shoe must work as an independent animation part; do not draw walking poses or multiple frames. Preserve costume identity with broad color blocks. Body and head have stable clean contours. Hat, ears and tail remain recognizable but compact. Normal-proportion views KEEP natural-length legs; never stretch chibi anatomy into them. Match identity across all three views. Empty hands, no gun, no additional characters, no scenery or watermark. Modern appealing Japanese adventure illustration with controlled cel shading and crisp outlines.
'''
    for slug, name, identity in CHARACTERS:
        (OUT / (slug + '.txt')).write_text('Character: ' + slug[3:].upper() + '. ' + identity + '\n' + common, encoding='utf-8')
    rows = '\n'.join(f'|{name}|[{slug}.txt]({slug}.txt)|' for slug,name,_ in CHARACTERS)
    (OUT / 'README.md').write_text('''# キャラクター修正指示

2026-09-12。ユーザー承認済みの方針：既存キャラクターの識別点を復元し、ゲーム用の足回りを実装済みリナへ統一する。通常等身は自然な脚の長さを保つ。

リナは採用済みゲーム画像を維持。他7人を各1枚、通常等身前後＋低頭身の設定シートとして修正する準備。生成前の指示であり、修正画像・ゲーム差し替えの完了ではない。以前の人間版コハク・ラトル・クロウは旧比較案として保存する。

元画像：`assets/characters/fighters.png`（4列×2行、ID順）。頭身の基準：`tests/fixtures/art/legacy-rina-twohead/rina.png`。ルナだけでなくソラ・ラトル・クロウも脚の見える長さを減らす。靴の大きさは個性を残し、左右別パーツとして読み取れる形にする。輪郭の安定と交互歩行は画像だけで解決済みとせず、実装時に固定パーツと逆位相の動作を確認する。

|対象|生成指示|
|---|---|
''' + rows + '''

## 受入条件

- 狐・骸骨・鳥人・単眼ロボットの種別と、各人の帽子・髪型・主要配色を元画像と照合。
- 低頭身の全身を同じ56px高で比較し、長いズボン部分や膝が見えないこと、靴が左右別に読めることを確認。
- 通常等身前後と低頭身で種族・衣装・装備が一致すること。
- 生成結果は個別確認し、不合格でも自動で追加生成しない。

## 生成枠

既存枠は累計28回までで消化済み。今回7枚には予約上限$29→$36（累計最大35回）への追加承認が必要。承認前はAPI送信・上限変更をしない。実際の請求額ではなく、1回$1を累積予約する保守制限。
''', encoding='utf-8')

if __name__ == '__main__':
    main()

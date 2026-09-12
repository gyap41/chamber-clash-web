"""Record the locally reviewed production assets and accounting; never generates."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'assets/first-workshop/manifest.json'
d=json.loads(p.read_text(encoding='utf-8'))
uses={
 'floor':['scripts/visuals/workshop_floor.gd'], 'cover':['scripts/world/wall.gd'],
 'rina':['scripts/catalog/character_catalog.gd'],
 'pistol':['scripts/catalog/weapon_catalog.gd','scripts/combat/player.gd'],
 'idle':['scripts/visuals/player_animation.gd'],'move':[],
 'move-corrected':['scripts/visuals/player_animation.gd'],'roll':['scripts/visuals/player_animation.gd'],
 'bullet':['scripts/visuals/projectile_art.gd'],'muzzle':['scripts/visuals/player_animation.gd'],
 'impact':['scripts/visuals/combat_visuals.gd'],'trail':['scripts/visuals/player_animation.gd'],
 'ammo':['scripts/world/pickup.gd'],'hud':['assets/ui/hud/skin.json']}
for a in d['assets']:
    a.update(consumers=uses[a['id']],adopted=a['id']!='move',prompt='docs/art/production/first-workshop-prompts/'+a['id']+'.txt')
    a['original_sha256']=hashlib.sha256((ROOT/a['original']).read_bytes()).hexdigest()
    if 'output' in a: a['output_sha256']=hashlib.sha256((ROOT/a['output']).read_bytes()).hexdigest()
d['animation_contract'].update(runtime_dest=[-64,-47.5,128,84],roll_processing_scale=.24,move_rate='10 frames/s * effective_move_speed / 205',idle_rate=3,roll_afterglow_seconds=.05)
d['weapon_20'].update(sprite_position=[15,0],muzzle_local=[29,-7],mirror='flip_v on left aim; muzzle y changes sign')
ledger=json.loads((ROOT/'assets/generated/first-workshop-usage.json').read_text(encoding='utf-8'))
assert len(ledger)==14 and all(x['status']=='success' for x in ledger)
d['accounting']=dict(requests=len(ledger),pricing_estimate_usd=round(sum(x['pricing_estimate_usd'] for x in ledger),6),reserved_usd=14,billing_invoice_verified=False,automatic_retries=0,audio_requests=0)
p.write_bytes((json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
lines=['# API使用量明細','', '全14回成功。各回n=1、gpt-image-2 / high / 1024×1024 PNG。', '', '|原画|usage料金表換算 USD|','|---|---:|']
lines += [f"|{x['name']}|${x['pricing_estimate_usd']:.6f}|" for x in ledger]
lines += ['',f"合計 **${d['accounting']['pricing_estimate_usd']:.6f}**。保守予約$14、承認上限$15/50回。",'', '画像入力$4・テキスト入力$2.50・画像出力$15/百万tokenで換算。キャッシュ割引なし。', '請求書・税・契約固有単価は未確認。APIが返したusageは各原画のJSONと共通ledgerに保存。', '', '公式料金表: https://developers.openai.com/api/docs/pricing', '', '移動修正1回のみ追加承認済み。全素材の追加候補・再送をこれ以上行っていない。']
(ROOT/'docs/archive/2026-09-12/first-workshop/USAGE.md').write_bytes(('\n'.join(lines)+'\n').encode('utf-8'))
print(json.dumps(d['accounting']))

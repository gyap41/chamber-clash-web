"""Prepare prompts and compact identity references; no API calls."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/reviews/character-directions-2026-09-12'
CHARACTERS=[
('01-sora','Sora: brown tousled hair, brass goggles, blue jacket with ivory hood, dark gloves and tiny dark shoes. Human male.','A low forward sliding dive, arms forward and tiny legs tucked behind.'),
('02-kohaku','Kohaku: an orange FOX person, huge pointed fox ears, white muzzle, orange tail with white tip, green short cloak, tiny brown shoes. Never human.','A nimble forward pounce with bent legs and tail trailing, then light crouched landing.'),
('03-bolt','Bolt: a round ivory ROBOT with one large blue circular lens eye, small antenna, rounded ivory armor, dark joints and tiny round feet. Never human.','Low mechanical forward glide: feet folded under round chassis, body inclined, then feet extend for landing. No standing rotation.'),
('04-mei','Mei: copper-red twin braids, brown work cap with goggles, yellow shirt, compact blue overalls, dark gloves and tiny brown shoes. Human female.','A low workmanlike forward slide, hands reaching forward, folded short legs, weighty crouched recovery.'),
('05-luna','Luna: silver-lilac bobbed hair, blue witch hat with gold crescent, short blue cape with gold crescent, tiny ivory dress and tiny separate dark shoes. Human female. Keep the witch hat.','A short floating evasive hop, knees and feet tucked up, hands outward and cape lifted, then feet gather for landing. Clearly airborne but no teleport or effects.'),
('06-rattle','Rattle: a cute SKELETON gunslinger, bare ivory skull with dark eye sockets and gold pupils, broad brown cowboy hat, rust-red poncho with gold trim, tiny brown boots. No human skin or hair.','A compact evasive forward lunge, skull leading, body low and legs bent behind, hands balancing, then crouched recovery.'),
('07-crow','Crow: a dark navy CROW bird person with gray beak, dark feathers, orange scarf, short dark blue jacket, tiny olive lower body and dark shoes. No human face.','A heavy forward dive, beak and shoulders leading, wing arms reaching forward, short legs tucked behind, then weighty landing.')]

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for name,identity,motion in CHARACTERS:
        folder=OUT/name; folder.mkdir(exist_ok=True)
        source=ROOT/'docs/art/settings/character-revision-2026-09-12'/name/'chibi.png'
        im=Image.open(source); im.thumbnail((600,600)); im.save(folder/'identity.png')
        prompt=f'''Production game sprite sheet of ONE character. First reference defines this character's identity. Second reference Rina defines rendering style and VERY LOW two-head proportions only; do NOT copy Rina's costume or face. {identity}
Match Rina's huge head, tiny compact torso, almost no visible legs, two independent tiny shoes directly under hem. No thighs, knees or long pants visible when standing. Crisp stable dark outlines, flat cel shading, ivory/teal workshop detailing where already present. Keep unique species, colors, hat/ears/tail. No weapon in any pose.
EXACT regular 4 columns by 3 rows on 1024x1024, each cell 256 wide and 341 high. Exactly TWELVE isolated sprites, centered in their own cell with generous magenta gutters. Pure uniform #FF00FF background. No text, labels, borders, shadows, floor, effects or extra sprites. Entire sprite including tail/hat fits cell. Same physical head size across all 12 poses, head about 130px wide excluding hat/ears. Do not independently fit each pose to the cell. Feet/hands contact a common baseline near bottom of each row. Slight elevated game camera, not cinematic.
Rows: TOP = front facing DOWN toward viewer; MIDDLE = true BACK facing UP away, NO face/eye/beak visible; BOTTOM = true RIGHT profile facing right. Left will be mirrored by game.
Columns: 1 STANDING idle with both small shoes visible and separated, arms at sides; 2 TAKEOFF crouch with weight forward and compressed tiny legs; 3 ACTIVE EVASION; 4 LANDING crouch absorbing impact with hands low and shoes gathered beneath torso.
Active evasion: {motion} Draw genuinely different bent limb/torso anatomy, never merely rotate a standing sprite. For down/front motion head leads toward bottom foreground, body/feet trail above and behind with foreshortening. For up/back head leads toward top, back torso and tucked shoes trail below, face hidden. For right motion head leads RIGHT and feet trail LEFT; show profile and clear movement direction. Preserve identical head mass, costume, outline weight and proportions throughout. Landing different from takeoff. All sprites are the same character, not variations.
This replaces a game's standing, walking source and dodge animation. Consistency and readable feet matter more than extra decoration.'''
        assert len(prompt.encode())<=4000
        (folder/'prompt.txt').write_text(prompt,encoding='utf-8')
    print('Prepared seven identity references and twelve-pose prompts; no API calls.')
if __name__=='__main__': main()

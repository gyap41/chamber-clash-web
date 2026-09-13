"""Extract the approved replacement sprite; no network or generation.

The generated RGB source has a baked checkerboard. This outline mask removes
only that background (including the trigger opening), retaining painted pixels.
Run after historical sheet packers to restore the current Doubleback artwork.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

def main():
    im = Image.open(ROOT / 'assets/generated/doubleback-body-v2.png').convert('RGBA')
    mask = Image.new('L', im.size)
    draw = ImageDraw.Draw(mask)
    outline = [(26,366),(30,339),(45,321),(78,310),(470,255),(505,254),
        (526,264),(544,286),(561,291),(578,287),(678,231),(704,214),
        (717,208),(730,218),(763,207),(758,191),(756,178),(766,163),
        (786,156),(803,160),(828,159),(864,139),(893,131),(909,130),
        (914,121),(943,120),(946,131),(1857,132),(1868,128),(1893,130),
        (1903,141),(1914,147),(1920,165),(1926,194),(1925,238),
        (1924,279),(1914,305),(1900,318),(1551,319),(1540,330),
        (1509,340),(954,351),(943,360),(928,361),(927,395),(914,425),
        (892,442),(864,449),(804,448),(773,436),(753,420),(738,392),
        (731,375),(715,375),(691,388),(665,415),(642,446),(622,487),
        (605,531),(593,539),(566,541),(523,533),(480,515),(439,498),
        (117,665),(88,675),(69,674),(55,663),(45,639),(37,570)]
    draw.polygon(outline, fill=255)
    # Trigger guard opening, excluding both painted triggers.
    draw.polygon([(787,361),(803,358),(790,380),(790,402),(806,424),
                  (779,415),(766,397),(762,380),(766,368)], fill=0)
    draw.polygon([(832,355),(861,352),(881,356),(896,369),(902,386),
                  (895,407),(878,421),(860,426),(813,425),(817,416),
                  (806,403),(805,386),(816,367)], fill=0)
    im.putalpha(mask)
    im = im.crop(mask.getbbox())
    im.thumbnail((256,192), Image.Resampling.LANCZOS)
    im.save(ROOT / 'assets/first-workshop/equipment/guns/04.png')
    print('Doubleback runtime:', im.size)

if __name__ == '__main__':
    main()

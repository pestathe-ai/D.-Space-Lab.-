import cairosvg, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from mark import full, fg
out = sys.argv[1]
open(f"{out}/icon.svg","w").write(full())
cairosvg.svg2png(bytestring=full().encode(), write_to=f"{out}/icon-512.png", output_width=512, output_height=512)
dens = {"mdpi":1,"hdpi":1.5,"xhdpi":2,"xxhdpi":3,"xxxhdpi":4}
for d,k in dens.items():
    os.makedirs(f"{out}/res/mipmap-{d}", exist_ok=True)
    cairosvg.svg2png(bytestring=full().encode(), write_to=f"{out}/res/mipmap-{d}/ic_launcher.png", output_width=int(48*k), output_height=int(48*k))
    s=int(108*k)
    cairosvg.svg2png(bytestring=fg().encode(), write_to=f"{out}/res/mipmap-{d}/ic_launcher_foreground.png", output_width=s, output_height=s)
    # monochrome: sagoma bianca con il simbolo "bucato" (solo l'alfa conta)
    import io
    from PIL import Image, ImageChops
    sil = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=fg().encode(), output_width=s, output_height=s))).convert("RGBA")
    r,g,b,a = sil.split()
    # il simbolo e' blu scuro: lo togliamo dall'alfa
    lum = Image.merge("RGB",(r,g,b)).convert("L").point(lambda v: 255 if v < 110 else 0)
    alpha = ImageChops.subtract(a, lum)
    Image.merge("RGBA",(Image.new("L",(s,s),255),)*3+(alpha,)).save(f"{out}/res/mipmap-{d}/ic_launcher_monochrome.png")
os.makedirs(f"{out}/res/mipmap-anydpi-v26", exist_ok=True)
open(f"{out}/res/mipmap-anydpi-v26/ic_launcher.xml","w").write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
''')
os.makedirs(f"{out}/res/values", exist_ok=True)
open(f"{out}/res/values/ic_launcher_background.xml","w").write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1D3A8A</color>
</resources>
''')

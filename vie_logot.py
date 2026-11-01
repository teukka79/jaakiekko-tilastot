#!/usr/bin/env python3
"""Kopioi ohjelman jo ladatut logot projektin LogoSeed-kansioon, jotta ne paketoituvat sovelluksen mukaan."""
import json, os, shutil, subprocess, sys, glob
home = os.path.expanduser("~")
cands = [home + "/Library/Containers/fi.teukka.JaakiekkoTilastot/Data/Library/Application Support/JaakiekkoTilastot",
         home + "/Library/Application Support/JaakiekkoTilastot"]
base = next((c for c in cands if os.path.isdir(c + "/logos")), None)
if not base:
    sys.exit("Logokansiota ei löytynyt. Käynnistä ohjelma kerran ja anna logojen latautua.")
here = os.path.dirname(os.path.abspath(__file__))
seed = os.path.join(here, "JaakiekkoTilastot", "LogoSeed")
os.makedirs(seed, exist_ok=True)
n = 0; total = 0
for f in glob.glob(base + "/logos/*.img"):
    dst = os.path.join(seed, os.path.basename(f))
    shutil.copyfile(f, dst); n += 1
    # pienennä isot kuvat (enintään 200 px), pienet jätetään ennalleen
    try:
        w = subprocess.run(["sips", "-g", "pixelWidth", dst], capture_output=True, text=True).stdout.split()[-1]
        if w.isdigit() and int(w) > 200:
            subprocess.run(["sips", "-Z", "200", dst], capture_output=True)
    except Exception:
        pass
    total += os.path.getsize(dst)
st = json.load(open(base + "/state.json"))
amap = {k: v for k, v in (st.get("autoLogos") or {}).items()}
json.dump(amap, open(os.path.join(seed, "LogoMap.json"), "w"), ensure_ascii=False, indent=1)
print(f"Kopioitu {n} logoa ({total/1e6:.1f} Mt) ja {len(amap)} joukkue-osoitetta kansioon {seed}")

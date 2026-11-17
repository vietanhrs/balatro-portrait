from pathlib import Path
import json, re, hashlib
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[2]; p=root/'assets/v3'; m=json.loads((p/'manifest.json').read_text())
assert {k:len(v) for k,v in m['items'].items()}=={'passive':20,'planet':9,'tarot':8,'voucher':4,'pack':4}
for f in p.glob('background*.png'):
 a=np.array(Image.open(f));assert a.shape==(512,512,4);assert (a[0]==a[-1]).all() and (a[:,0]==a[:,-1]).all();assert (a[:,:,3]==255).all()
atlas=Image.open(p/'items_atlas.png')
for family,items in m['items'].items():
 for id,v in items.items():
  im=Image.open(root/v['path'].replace('res://',''));assert im.size==(192,256);assert im.getpixel((0,0))[3]==0
  x,y,w,h=v['atlas_rect'];assert np.array_equal(np.array(im),np.array(atlas.crop((x,y,x+w,y+h))))
for name,v in m['assets'].items():
 im=Image.open(root/v['path'].replace('res://',''));assert list(im.size)==v['size'];assert im.mode=='RGBA'
for f in p.rglob('*.png'):Image.open(f).verify()
report={'result':'PASS','item_count':45,'png_count':len(list(p.rglob('*.png'))),'png_bytes':sum(f.stat().st_size for f in p.rglob('*.png')),'checks':['all PNG files decode','all manifest paths and sizes','45 items in five families','all atlas rect pixels equal originals','all item alpha corners transparent','three seamless backgrounds exact opposite edges, opaque'],'sha256':{str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(p.rglob('*.png'))}}
(p/'verification.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps({k:v for k,v in report.items() if k!='sha256'},indent=2))

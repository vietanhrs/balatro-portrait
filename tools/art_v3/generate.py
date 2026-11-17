from PIL import Image, ImageDraw, ImageFont
import numpy as np, math, random, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/v3'; OUT.mkdir(exist_ok=True)
random.seed(1847); rng=np.random.default_rng(1847)
INK='#163a3d'; GOLD='#d6a56b'; LIGHT='#f4dfb3'; COPPER='#b75c48'
def surface(w,h,color,grain=3):
 c=np.array(Image.new('RGB',(1,1),color))[0,0].astype(float); y,x=np.mgrid[:h,:w]; n=rng.normal(0,grain,(h,w))+1.2*np.sin(x*2.5)+.8*np.cos(y*2.1); a=np.clip(c+n[:,:,None],0,255).astype('uint8'); return Image.fromarray(a).convert('RGBA')
def save(im,name):
 p=OUT/name;p.parent.mkdir(parents=True,exist_ok=True); im.save(p,optimize=True)
def rounded(im,r=14):
 m=Image.new('L',im.size);ImageDraw.Draw(m).rounded_rectangle((2,2,im.width-3,im.height-3),r,fill=255);im.putalpha(m);return im
def printwear(im,amount=3):
 a=np.array(im).copy(); noise=rng.normal(0,amount,a.shape[:2]); y,x=np.mgrid[:a.shape[0],:a.shape[1]]; pigment=(a[:,:,0]>130)&(a[:,:,1]>90); etch=(np.sin((x+y*.35)*1.2)>0.87)*pigment*13; a[:,:,:3]=np.clip(a[:,:,:3].astype(float)+noise[:,:,None]-etch[:,:,None],0,255);return Image.fromarray(a)
y,x=np.mgrid[0:512,0:512]/511*2*np.pi
for idx,name in enumerate(['background.png','background_flow.png','background_grain.png']):
 f=np.sin(x+1.3*np.sin(y))+np.cos(y*2+.7*np.sin(2*x))*.55+np.sin(3*x-2*y)*.24
 if idx==1:f=np.sin(2*x+np.sin(y)*2)+np.cos(y-x)*.5
 if idx==2:f=np.sin(93*x)*np.cos(109*y)*.4+np.sin(2*x-y)*.3
 t=(np.tanh(f*.9)+1)/2; lo=np.array([12,40,40]); hi=np.array([29,77,72]);a=(lo+(hi-lo)*t[:,:,None]).astype('uint8');a[-1]=a[0];a[:,-1]=a[:,0];save(Image.fromarray(a).convert('RGBA'),name)
for name,w,h,col in [('panel.png',256,256,'#183d3e'),('button.png',256,96,'#ab5941'),('card_front.png',256,352,'#efdfbc'),('card_back.png',256,352,'#214a4b')]:
 im=surface(w,h,col);d=ImageDraw.Draw(im)
 for k,c in [(3,'#122f32'),(5,'#b9915f'),(8,'#5d6554')]:d.rounded_rectangle((k,k,w-k-1,h-k-1),12,outline=c,width=1)
 if name=='button.png':
  d.line((18,12,w-18,12),fill='#e6b577',width=2);d.line((18,h-12,w-18,h-12),fill='#693e36',width=3)
 if name=='card_front.png':
  d.rounded_rectangle((13,13,w-14,h-14),7,outline='#cbb893');d.rounded_rectangle((17,17,w-18,h-18),5,outline='#e0cda8')
 if name=='card_back.png':
  for k in range(26):
   pts=[]
   for t in np.linspace(0,2*math.pi,700):
    rr=1+.13*math.cos(8*t+k*.19);pts.append((128+(30+k*2.8)*math.cos(t)*rr,176+(43+k*4.0)*math.sin(t)*rr))
   d.line(pts,fill=GOLD if k%4==0 else '#558179',width=1)
  for cx,cy in [(30,30),(226,30),(30,322),(226,322)]:
   for r in [4,8,12]:d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=GOLD)
  d.ellipse((103,151,153,201),fill=INK,outline=GOLD,width=2);d.line((116,163,128,190,140,163),fill=LIGHT,width=3)
 save(rounded(im),name)
S=2
class Engraver:
 def __init__(self,im):self.im=im;self.d=ImageDraw.Draw(im)
 def line(self,pts,fill=LIGHT,width=1):self.d.line([(int(x*S),int(y*S)) for x,y in pts],fill=fill,width=max(1,int(width*S)))
 def poly(self,pts,fill=GOLD):self.d.polygon([(int(x*S),int(y*S)) for x,y in pts],fill=fill)
 def box(self,b,fill=None,outline=GOLD,width=1):self.d.rectangle(tuple(int(v*S) for v in b),fill=fill,outline=outline,width=max(1,int(width*S)))
 def oval(self,b,fill=None,outline=GOLD,width=1):self.d.ellipse(tuple(int(v*S) for v in b),fill=fill,outline=outline,width=max(1,int(width*S)))
 def arc(self,b,a,z,fill=LIGHT,width=1):self.d.arc(tuple(int(v*S) for v in b),a,z,fill=fill,width=max(1,int(width*S)))
 def star(self,x,y,r=8):self.poly([(x+math.sin(t*math.pi/4)*(r if t%2==0 else r*.2),y+math.cos(t*math.pi/4)*(r if t%2==0 else r*.2)) for t in range(8)],LIGHT)
 def hatch(self,b,step=5):
  x,y,X,Y=b
  for yy in range(int(y),int(Y),step):self.line([(x,yy),(X,yy+3)],INK,.6)
 def gear(self,x,y,r):
  self.poly([(x+math.cos(t*math.pi/24)*(r if t%4<2 else r*.85),y+math.sin(t*math.pi/24)*(r if t%4<2 else r*.85)) for t in range(48)],GOLD);self.oval((x-r*.65,y-r*.65,x+r*.65,y+r*.65),INK,LIGHT);self.oval((x-5,y-5,x+5,y+5),GOLD)
 def lantern(self,x,y,s=1):
  self.arc((x-14*s,y-54*s,x+14*s,y-23*s),180,360,GOLD,2);self.poly([(x-25*s,y-27*s),(x,y-43*s),(x+25*s,y-27*s)],GOLD)
  self.box((x-21*s,y-26*s,x+21*s,y+28*s),INK,GOLD,2);self.oval((x-13*s,y-20*s,x+13*s,y+25*s),'#d88951',LIGHT)
  for k in [-17,0,17]:self.line([(x+k*s,y-25*s),(x+k*s,y+28*s)],GOLD,2)
  self.box((x-26*s,y+28*s,x+26*s,y+34*s),GOLD)
 def dial(self,x,y,r):
  self.oval((x-r,y-r,x+r,y+r),GOLD,LIGHT,2);self.oval((x-r+5,y-r+5,x+r-5,y+r-5),INK,GOLD)
  for k in range(32):
   t=k*math.pi/16;self.line([(x+math.cos(t)*(r-7),y+math.sin(t)*(r-7)),(x+math.cos(t)*(r-(14 if k%4==0 else 10)),y+math.sin(t)*(r-(14 if k%4==0 else 10)))])
  self.line([(x-13,y+15),(x+21,y-26)],LIGHT,3);self.oval((x-4,y-4,x+4,y+4),COPPER)
def base(family,i):
 colors={'passive':'#824a3f','planet':'#234960','tarot':'#55435b','voucher':'#746039','pack':'#275956'}
 im=surface(384,512,colors[family],2);g=Engraver(im);g.box((5,5,187,251),None,GOLD,2);g.box((10,10,182,246),None,'#be9468',.6)
 for k in range(64):
  t=k*math.pi/32;g.line([(96+42*math.cos(t),122+42*math.sin(t)),(96+150*math.cos(t),122+150*math.sin(t))], '#997257' if family=='passive' else '#65776b',.35)
 g.oval((24,48,168,199),None,GOLD,.7);g.oval((28,52,164,195),None,GOLD,.5)
 for k in range(150):
  xx=random.randrange(16,177);yy=random.randrange(16,240);g.line([(xx,yy),(xx+random.randrange(1,4),yy)],GOLD,.35)
 for yy in [22,231]:
  g.line([(24,yy),(76,yy)],GOLD);g.line([(116,yy),(168,yy)],GOLD);g.star(96,yy,5)
 return im,g
def passive(g,id,i):
 if id in ['twins','wage']:
  g.lantern(65,123,.8);g.lantern(126,140,.8) if id=='twins' else g.star(135,85,20)
 elif id in ['even','reserve']:
  g.dial(96,126,53);g.box((73,184,119,190),GOLD)
  if id=='reserve':g.gear(96,125,21)
 elif id in ['red','black']:
  g.poly([(59,83),(124,72),(139,177),(74,186)],GOLD);g.oval((57,72,125,93),GOLD,LIGHT);g.oval((73,174,141,195),GOLD,LIGHT)
  for k in range(36):g.line([(64+k*.38,94+k*2.1),(126+k*.32,83+k*2.6)],'#bb5145' if id=='red' else INK,1.5)
  g.line([(134,160),(155,178),(151,208),(114,210)],LIGHT,1.5);g.line([(147,101),(128,171)],LIGHT,2)
 elif id in ['ledger','bank']:
  g.poly([(49,73),(127,59),(145,170),(64,191)],GOLD);g.poly([(55,78),(121,68),(135,165),(68,181)],INK)
  for k in range(12):g.line([(66,88+k*6),(122,77+k*6)],'#70897a',.8)
  g.box((97,110,144,133),GOLD);g.oval((112,116,119,126),INK)
  if id=='bank':g.dial(95,136,24)
 elif id=='trio':
  for xx in [57,95,133]:g.line([(xx,68),(xx-12,189)],GOLD,8);g.line([(xx+2,68),(xx-10,189)],LIGHT,1)
  for yy in range(85,190,16):g.line([(40,yy),(149,yy-8)],INK,6);g.line([(40,yy-2),(149,yy-10)],GOLD,2)
 elif id=='ribbon':
  for k in range(26):g.line([(48+math.sin(t/17+k*.018)*32+k*2.5,t) for t in range(65,193)],LIGHT if k%5==0 else '#69aaa2',1)
 elif id=='prism':
  g.poly([(96,65),(145,161),(47,161)],GOLD);g.poly([(96,72),(96,150),(53,157)],'#75a69b');g.poly([(96,72),(96,150),(138,157)],'#bd6658');g.poly([(53,157),(96,150),(138,157),(96,184)],LIGHT)
  for k in range(12):g.line([(96,75+k*6),(138-k*2,157)],'#e7bd82',.6)
 elif id=='court':
  g.box((49,145,145,180),GOLD);g.hatch((53,152,141,176));g.poly([(64,140),(68,103),(56,83),(81,96),(96,71),(111,96),(136,83),(124,104),(128,140)],GOLD)
  for xx in [77,96,115]:g.oval((xx-4,115,xx+4,123),COPPER,LIGHT)
 elif id in ['ace','odd','ember']:
  if id=='ace':g.dial(96,130,45);g.star(96,123,57);g.star(96,123,28)
  else:
   g.poly([(66,175),(52,145),(73,123),(79,84),(95,108),(116,64),(114,120),(141,142),(126,177),(102,190)],COPPER);g.poly([(80,173),(74,147),(95,124),(100,95),(111,143),(121,155),(103,180)],GOLD);g.poly([(91,172),(90,151),(102,136),(111,167)],LIGHT)
   if id=='odd':g.line([(133,72),(115,107),(137,103),(121,130)],LIGHT,3)
   else:g.line([(83,186),(117,186),(125,202)],GOLD,3)
 elif id=='first':
  g.poly([(51,161),(67,140),(69,105),(80,85),(111,85),(124,105),(126,141),(144,161)],GOLD);g.oval((50,151,145,173),GOLD,LIGHT,2);g.oval((85,166,108,185),GOLD);g.arc((80,65,112,94),180,360,LIGHT,3)
  for xx in range(76,122,7):g.line([(xx,105),(xx-5,147)],'#855c3f',1)
 elif id=='last':
  g.poly([(73,190),(81,100),(110,100),(124,190)],GOLD);g.box((74,86,118,112),INK,LIGHT,2);g.poly([(68,85),(96,63),(125,85)],COPPER)
  for yy in range(120,185,20):g.poly([(80,yy),(112,yy-5),(115,yy+5),(78,yy+12)],COPPER)
  g.poly([(74,94),(20,74),(20,117)],'#b5a173');g.poly([(118,94),(171,74),(171,117)],'#b5a173')
 elif id=='compact':
  g.box((48,104,143,171),INK,GOLD,3);g.gear(76,133,28);g.gear(124,149,21);g.box((62,76,82,105),GOLD);g.box((107,87,132,105),GOLD);g.line([(51,178),(142,178)],LIGHT,4)
 elif id=='growth':
  g.line([(92,70),(92,195)],GOLD,8);g.poly([(48,83),(130,83),(149,100),(130,116),(48,116)],GOLD);g.poly([(141,127),(61,127),(43,142),(61,157),(141,157)],'#6b9b83');g.hatch((57,91,128,109),4)
 elif id=='echo':
  g.oval((48,105,145,196),INK,GOLD,2);g.box((48,145,145,194),INK,GOLD,2);g.line([(96,107),(128,85)],GOLD,17);g.line([(96,107),(128,85)],LIGHT,2);g.oval((117,73,139,95),INK,GOLD,3)
  for xx in range(59,142,15):g.line([(xx,150),(xx,186)],GOLD,.7)
  for xx,yy in [(48,74),(149,62),(86,54)]:g.star(xx,yy,7)
engine=(ROOT/'core/game_engine.gd').read_text()
def keys(block,nextblock):return re.findall(r'"([a-z_]+)":',engine.split('const '+block+' = {')[1].split(nextblock)[0])
mods=keys('MODS','const ITEMS');items=keys('ITEMS','const BOSSES');vouchers=keys('VOUCHERS','const HANDS')
manifest={'version':3,'license':'MIT','generated_by':'tools/art_v3/generate.py','assets':{},'items':{},'atlas':{'path':'res://assets/v3/items_atlas.png','cell_size':[196,260],'padding':2}}; allart=[]
for fam,ids in [('passive',mods),('planet',[v for v in items if v.startswith('study_')]),('tarot',[v for v in items if not v.startswith('study_')]),('voucher',vouchers),('pack',['passive','planet','tarot','playing_card'])]:
 manifest['items'][fam]={}
 for i,id in enumerate(ids):
  im,g=base(fam,i)
  if fam=='passive':passive(g,id,i)
  elif fam=='planet':
   r=34+i%4*4;g.oval((96-r,125-r,96+r,125+r),['#b18d64','#669b9a','#ba785b'][i%3],LIGHT,1)
   for yy in range(-r+2,r,3):
    dx=math.sqrt(r*r-yy*yy);g.line([(96-dx,125+yy),(96+dx,125+yy+math.sin(yy*.2)*2)],INK,.7)
   g.arc((27,93,167,161),5,190,LIGHT,2);g.arc((27,88,167,157),190,355,GOLD,1)
   for k in range(i%5+1):
    a=k*1.2+i;xx=96+67*math.cos(a);yy=125+73*math.sin(a);g.oval((xx-4,yy-4,xx+4,yy+4),LIGHT)
   for k in range(8):g.star(30+(k*37+i*13)%130,48+(k*29)%150,3)
  elif fam=='tarot':
   if id.endswith('dye'):
    col={'diamond_dye':'#d7a34f','club_dye':'#72a17c','scarlet_dye':'#c45c54','ink_dye':'#375e73'}[id]
    g.box((81,74,111,96),GOLD);g.poly([(80,97),(111,97),(117,114),(133,131),(129,187),(63,187),(59,131),(74,113)],LIGHT);g.poly([(65,138),(126,138),(123,180),(69,180)],col)
    for yy in range(143,179,5):g.line([(72,yy),(121,yy-2)],INK,.6)
    g.line([(76,117),(69,130),(72,159)],LIGHT,3);g.star(97,155,18)
   elif id=='rank_copy':
    for xx in [70,118]:g.oval((xx-30,76,xx+30,160),GOLD,LIGHT,2);g.oval((xx-23,83,xx+23,153),INK,GOLD);g.line([(xx,161),(xx,192)],GOLD,8);g.line([(xx-13,133),(xx+13,103)],LIGHT,2)
   elif id=='prune':
    g.oval((48,151,85,188),None,LIGHT,4);g.oval((108,151,145,188),None,LIGHT,4);g.line([(78,159),(131,72),(94,142),(113,160),(61,72),(94,142)],GOLD,5);g.oval((89,136,100,147),LIGHT)
   elif id=='rank_lift':
    for k in range(5):g.box((49+k*16,174-k*20,68+k*16,191),GOLD)
    g.line([(48,145),(130,64),(113,67),(130,64),(127,83)],LIGHT,3)
   else:g.box((50,97,133,176),GOLD);g.hatch((55,104,127,171),4);g.line([(77,152),(143,70)],LIGHT,7);g.poly([(71,159),(77,143),(84,150)],INK);g.star(71,159,14)
  elif fam=='voucher':
   g.box((30,62,162,204),INK,GOLD,2)
   for yy in range(69,199,8):g.oval((26,yy,34,yy+4),'#746039');g.oval((158,yy,166,yy+4),'#746039')
   passive(g,['reserve','ribbon','ledger','bank'][i],i);g.line([(46,192),(145,192)],LIGHT,2)
  else:
   g.poly([(39,51),(150,51),(158,206),(32,206)],INK);g.box((35,52,155,66),GOLD);g.box((32,194,158,208),GOLD)
   for xx in range(37,155,5):g.line([(xx,53),(xx,65)],INK,.7);g.line([(xx,196),(xx,207)],INK,.7)
   passive(g,['prism','ace','ember','court'][i],i);g.line([(43,74),(37,185)],LIGHT,1);g.line([(149,75),(153,186)],GOLD,1)
  im=rounded(printwear(im,3),20).resize((192,256),Image.Resampling.LANCZOS);name=f'items/{fam}/{id}.png';save(im,name)
  n=len(allart);rect=[(n%8)*196+2,(n//8)*260+2,192,256];manifest['items'][fam][id]={'path':'res://assets/v3/'+name,'atlas_rect':rect};allart.append((fam,id,im))
atlas=Image.new('RGBA',(1568,math.ceil(len(allart)/8)*260))
for n,(fam,id,im) in enumerate(allart):atlas.paste(im,((n%8)*196+2,(n//8)*260+2))
save(atlas,'items_atlas.png')
fontpath='/usr/share/fonts/noto/NotoSerif-Bold.ttf';font=ImageFont.truetype(fontpath,86);small=ImageFont.truetype(fontpath,18)
logo=Image.new('RGBA',(768,256));d=ImageDraw.Draw(logo)
for text,y in [('VELVET',8),('CIRCUIT',100)]:
 box=d.textbbox((0,0),text,font=font);xx=(768-(box[2]-box[0]))//2;d.text((xx+3,y+5),text,font=font,fill=INK,stroke_width=2);d.text((xx,y),text,font=font,fill=LIGHT,stroke_width=1,stroke_fill=GOLD)
d.text((267,218),'A GAME OF FINE MARGINS',font=small,fill=GOLD)
for xx in [89,679]:
 for k in range(5):d.arc((xx-35-k*3,53-k*7,xx+35+k*3,195+k*7),-90 if xx<384 else 90,90 if xx<384 else 270,fill=GOLD,width=1)
save(printwear(logo,2),'logo.png')
for name in ['background','background_flow','background_grain','panel','button','card_front','card_back','logo']:
 im=Image.open(OUT/(name+'.png'));manifest['assets'][name]={'path':'res://assets/v3/'+name+'.png','size':list(im.size),'repeat':name.startswith('background')}
for name,margin in [('panel',24),('button',20),('card_front',14)]:manifest['assets'][name]['nine_slice_insets']=[margin]*4
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+chr(10))
f=ImageFont.truetype('/usr/share/fonts/noto/NotoSans-Regular.ttf',12)
sheet=Image.new('RGB',(8*196,math.ceil(len(allart)/8)*286),'#102e30');d=ImageDraw.Draw(sheet)
for n,(fam,id,im) in enumerate(allart):
 xx=n%8*196;yy=n//8*286;sheet.paste(im,(xx+2,yy),im);d.text((xx+5,yy+258),id,font=f,fill=LIGHT)
save(sheet,'contact_items.jpg')
sheet=Image.new('RGBA',(1024,850),'#102e30');sheet.alpha_composite(Image.open(OUT/'logo.png'),(128,0))
for name,pos in [('background',(0,270)),('panel',(520,270)),('button',(520,540)),('card_front',(0,490)),('card_back',(264,490))]:
 im=Image.open(OUT/(name+'.png'));im=im.resize((512,200)) if name=='background' else im;sheet.alpha_composite(im,pos)
save(sheet.convert('RGB'),'contact_surfaces.jpg')
print('Generated',len(allart),'item illustrations;',sum(p.stat().st_size for p in OUT.rglob('*.png')),'PNG bytes')

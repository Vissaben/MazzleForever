"""Offline layout proof from runtime geometry and original assets, not a game capture."""
from pathlib import Path
import sys
from original_profiles import ROOT, plain
sys.path.insert(0, str(ROOT / '.validation/python'))
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

CORE = ROOT / 'Interface/AddOns/MazzleUI'
ANCHORS = {'BOTTOMLEFT': (0,0), 'BOTTOM': (.5,0), 'BOTTOMRIGHT': (1,0),
           'LEFT': (0,.5), 'CENTER': (.5,.5), 'RIGHT': (1,.5),
           'TOPLEFT': (0,1), 'TOP': (.5,1), 'TOPRIGHT': (1,1)}


def render(width, height, physical=1):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f'UIParent={{GetWidth=function() return {width} end,GetHeight=function() return {height} end,GetEffectiveScale=function() return {physical} end}}')
    ns = lua.table()
    ns.db = lua.table(scale=1)
    for source in ('UnitStyles.lua', 'Geometry.lua'):
        lua.execute('return assert(loadstring(...))', (CORE/'Forever'/source).read_text())('MazzleUI', ns)
    g = plain(ns.ComputeGeometry(width,height))
    style = plain(ns.SelectUnitStyle())
    img = Image.new('RGBA',(width,height),(27,33,38,255))
    draw = ImageDraw.Draw(img)
    skin = ROOT/'Interface/AddOns/MazzleUI_Skin_Noob123_BlackMetal'

    def image_at(path,x,y,w,h):
        art=Image.open(path).convert('RGBA').resize((round(w),round(h)),Image.Resampling.LANCZOS)
        img.alpha_composite(art,(round(x),round(height-y-h)))

    def rectangle(x,y,w,h,color,outline=None):
        draw.rectangle((x,height-y-h,x+w,height-y),fill=color,outline=outline)

    def text_at(text,x,y,w,h,size=10,color='white',align='center'):
        font=ImageFont.truetype(str(ROOT/'Fonts/ARIALN.ttf'),round(size))
        box=draw.multiline_textbbox((0,0),text,font=font,align=align,spacing=0)
        tx=x if align=='left' else (x+w-(box[2]-box[0]) if align=='right' else x+(w-box[2]+box[0])/2)
        draw.multiline_text((tx,height-y-h+(h-box[3]+box[1])/2-box[1]),text,font=font,fill=color,spacing=0,align=align,
                            stroke_width=1,stroke_fill=(0,0,0,190))

    x=0
    for n in range(1,5):
        w=g['edge'] if n in (1,4) else (width-2*g['edge'])/2
        image_at(skin/f'Bottom{n}.blp',x,0,w,g['height']);x+=w
    image_at(skin/'FloatingCave.blp',(width-g['caveSize'])/2,g['caveY'],g['caveSize'],g['caveSize'])

    # Schematic map and model contents; bounding boxes use real profile sizes.
    m=g['mapSize']; mb=g['mapBottom']
    rectangle((width-m)/2,mb,m,m,(52,66,52,255))
    for n in range(1,4):
        rectangle((width-m)/2+n*m/4,mb,1,m,(63,78,63,255))
        rectangle((width-m)/2,mb+n*m/4,m,1,(63,78,63,255))
    aw,ah=256*m/131,256*m/128
    image_at(skin/'MazzleUIMinimapBorder.blp',width/2+(128-166.5)*m/131-aw/2,mb+m/2+(100-128)*m/128-ah/2,aw,ah)
    text_at('MAP',(width-m)/2,mb,m,m,11/physical,'#bfd6be')

    for side in (-1,1):
        for upper in (0,1):
            columns=12//g['actionRows'];cell=g['actionRow']
            left=width/2+g['gap'] if side==1 else width/2-g['gap']-columns*cell
            for index in range(12):
                # Sample occupied slots; empty slots are hidden in the runtime.
                if index not in ((0,1,2,5,8,11) if upper else (0,1,3,4,6,9)):continue
                bx=left+(index%columns)*cell
                by=g['actionBottom']+(upper*g['actionRows']+index//columns)*cell
                rectangle(bx,by,cell-2,cell-2,(35,40,47,255),(110,116,125,255))
                text_at(str(index+1),bx,by,cell-2,cell-2,8/physical,'#c2c5ca')

    def model(x,y,w,h):
        # Silhouette indicates the model rectangle only; it is not a game model.
        rectangle(x,y,w,h,None,(58,72,82,255))
        cx=x+w/2
        draw.ellipse((cx-w*.12,height-y-h*.95,cx+w*.12,height-y-h*.71),fill=(118,131,139,255))
        draw.polygon([(cx-w*.22,height-y-h*.69),(cx+w*.22,height-y-h*.69),(cx+w*.15,height-y-h*.3),
                      (cx+w*.23,height-y),(cx+w*.06,height-y),(cx,height-y-h*.28),(cx-w*.06,height-y),
                      (cx-w*.23,height-y),(cx-w*.15,height-y-h*.3)],fill=(91,105,116,255))

    def unit(kind,x,y,number=1):
        p=style[kind]; s=p['scale']*g['scale']
        refs={'Unit Frame':(x,y,p['width']*s,p['height']*s), 'UIParent':(0,0,width,height)}
        indices= {'party':[1,2,3,4,5,6], 'pet':[1,2,3,4,5], 'player':[1,2,3,4], 'target':[8,6,2,1,3,9]}[kind]
        def spec_rect(key,spec):
            if key in refs:return refs[key]
            relative=refs[spec['attach']]; a=ANCHORS[spec['attachpoint']]; b=ANCHORS[spec['attachto']]
            w,h=spec['width']*s,spec['height']*s
            rect=(relative[0]+relative[2]*b[0]-w*a[0]+spec.get('xoffset',0)*s,
                  relative[1]+relative[3]*b[1]-h*a[1]+spec.get('yoffset',0)*s,w,h)
            refs[key]=rect;return rect
        for i,c in ((1,(180,44,43,255)),(2,(48,86,180,255))):
            rectangle(*spec_rect('_HealthBar' if i==1 else '_ManaBar',p['bars'][i]),c)
        if kind in ('party','pet'):
            r=spec_rect('_Pedestal',p['TextBox'][10]); image_at(CORE/'Art/pedestal.tga',*r)
            sz=(92 if kind=='party' else 75)*s
            model(r[0]+r[2]/2-sz/2,r[1]+(5 if kind=='party' else 6)*s,sz,sz)
        if kind=='player':
            ci=p['ClassIcon']; ci=dict(ci,width=ci['size'],height=ci['size'])
            spec_rect('_ClassIcon',ci)
            r=spec_rect('_Pedestal',p['TextBox'][8]);image_at(CORE/'Art/pedestal.tga',*r)
            model(r[0]+r[2]/2-51*s,r[1]+5*s,100*s,100*s)
        names={'party':f'Party {number}','pet':'Imp','player':'Player','target':'Target'}
        texts={1:names[kind],2:'15 Shaman' if kind!='pet' else '5 Demon',3:'68\n100',4:'100%',5:'68%',6:'100\n100'}
        compact=height*physical<800
        if compact and kind in ('party','pet'):texts.update({3:'68',6:'100'})
        if kind=='player':texts.update({3:'68/100',4:'100/100'})
        if kind=='target':texts={1:'68%',2:'15 Humanoid',3:'100%',6:'Target',8:'Looking at Player',9:'68/100\n100/100'}
        for i in indices:
            spec=p['TextBox'][i]
            if kind=='party' and i==2:spec=dict(spec,height=16)
            r=spec_rect('_TextBox_'+str(i),spec)
            if compact and kind in ('party','pet') and i in (4,5):continue
            size=max(spec['textheight']*s,(8 if spec.get('label')=='Name' else 7)/physical)
            text_at(texts.get(i,''),*r,size,align=spec.get('justify','CENTER').lower())

    unit('player',g['playerX'],g['playerY'])
    unit('pet',g['petX'],g['petY'])
    for index,pos in g['party'].items(): unit('party',pos['x'],pos['y'],index)
    ts=style['target']['scale']*g['scale']
    lh=max(12*ts,7/physical+2*ts)
    bottom=max(131*ts,115*ts+2*lh+3*ts)
    model(width/2-60*ts,bottom,120*ts,min(120*ts,g['caveY']+g['caveSize']*(1-73/256)-bottom))
    unit('target',width/2-style['target']['width']*ts/2,g['targetTop']-style['target']['height']*ts)
    # The pane/utility placeholders below share the runtime's actual bounds.
    cs=g['chatScale']; cx=g['chatX']; cy=g['chatBottom']; cw=g['chatWidth']*cs; ch=g['chatHeight']*cs
    rectangle(cx,cy,cw,ch,(0,0,0,70))
    text_at('General   Whispers',cx,cy+ch,cw,24,8/physical,'#cdbb91','left')
    for i,line in enumerate(('Party: Ready.', 'General chat', 'Whispers')):
        text_at(line,cx+2,cy+ch-(i+1)*16/physical,cw-4,16/physical,max(14*cs,9/physical),'#c3c9d0','left')
    rectangle(cx-5*cs,cy-34*cs,cw+10*cs,32*cs,(12,15,18,210),(96,105,112,255))
    text_at('Chat input',cx,cy-34*cs,cw,32*cs,8/physical,'#c3c9d0','left')
    rectangle(cx-32*cs,cy,26*cs,ch,(35,40,46,200))
    rx=width-g['sideInset']-g['sideWidth']; rw=g['sideWidth']
    top=g['height']-10*g['scale']; line=g['infoLine']
    text_at('17:48   60 FPS',rx,top-line,rw*.6,line,g['infoFont'],'#d7c96f','left')
    text_at('40 ms   2.0 MB',rx,top-2*line,rw*.64,line,g['infoFont'],'#d7c96f','left')
    text_at('Menu  M',rx+rw*.6,top-line,rw*.4,line,g['infoFont'],'#c4c9c8','right')
    text_at('1g 23s 45c',rx+rw*.64,top-2*line,rw*.36,line,g['infoFont'],'#d7c96f','right')
    text_at('Bags: 6/16',rx,g['bagsBottom'],g['damageWidth'],24*g['bagsScale'],g['infoFont'],'#d7c96f','left')
    bs=g['bagsScale']; bx=rx+rw-270*bs
    for i in range(6):rectangle(bx+i*45*bs,g['bagsBottom'],42*bs,45*bs,(40,45,53,230),(107,115,123,255))
    ly=g['logBottom']; lh=g['logHeight']; header=g['logHeader']; dw=g['damageWidth']
    rectangle(rx+dw+g['logGap']/2,ly,1,lh,(60,64,66,255))
    text_at('Dmg Out',rx,ly+lh-header,dw,header,g['logFont'],'#c4c9c8','left')
    text_at('Combat Log',rx+dw+g['logGap'],ly+lh-header,g['combatWidth'],header,g['logFont'],'#c4c9c8','left')
    row=min(g['logFont']+2,(lh-header-2)/4)
    for i,(label,color) in enumerate((('Damage','#888888'),('1.2K','#ffe58c'),('DPS','#888888'),('94','#ffe58c'))):
        text_at(label,rx,ly+lh-header-2-(i+1)*row,dw,row,g['infoFont'] if i%2==0 else g['logFont'],color,'left')
    for i,label in enumerate(('Your spell hits', 'the target.', 'You gain 45 XP.')):
        text_at(label,rx+dw+g['logGap'],ly+lh-header-(i+1)*(g['logFont']+1),g['combatWidth'],g['logFont']+1,g['logFont'],'#c3c9d0','left')
    # The native micro menu is collapsed initially; the header opens its popout.
    text_at('XP / reputation',rx,g['statusBottom'],rw,12,7/physical,'#85a6db')
    rectangle(rx-78,g['menuBottom'],62,24,(32,53,66,230))
    text_at('Actions',rx-78,g['menuBottom'],62,24,8/physical,'#d7cd94')
    for label,by,rows,col in (('Buffs',g['buffBottom'],2,(70,116,83,230)),('Debuffs',g['debuffBottom'],1,(126,66,65,230))):
        for row in range(rows):
            for i in range(8):rectangle(g['sideInset']+i*32,by+row*41,27,27,col,(142,149,158,255))
        text_at(label,g['sideInset'],by+rows*41,256,18,9/physical,'#c3c9d0','left')
    text_at('Northshire…',(width-m)/2+2,mb+m-18,m-4,16,8/physical,'#e4d5ae')
    text_at('48.2, 42.1',(width-m)/2+2,mb+2,m-4,14,7/physical,'#d1dbcf')
    for side in (-1,1):
        bx=width/2+side*(m/2+3)-(16 if side==-1 else 0)
        for by in (mb+m-18,mb+m/2-8):rectangle(bx,by,16,16,(55,62,70,255),(140,148,158,255))
    text_at('OFFLINE LAYOUT PROOF  |  models and map are placeholders',18,height-44,width-36,30,13/physical,'#d2d8de','left')
    if physical!=1:img=img.resize((round(width*physical),round(height*physical)),Image.Resampling.LANCZOS)
    out=ROOT/f'.validation/layout-{round(width*physical)}x{round(height*physical)}.png'
    img.convert('RGB').save(out)
    print(out)
    return g


if __name__=='__main__':
    for dimensions in ((1920,1080,1),(1368,768,.625),(1024,768,1)):
        render(*dimensions)

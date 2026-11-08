-- Static geometry from the original DUF and panel profiles, in UIParent units.
local _, M = ...
local anchors = {BOTTOMLEFT={0,0}, BOTTOM={0.5,0}, BOTTOMRIGHT={1,0},
    LEFT={0,0.5}, CENTER={0.5,0.5}, RIGHT={1,0.5}, TOPLEFT={0,1}, TOP={0.5,1}, TOPRIGHT={1,1}}

function M.SelectUnitStyle()
    local aspect = UIParent:GetWidth() / UIParent:GetHeight()
    local chosen, difference
    for ratio, profile in pairs(M.unitStyles) do
        local distance = math.abs(ratio - aspect)
        if not difference or distance < difference then chosen, difference = profile, distance end
    end
    return chosen
end

function M.ProfileRects(profile, indices, modelSize)
    local rects = {["Unit Frame"]={0,0,profile.width,profile.height}}
    local left, bottom, right, top = 0,0,profile.width,profile.height
    local function Add(key, spec)
        local relative = assert(rects[spec.attach], "Missing original anchor: " .. spec.attach)
        local from, to = anchors[spec.attachpoint], anchors[spec.attachto]
        local x = relative[1] + to[1]*relative[3] - from[1]*spec.width + (spec.xoffset or 0)
        local y = relative[2] + to[2]*relative[4] - from[2]*spec.height + (spec.yoffset or 0)
        rects[key] = {x,y,spec.width,spec.height}
        left, bottom = math.min(left,x), math.min(bottom,y)
        right, top = math.max(right,x+spec.width), math.max(top,y+spec.height)
    end
    Add("_HealthBar",profile.bars[1]); Add("_ManaBar",profile.bars[2])
    for _, index in ipairs(indices) do Add("_TextBox_"..index,profile.TextBox[index]) end
    if modelSize then
        if modelSize==100 then
            local icon={}
            for key,value in pairs(profile.ClassIcon) do icon[key]=value end
            icon.width,icon.height=icon.size,icon.size
            Add("_ClassIcon",icon)
        end
        Add("_Pedestal",profile.TextBox[modelSize==100 and 8 or 10])
        Add("_Model",{attach="_Pedestal",attachpoint="BOTTOM",attachto="BOTTOM",
            width=modelSize,height=modelSize,xoffset=modelSize==100 and -1 or 0,yoffset=modelSize==75 and 6 or 5})
    end
    return {left=left,bottom=bottom,right=right,top=top,rects=rects}
end

function M.ComputeGeometry(width,height)
    local style = M.SelectUnitStyle()
    local scale = math.min(height/1200*M.db.scale,width/1536)
    local edge = math.min(470*scale,(width-476)/2)
    local g = {width=width,screenHeight=height,scale=scale,edge=edge,height=238*scale,
        aspect=style.aspect,mapSize=129*scale,mapBottom=9*scale,targetLift=0}
    g.gap = math.max(86*scale,g.mapSize/2+22)
    g.inner = width/2-edge-g.gap-10
    -- Forty-eight current slots, arranged in the original two rows per side
    -- when they fit. Narrow screens wrap to six columns without losing slots.
    g.actionRows = g.inner >= 292 and 1 or 2
    local columns = 12/g.actionRows
    g.iconScale = math.max(0.5,math.min(0.8,math.floor(g.inner/(columns*49)*10)/10))
    g.actionRow = 49*g.iconScale
    g.actionBottom = 18*scale
    g.actionTop = g.actionBottom + g.actionRow*g.actionRows*2
    g.party = {}
    local p = style.party
    local bounds = M.ProfileRects(p,{1,2,3,4,5,6},92)
    local s = p.scale*scale
    local groupBottom = math.huge
    for index=1,4 do
        local x = width/2 + (p.xos[index]*p.scale-style.aspect*600)*scale
        local y = (1200+(p.yos[index]-p.height)*p.scale)*scale
        g.party[index]={x=x,y=y}
        groupBottom=math.min(groupBottom,y+bounds.bottom*s)
    end
    -- Native buttons cannot shrink below 50%; preserve room over their wrapped rows.
    local lift = math.max(0,g.actionTop+8-groupBottom)
    g.partyBounds=bounds
    g.partyLeft,g.partyBottom,g.partyRight,g.partyTop=math.huge,math.huge,-math.huge,-math.huge
    for _, pos in ipairs(g.party) do
        pos.y=pos.y+lift
        g.partyLeft=math.min(g.partyLeft,pos.x+bounds.left*s)
        g.partyBottom=math.min(g.partyBottom,pos.y+bounds.bottom*s)
        g.partyRight=math.max(g.partyRight,pos.x+bounds.right*s)
        g.partyTop=math.max(g.partyTop,pos.y+bounds.top*s)
    end
    g.playerX=style.player.xos[1]*style.player.scale*scale
    g.playerY=(1200+(style.player.yos[1]-style.player.height)*style.player.scale)*scale
    g.playerBounds=M.ProfileRects(style.player,{1,2,3,4},100)
    local pet=style.pet
    g.petBounds=M.ProfileRects(pet,{1,2,3,4,5},75)
    g.petX=pet.xos[1]*pet.scale*scale
    g.petY=(1200+(pet.yos[1]-pet.height)*pet.scale)*scale
    g.targetTop=(1200+style.target.yos[1]*style.target.scale)*scale
    g.caveSize=256*0.81*style.target.scale*scale
    g.caveY=(style.aspect==1.6 and 143 or 149)*0.81*style.target.scale*scale
    -- The tall interior of each outer texture is only ~385 of its 470 units.
    -- Original ChatFrame1 used x=20, width=347; keep both side panes inside it.
    g.sideInset=20*edge/470
    g.sideWidth=347*edge/470
    g.chatScale=math.min(1,g.sideWidth/296,(g.height-24*scale-26)/154)
    g.chatX=g.sideInset+34*g.chatScale
    g.chatBottom=20*scale+34*g.chatScale
    g.chatWidth=math.max(250,math.floor(g.sideWidth/g.chatScale-46))
    g.chatHeight=math.max(120,math.floor((g.height-24*scale-26)/g.chatScale-34))
    -- The original right pane has an information strip over two separate logs.
    -- Keep a physical text floor when the user plays in a small window.
    local physical=UIParent:GetEffectiveScale()
    -- Native 12/13-unit text also stays legible when Windows scales the client
    -- surface separately from WoW's UI scale (e.g. a small high-DPI window).
    g.infoFont=math.max(12,10*scale,7/physical)
    g.infoLine=g.infoFont+2
    g.logFont=math.max(13,12*scale,8/physical)
    g.logBottom=20*scale
    g.logHeight=g.height-math.max(92*scale,4*g.infoLine+8)-g.logBottom
    g.logHeader=g.logFont+4
    g.damageWidth=g.sideWidth*111/347
    g.logGap=6*scale
    g.combatWidth=g.sideWidth-g.damageWidth-g.logGap
    g.combatScale=math.min(1,g.combatWidth/250,(g.logHeight-g.logHeader)/120)
    g.bagsScale=math.min(0.75,(g.combatWidth-4)/270,(2*g.infoLine-4)/45)
    g.meterScale=1
    g.meterWidth=math.max(250,math.min(400,g.sideWidth))
    g.meterHeight=200
    g.meterBottom=g.height+70
    g.menuBottom=g.height+25
    g.bagsBottom=g.logBottom+g.logHeight+3
    g.statusBottom=g.height+3
    local playerScale=style.player.scale*scale
    g.buffBottom=g.playerY+g.playerBounds.top*playerScale+18
    -- Eight columns, four possible buff rows; debuffs get their own clear area.
    g.debuffBottom=g.buffBottom+4*(40*0.9+5)+12
    g.auxiliaryBottom=math.max(g.statusBottom+32,g.partyTop+12,g.caveY+g.caveSize*(1-73/256)+12)
    return g
end

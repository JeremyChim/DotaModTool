-- Local anti-copy spell advice. Does not change modes, objectives or movement.
local X={}
local Profiles=require(GetScriptDirectory()..'/FuncLib/systems/illusion_spells')
local function Has(v,f)return math.floor(v/f)%2==1 end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Valid(u)return u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()end
local function Log(b,phase,name,count)
 local now=DotaTime()
 if phase=='clear_order'and now<(b._illusionClearLog or -1)then return end
 b._illusionClearLog=now+3
 print('[ILLUSION_RESPONSE] t='..now..' pid='..b:GetPlayerID()..' phase='..phase..' spell='..name..' visible_models='..count)
end
local function Abilities(b,now)
 local c=b._illusionSpellCache
 if c and now<c.untilTime then return c.list end
 c={untilTime=now+2,list={}};b._illusionSpellCache=c
 for slot=0,23 do
  local a=b:GetAbilityInSlot(slot)
  if a and not a:IsNull()and Profiles[a:GetName()]then
   c.list[#c.list+1]={a=a,cfg=Profiles[a:GetName()]}
  end
 end
 return c.list
end
local function Radius(a,cfg)
 local r=cfg.radius
 if cfg.nativeAOE then return math.max(0,a:GetAOERadius()*.85)end
 -- Native circle AOE can refine a known profile, but never widen the whitelist.
 if cfg.kind=='self'or cfg.kind=='point'or cfg.kind=='selfpoint'then
  local actual=a:GetAOERadius()
  if actual>0 then r=math.min(r,actual*.85)end
 end
 return r
end
local function Legal(a,cfg)
 if a:IsNull()or a:IsHidden()or a:GetLevel()==0 or a:IsUltimate()or not a:IsFullyCastable()then return false end
 local f=a:GetBehavior()
 -- Passive, channelled, toggle and autocast mechanics stay with the hero AI.
 if Has(f,2)or Has(f,128)or Has(f,512)or Has(f,4096)then return false end
 local kind=cfg.kind
 if kind=='self'or kind=='fixed'then return Has(f,4)and not Has(f,16)end
 if kind=='selfpoint'then return Has(f,4)or Has(f,16)end
 if kind=='entity'or kind=='entityline'then return Has(f,8)and Has(a:GetTargetTeam(),2)end
 return Has(f,16)
end
local function Reflects(u)
 return u:HasModifier('modifier_item_sphere_target')or u:HasModifier('modifier_item_lotus_orb_active')
  or u:HasModifier('modifier_antimage_spell_shield')or u:HasModifier('modifier_item_mirror_shield')
end
local function Count(g,b,p,cfg,r,reach,primary)
 local origin=b:GetLocation();local kind=cfg.kind;local n=0
 local dx,dy=p.x-origin.x,p.y-origin.y;local norm=math.max(1,D(p,origin));dx,dy=dx/norm,dy/norm
 for _,u in ipairs(g)do
  local q=u:GetLocation();local hit=false
  if kind=='line'or kind=='pointline'or kind=='entityline'or kind=='cone'then
   local x,y=q.x-origin.x,q.y-origin.y;local along=x*dx+y*dy;local side=math.abs(x*dy-y*dx)
   local width=kind=='cone'and math.max(r,along*math.tan((cfg.angle or 25)*math.pi/180))or r
   hit=along>=0 and along<=reach and side<=width
  else hit=D(q,p)<=r end
  if hit and(not cfg.excludePrimary or u~=primary)then n=n+1 end
 end
 return n
end
local function Choice(b,a,cfg,g)
 local r=Radius(a,cfg);if r<=0 then return nil end
 local origin=b:GetLocation();local kind=cfg.kind;local range=math.max(0,a:GetCastRange())
 local reach=math.min(range,cfg.reach or range)
 if kind=='self'or kind=='selfpoint'and not Has(a:GetBehavior(),16)then
  return {loc=origin,count=Count(g,b,origin,cfg,r,r),selfCast=true}
 end
 if kind=='fixed'then
  local angle=b:GetFacing()*math.pi/180
  local p=Vector(origin.x+math.cos(angle)*cfg.offset,origin.y+math.sin(angle)*cfg.offset,origin.z)
  return {loc=p,count=Count(g,b,p,cfg,r,r),selfCast=true}
 end
 local points={};local sx,sy=0,0
 for _,u in ipairs(g)do points[#points+1]={loc=u:GetLocation(),unit=u};sx=sx+u:GetLocation().x;sy=sy+u:GetLocation().y end
 if kind~='entity'and kind~='entityline'then points[#points+1]={loc=Vector(sx/#g,sy/#g,origin.z)}end
 local best
 for _,v in ipairs(points)do
  if D(origin,v.loc)<=range and D(origin,v.loc)>1
   and(not v.unit or kind~='entity'and kind~='entityline'or not Reflects(v.unit))then
   local n=Count(g,b,v.loc,cfg,r,reach,v.unit)
   if not best or n>best.count then best={loc=v.loc,unit=v.unit,count=n}end
  end
 end
 return best
end
local function Observe(b,now)
 local p=b._illusionClearPending;if not p then return end
 local a=p.a
 if a and not a:IsNull()and a:GetCooldownTimeRemaining()>p.cooldown+.1 then
  Log(b,'cast_observed',p.name,p.count);b._illusionClearPending=nil
 elseif now>p.at+1.2 then b._illusionClearPending=nil end
end
function X.Try(b,Fu)
 local now=DotaTime()
 if b~=GetBot()or not b or b:IsNull()or not b:IsAlive()then return false end
 Observe(b,now)
 if now<0 or not b:IsHero()or b:IsIllusion()or b:IsInvulnerable()or b:IsInvisible()
  or b:HasModifier('modifier_smoke_of_deceit')or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
  or b:IsStunned()or b:IsHexed()or b:IsSilenced()or b:NumQueuedActions()>0
  or b:GetHealth()/math.max(1,b:GetMaxHealth())<.2
  or b._enigmaCombo or b._invokerPlan or b._illusionClearPending
  or b._invokerEscape and now<b._invokerEscape.untilTime
  or now<(b._illusionClearNext or -1)or now<(b._ohaAbilityOrderAt or -999)+.3 then return false end
 b._illusionClearNext=now+.3
 local abilities=Abilities(b,now);if #abilities==0 then return false end
 local enemies=b:GetNearbyHeroes(1000,true,BOT_MODE_NONE)or{};local groups={}
 for i,u in ipairs(enemies)do
  if i>24 then break end
  if Valid(u)and u:GetPlayerID()>=0 and not u:IsInvulnerable()and not u:IsMagicImmune()
   and D(b:GetLocation(),u:GetLocation())<=650 then
   local key=u:GetPlayerID()..':'..u:GetUnitName();groups[key]=groups[key]or{};table.insert(groups[key],u)
  end
 end
 local best
 for _,g in pairs(groups)do if #g>=2 then
  local id=g[1]:GetPlayerID();local threat=b:WasRecentlyDamagedByPlayer(id,1)
  for _,u in ipairs(g)do if u:GetAttackTarget()==b then threat=true end end
  local contested=false
  for _,u in ipairs(enemies)do
   if Valid(u)and u:GetPlayerID()~=id and not Fu.IsSuspiciousIllusion(u)and GetUnitToUnitDistance(b,u)<900 then contested=true;break end
  end
  if threat then
   for _,entry in ipairs(abilities)do
    local a,cfg=entry.a,entry.cfg
    local pressure=contested or b:GetActiveMode()==BOT_MODE_RETREAT or b:GetHealth()/math.max(1,b:GetMaxHealth())<.35
    local control={lion_impale=true,nyx_assassin_impale=true,monkey_king_boundless_strike=true,
     centaur_hoof_stomp=true,slardar_slithereen_crush=true,tiny_avalanche=true,leshrac_split_earth=true,
     kunkka_torrent=true,sven_storm_bolt=true,witch_doctor_paralyzing_cask=true,invoker_deafening_blast=true}
    local cheap=not control[a:GetName()]and cfg.kind~='entity'and cfg.kind~='entityline'
     and a:GetManaCost()<=math.max(100,b:GetMaxMana()*.12)and a:GetCastPoint()<=.45
    if (not pressure or cheap)and Legal(a,cfg)and b:GetMana()-a:GetManaCost()>=math.max(150,b:GetMaxMana()*(pressure and .35 or .2))
     and now>=((b._illusionSkillNext or{})[a:GetName()]or -1)then
     local c=Choice(b,a,cfg,g)
     if c and c.count>=(cfg.minModels or 2)then
      local score=c.count*1000-a:GetManaCost()
      if not best or score>best.score then best={a=a,cfg=cfg,choice=c,score=score,id=id,models=#g}end
     end
    end
   end
  end
 end end
 if not best then return false end
 for _,ally in ipairs(b:GetNearbyHeroes(1000,false,BOT_MODE_NONE)or{})do
  if ally~=b and ally._illusionClearUntil and now<ally._illusionClearUntil and ally._illusionClearPlayer==best.id then return false end
 end
 local a,cfg,c=best.a,best.cfg,best.choice
 b._illusionClearUntil=now+.8;b._illusionClearPlayer=best.id;b._illusionClearNext=now+.8
 b._illusionSkillNext=b._illusionSkillNext or{};b._illusionSkillNext[a:GetName()]=now+(cfg.reuse or .8)
 b._illusionClearPending={a=a,name=a:GetName(),at=now,cooldown=a:GetCooldownTimeRemaining(),
  count=best.models}
 if c.selfCast then b:Action_UseAbility(a)
 elseif cfg.kind=='entity'or cfg.kind=='entityline'then b:Action_UseAbilityOnEntity(a,c.unit)
 else b:Action_UseAbilityOnLocation(a,c.loc)end
 Log(b,'clear_order',a:GetName(),best.models)
 return true
end
local Raw=X.Try
function X.Try(b,...)
 if b and DotaTime()<(b._illusionFaultUntil or -999)then return false end
 local ok,result=pcall(Raw,b,...)
 if ok then return result end
 if b then
  b._illusionClearPending=nil;b._illusionClearUntil=nil;b._illusionSpellCache=nil;b._illusionFaultUntil=DotaTime()+10
  print('[LOCAL_ADVICE_ERROR] module=illusion_response function=Try error='..tostring(result))
 end
 return false
end
return X

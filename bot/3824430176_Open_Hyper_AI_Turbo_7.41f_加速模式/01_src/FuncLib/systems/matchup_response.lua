-- Short local responses for every hero. Never creates a team objective.
-- Enemy handles are sampled only while visible; hidden aim uses recent public evidence.
local X={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local Profiles=require(GetScriptDirectory()..'/FuncLib/systems/illusion_spells')
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local function Has(n,f)return math.floor(n/f)%2==1 end
local function Own(b)return b and b==GetBot()and V(b)and b:IsHero()and not b:IsIllusion()end
local function Protected(b)
 return not Own(b)or b:IsInvulnerable()or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
  or b:IsStunned()or b:IsHexed()or b:IsInvisible()or b:HasModifier('modifier_smoke_of_deceit')
  or b:HasModifier('modifier_life_stealer_infest')or b:HasModifier('modifier_phoenix_icarus_dive')
  or b:HasModifier('modifier_phoenix_sun_ray')
end
local function Stack(b,name)
 local i=b:GetModifierByName(name);return i and i>=0 and b:GetModifierStackCount(i)or 0
end
local function Log(b,phase,name)
 local s=b._matchup;local now=DotaTime();s.logs=s.logs or{}
 if now>=(s.logs[phase]or -999)then s.logs[phase]=now+2
  print('[MATCHUP_RESPONSE] t='..now..' pid='..b:GetPlayerID()..' phase='..phase..' spell='..(name or'none'))end
end
local function ReadyHelpers(b,e)
 local n=0
 for _,a in ipairs(b:GetNearbyHeroes(900,false,BOT_MODE_NONE)or{})do
  if a~=b and V(a)and not a:IsIllusion()and not a:IsStunned()and not a:IsHexed()and not a:IsChanneling()
   and not a:IsDisarmed()and not a:IsAttackImmune()and HP(a)>.4 and D(a:GetLocation(),e:GetLocation())<=math.max(420,a:GetAttackRange()+100)
   and a:GetAttackTarget()==e then n=n+1 end
 end
 return n
end
local function KillNow(b,e)
 return GetUnitToUnitDistance(b,e)<=b:GetAttackRange()+50
  and b:GetEstimatedDamageToTarget(true,e,.8,DAMAGE_TYPE_PHYSICAL)>e:GetHealth()*1.25
end
function X.Update(b)
 if not Own(b)then return end
 local now=DotaTime();local s=b._matchup or{seen={}};b._matchup=s
 if now<(s.next or -999)then return s end;s.next=now+.12
 s.threat=nil;s.hidden=nil;s.trade=nil
 local napalm=Stack(b,'modifier_batrider_sticky_napalm')
 local stolen=Stack(b,'modifier_slark_essence_shift_debuff_counter')
 local victims={b}
 for _,a in ipairs(b:GetNearbyHeroes(800,false,BOT_MODE_NONE)or{})do
  if a~=b and V(a)and not a:IsIllusion()then victims[#victims+1]=a end
 end
 for _,e in ipairs(b:GetNearbyHeroes(1400,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and not e:IsIllusion()then
   local name=e:GetUnitName()
   if name=='npc_dota_hero_slark'then
    local here=e:GetLocation();local r={at=now,loc=here,id=e:GetPlayerID(),unit=e,range=e:GetAttackRange(),
     pact=e:HasModifier('modifier_slark_dark_pact')or e:HasModifier('modifier_slark_dark_pact_pulses'),
     immune=e:IsMagicImmune(),dance=e:HasModifier('modifier_slark_shadow_dance')or e:HasModifier('modifier_slark_depth_shroud')}
    s.seen[r.id]=r
    local melee=GetUnitToUnitDistance(b,e)<math.max(450,e:GetAttackRange()+160)
    if melee and b:WasRecentlyDamagedByHero(e,1.2)and not KillNow(b,e)
     and((stolen>=3 and HP(b)<.82 or HP(b)<.48)and ReadyHelpers(b,e)==0
      or stolen>=6 and ReadyHelpers(b,e)<2)then
     s.trade={loc=here,unit=e,kind='slark_trade',at=now};s.threat=s.trade
    end
   elseif name=='npc_dota_hero_batrider'and napalm>=3 and not KillNow(b,e)then
    local d=GetUnitToUnitDistance(b,e)
    if d<750 and(b:WasRecentlyDamagedByHero(e,1.5)or e:GetAttackTarget()==b
     or e:HasModifier('modifier_batrider_firefly')or d<450)
     and(napalm>=5 or HP(b)<.65 or ReadyHelpers(b,e)==0)then
     s.threat={loc=e:GetLocation(),unit=e,kind='napalm_spacing',at=now}
    end
   end
  end
 end
 for id,r in pairs(s.seen)do
  if now-r.at>5 then s.seen[id]=nil
  else
   -- Never inspect a hidden unit's location, modifiers, health or cast state here.
   local visible=V(r.unit)and r.unit:CanBeSeen()
   if not visible or r.dance then
    for _,a in ipairs(victims)do
     if a:WasRecentlyDamagedByPlayer(id,.65)and D(a:GetLocation(),r.loc)<1000 then
      local age=now-r.at;local pos,uncertainty
      if age<.65 then pos=r.loc;uncertainty=80+age*180
      else
       -- A melee hit identifies the victim area, not the hidden attacker's exact position.
       local v=a:GetLocation();local dx,dy=r.loc.x-v.x,r.loc.y-v.y;local n=math.max(1,math.sqrt(dx*dx+dy*dy))
       pos=Vector(v.x+dx/n*120,v.y+dy/n*120,v.z);uncertainty=math.max(180,r.range+80)
      end
      local h={loc=pos,uncertainty=uncertainty,victim=a,id=id,kind='hidden_slark',pact=r.pact and age<1.6,
       at=now,lastSeenAt=r.at,hidden=true,immune=r.immune and age<1.8}
      s.hidden=h
      if a==b then s.threat=h end
      break
     end
    end
   end
  end
 end
 if s.trade then s.tradeUntil=now+1.25;s.tradeMemory=s.trade end
 if not s.threat and s.tradeMemory and now<(s.tradeUntil or -1)and V(s.tradeMemory.unit)and s.tradeMemory.unit:CanBeSeen()
  and D(b:GetLocation(),s.tradeMemory.unit:GetLocation())<650 then s.threat=s.tradeMemory end
 if not s.threat then s.goal=nil end
 return s
end
local function Risk(p,t)return D(p,t.loc)end
function X.Goal(b)
 local s=X.Update(b);if not s or not s.threat or Protected(b)or b:IsRooted()
  or b:HasModifier('modifier_bloodseeker_rupture')or b:HasModifier('modifier_batrider_flaming_lasso')then return nil end
 local t=s.threat;local now=DotaTime();local here=b:GetLocation()
 if t.kind=='napalm_spacing'and Risk(here,t)>780 then return nil end
 if t.kind=='slark_trade'and Risk(here,t)>620 then return nil end
 if s.goal and s.goalKind==t.kind and now<(s.hold or -999)and D(here,s.goal)>60
  and Risk(s.goal,t)>Risk(here,t)+70 and Safe(b,s.goal)then return s.goal end
 local home=GetAncient(b:GetTeam());local best,score;local before=Risk(here,t)
 for i=0,15 do
  local angle=i*math.pi/8;local p=Vector(here.x+math.cos(angle)*320,here.y+math.sin(angle)*320,here.z)
  if Risk(p,t)>before+120 and Safe(b,p)then
   local value=Risk(p,t)-(V(home)and D(p,home:GetLocation())*.035 or 0)
   for _,a in ipairs(b:GetNearbyHeroes(900,false,BOT_MODE_NONE)or{})do
    if a~=b and V(a)and not a:IsIllusion()and HP(a)>.4 then value=value-math.max(0,D(p,a:GetLocation())-600)*.03 end
   end
   if not score or value>score then best,score=p,value end
  end
 end
 if best then s.goal=best;s.goalKind=t.kind;s.hold=now+.65;Log(b,t.kind);return best end
end
local control={lion_impale=true,nyx_assassin_impale=true,leshrac_split_earth=true,tiny_avalanche=true,
 centaur_hoof_stomp=true,slardar_slithereen_crush=true,monkey_king_boundless_strike=true,
 kunkka_torrent=true,invoker_deafening_blast=true,jakiro_ice_path=true,lina_light_strike_array=true,
 earthshaker_fissure=true,invoker_tornado=true}
local extra={jakiro_ice_path={kind='line',radius=130},lina_light_strike_array={kind='point',radius=200},
 earthshaker_fissure={kind='line',radius=120},invoker_tornado={kind='line',radius=150}}
local function Available(a)
 if not a or a:IsNull()or a:IsHidden()or a:GetLevel()==0 or not a:IsFullyCastable()or a:IsUltimate()then return false end
 local flags=a:GetBehavior()
 return not(Has(flags,2)or Has(flags,128)or Has(flags,512)or Has(flags,4096))
end
local function Fits(b,a,cfg,h)
 local kind=cfg.kind;local flags=a:GetBehavior();local radius=cfg.radius or 0
 local circle=kind=='self'or kind=='point'or kind=='selfpoint'
 if circle then local actual=a:GetAOERadius();if actual>0 then radius=math.min(radius,actual*.9)end end
 if h.hidden and (kind=='self' or kind=='selfpoint') then
  -- Auto-acquiring AOE is not equivalent to damage that covers hidden units.
  local hiddenSelf={centaur_hoof_stomp=true,slardar_slithereen_crush=true,bristleback_quill_spray=true,
   razor_plasma_field=true,huskar_inner_fire=true,shredder_whirling_death=true,void_spirit_resonant_pulse=true}
  if not hiddenSelf[a:GetName()]then return false end
 end
 local d=D(b:GetLocation(),h.loc)
 if kind=='self'or kind=='selfpoint'and not Has(flags,16)then
  local distance=h.hidden and h.victim and D(b:GetLocation(),h.victim:GetLocation())or d
  return Has(flags,4)and not Has(flags,16)and radius>=distance+h.uncertainty,nil
 end
 if not Has(flags,16)or not(kind=='point'or kind=='line'or kind=='pointline'or kind=='selfpoint')then return false end
 if d>a:GetCastRange()-20 or d<1 then return false end
 local delay=a:GetCastPoint()
 if a:GetName()=='leshrac_split_earth'or a:GetName()=='lina_light_strike_array'then delay=delay+.5 end
 if a:GetName()=='kunkka_torrent'then delay=delay+1.6 end
 -- Do not throw narrow/slow spells at a stale exact coordinate.
 local uncertainty=h.uncertainty+(delay>.6 and(delay-.6)*180 or 0)
 local nearLine=(kind=='line'or kind=='pointline')and h.victim and d<400
 if h.hidden and radius+(nearLine and 40 or 0)<uncertainty*(nearLine and .55 or .75)then return false end
 return true,h.loc
end
function X.TrySpells(b)
 local s=X.Update(b);if not s or Protected(b)or b:NumQueuedActions()>0 or DotaTime()<0
  or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 or DotaTime()<(s.castNext or -999)
  or b._enigmaCombo or b._invokerPlan then return false end
 local t=s.threat;local h=s.hidden
 if not t and not h then return false end
 if t and b:WasRecentlyDamagedByAnyHero(1)then
  local choices=t.kind=='napalm_spacing'and{'item_manta','item_lotus_orb','item_glimmer_cape'}or{'item_ghost','item_glimmer_cape'}
  for _,name in ipairs(choices)do
   local slot=b:FindItemSlot(name);local a=slot>=0 and slot<=5 and b:GetItemInSlot(slot)
   if a and a:IsFullyCastable()and not(name=='item_ghost'and b:HasModifier('modifier_ghost_state'))
    and not(name=='item_glimmer_cape'and b:HasModifier('modifier_item_glimmer_cape_fade'))then
    s.castNext=DotaTime()+.6
    if name=='item_glimmer_cape'or name=='item_lotus_orb'then b:Action_UseAbilityOnEntity(a,b)else b:Action_UseAbility(a)end
    Log(b,'defensive_item',name);return true
   end
  end
 end
 if b:IsSilenced()then return false end
 if not h and t and V(t.unit)and t.unit:CanBeSeen()then
  h={loc=t.unit:GetLocation(),unit=t.unit,uncertainty=40,hidden=false,victim=b,immune=t.unit:IsMagicImmune(),
   pact=t.unit:HasModifier('modifier_slark_dark_pact')or t.unit:HasModifier('modifier_slark_dark_pact_pulses')}
 end
 if not h or h.immune then return false end
 local now=DotaTime();local best,score
 for slot=0,23 do
  local a=b:GetAbilityInSlot(slot)
  if Available(a)then
   local name=a:GetName();local cfg=extra[name]or Profiles[name]
   if cfg and(not h.pact or not control[name]or HP(h.victim)<.25)then
    local fit,point=Fits(b,a,cfg,h)
    local reserve=math.max(75,b:GetMaxMana()*.15)
    if fit and b:GetMana()-a:GetManaCost()>=reserve then
     local value=(control[name]and 500 or 0)-a:GetManaCost()-(point and 0 or 25)
     if not score or value>score then best={a=a,point=point,control=control[name]};score=value end
    end
   end
  end
 end
 if not best then return false end
 for _,a in ipairs(b:GetNearbyHeroes(1000,false,BOT_MODE_NONE)or{})do
  if a~=b and a._hiddenPeel and now<a._hiddenPeel.untilTime and D(a._hiddenPeel.loc,h.loc)<350
   and best.control then return false end
 end
 s.castNext=now+1;b._hiddenPeel={loc=h.loc,untilTime=now+(best.control and .65 or .2)}
 if best.point then b:Action_UseAbilityOnLocation(best.a,best.point)else b:Action_UseAbility(best.a)end
 Log(b,h.hidden and'hidden_area_cast'or'visible_peel_cast',best.a:GetName());return true
end
function X.OrderGoal(b,action)
 if not b or not b._matchup or not(action:find('Move',1,true)or action:find('Attack',1,true))then return nil end
 return X.Goal(b)
end
function X.TryMove(b)
 if Protected(b)or b:NumQueuedActions()>0 or DotaTime()<(b._ohaAbilityOrderAt or -999)+.35 then return false end
 local p=X.Goal(b);if not p then return false end
 local s=b._matchup
 if DotaTime()>=(s.orderNext or -999)then s.orderNext=DotaTime()+.25;b:Action_MoveToLocation(p)end
 return true
end
for name,fallback in pairs({Update=function()end,Goal=function()end,TrySpells=function()return false end,OrderGoal=function()end,TryMove=function()return false end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,a=pcall(raw,b,...);if ok then return a end
  if b and DotaTime()>=(b._matchupErrorNext or -999)then b._matchupErrorNext=DotaTime()+10
   print('[EXECUTION_ERROR] module=matchup_response function='..name..' error='..tostring(a))end
  return fallback()
 end
end
return X

-- Enemy-fountain execution boundary, shared across modes; no field chase scheduling.
local X={};local fountains={}
-- Installed 7.41f positions. Prefer the actual visible entity; do not change Fu globally.
local function EnemyFountain(b)
 local team=b:GetTeam();local enemy=team==2 and 3 or 2;local now=DotaTime()
 local c=fountains[team]
 if not c or now>=c.next then
  c={next=now+2,loc=enemy==2 and Vector(-7456,-6938,393.301758) or Vector(7408,6848,377.301758)}
  local p=b:GetLocation();local dx,dy=p.x-c.loc.x,p.y-c.loc.y
  if dx*dx+dy*dy<2800*2800 then
  for _,u in ipairs(GetUnitList(UNIT_LIST_ALL) or {}) do
   if u and not u:IsNull() and u:GetTeam()==enemy and u:CanBeSeen()
    and string.find(u:GetUnitName() or '', 'fountain',1,true) then c.loc=u:GetLocation();break end
  end
  end
  fountains[team]=c
 end
 return c.loc
end
local function Dist(a,b) local dx,dy=a.x-b.x,a.y-b.y;return math.sqrt(dx*dx+dy*dy) end
local function Valid(b) return b and not b:IsNull() and b:IsAlive() end
local function Protected(b)
 return not Valid(b) or not b:IsHero() or b:IsIllusion() or b:IsInvulnerable()
  or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted()
end
local function State(b)
 if Protected(b) or b._guardTravel then return nil end
 local fountain=EnemyFountain(b)
 local p=b:GetLocation();local radius=Dist(p,fountain)
 local s=b._fountainSafety
 if radius>=1750 then
  if s and DotaTime()>(s.lockUntil or -1)then b._fountainSafety=nil end
  return nil
 end
 local target=b:GetAttackTarget()
 local chase=Valid(target) and target:IsHero() and not target:IsIllusion() and target:CanBeSeen()
  and target:GetTeam()~=b:GetTeam() and Dist(target:GetLocation(),fountain)<1450 and radius<1750
 if radius>1450 and not (s and radius<1750) then
  if not chase then return nil end
  -- Allow an already reachable one-hit finish outside the inner fountain area.
  if Dist(p,target:GetLocation())<=b:GetAttackRange()+80
   and not target:IsInvulnerable() and b:GetEstimatedDamageToTarget(true,target,0.8,DAMAGE_TYPE_PHYSICAL)>=target:GetHealth()*1.3 then return nil end
 end
 if not s then s={nextOrder=0};b._fountainSafety=s end
 s.fountain=fountain;s.lockUntil=DotaTime()+5
 return s
end
function X.Location(b)return EnemyFountain(b)end
function X.Forbidden(b,point)
 if not point then return false end
 local f=EnemyFountain(b);local s=b._fountainSafety
 return Dist(point,f)<1650 or s and DotaTime()<(s.lockUntil or -1)and Dist(point,f)<1900 or false
end
function X.GetDesire(b) return State(b) and 1.01 or 0 end
function X.Exit(b,force)
 local s=State(b)
 if not s and not force then return nil end
 s=s or {fountain=EnemyFountain(b)}
 local p=b:GetLocation();local f=s.fountain
 local dx,dy=p.x-f.x,p.y-f.y;local len=math.sqrt(dx*dx+dy*dy)
 if len<1 then
  local ancient=GetAncient(b:GetTeam());local a=ancient and ancient:GetLocation() or Vector(0,0,0)
  dx,dy=a.x-f.x,a.y-f.y;len=math.max(1,math.sqrt(dx*dx+dy*dy))
 end
 local now=DotaTime();local route=b._fountainRoute or{at=now,loc=p};b._fountainRoute=route
 if now-route.at>=1.25 then
  if Dist(p,route.loc)<70 then route.stuckSince=route.stuckSince or route.at else route.stuckSince=nil end
  route.at=now;route.loc=p
 end
 route.touched=now
 local chosen
 for _,stepLength in ipairs({650,350,200}) do
 for _,angle in ipairs({0,0.35,-0.35,0.7,-0.7,1,-1,1.3,-1.3}) do
  local x,y=(dx*math.cos(angle)-dy*math.sin(angle))/len,(dx*math.sin(angle)+dy*math.cos(angle))/len
  local q=Vector(p.x+x*stepLength,p.y+y*stepLength,p.z)
  local safe=Dist(q,f)>len+100
  for i=1,6 do
   local step=Vector(p.x+(q.x-p.x)*i/6,p.y+(q.y-p.y)*i/6,p.z)
   if not IsLocationPassable(step) or Dist(step,f)<len-1 then safe=false;break end
  end
  if safe then chosen=q;break end
 end
 if chosen then break end
 end
 return chosen
end
-- An unusable walking exit must still allow a validated home teleport.
local function UnstickTP(b)
 local r=b and b._fountainRoute;local now=DotaTime()
 if not r or not r.stuckSince or now-r.stuckSince<2.5 or now-(r.touched or -999)>1
  or b~=GetBot()or Protected(b)or b:IsMuted()or b:IsHexed()or b:IsInvisible()
  or Dist(b:GetLocation(),EnemyFountain(b))>2100 then return false end
 local home=GetAncient(b:GetTeam());if not Valid(home)then return false end
 for _,slot in ipairs({15,0,1,2,3,4,5})do local a=b:GetItemInSlot(slot)
  if a and a:GetName()=='item_tpscroll'and a:IsFullyCastable()
   and require(GetScriptDirectory()..'/FuncLib/systems/escape_tp').Allow(b,a,'fountain TP out')then
   b:Action_UseAbilityOnLocation(a,home:GetLocation())
   print('[FOUNTAIN_LOCAL] t='..now..' pid='..b:GetPlayerID()..' phase=stalled_safe_tp_order');return true
  end
 end
 return false
end
function X.Think(b)
 local base=require(GetScriptDirectory()..'/FuncLib/systems/base_execution');if base.Active(b)then return base.Try(b)end
 local s=State(b);if UnstickTP(b)then return true end;if not s then return false end
 if DotaTime()<s.nextOrder then return true end;s.nextOrder=DotaTime()+0.5
 local chosen=X.Exit(b)
 local len=Dist(b:GetLocation(),s.fountain)
 if chosen then
  if not s.queueCleared then s.queueCleared=true;if b:NumQueuedActions()>0 then b:Action_ClearActions(false)end end
  b:Action_MoveToLocation(chosen);s.blocked=false
 elseif not s.blocked then b:Action_ClearActions(false);s.blocked=true end
 if DotaTime()>=(s.nextLog or 0) then
  s.nextLog=DotaTime()+3
  print(string.format('[FOUNTAIN_LOCAL] t=%.2f pid=%d phase=%s radius=%.0f',DotaTime(),b:GetPlayerID(),chosen and 'exit_order' or 'no_passable_exit',len))
 end
 return true
end
function X.OrderGoal(b,action,target,location)
 if not Valid(b)or b~=GetBot()or b:IsIllusion()or b:IsStunned()or b:IsRooted()then return nil end
 if b._baseOwnOrder then return nil end
 if action:find('AttackUnit',1,true)and Valid(target)and target:IsBuilding()and Dist(b:GetLocation(),EnemyFountain(b))>=1800
  and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+b:GetBoundingRadius()+target:GetBoundingRadius()+25 then return nil end
 local foot=action:find('Move',1,true)or action:find('Attack',1,true)
 if foot and require(GetScriptDirectory()..'/FuncLib/systems/base_execution').Active(b)then return nil end
 local spell=action:find('UseAbility',1,true)and target or nil
 local mobility={item_tpscroll=true,item_travel_boots=true,item_travel_boots_2=true,furion_teleportation=true,wisp_relocate=true,item_blink=true,item_overwhelming_blink=true,item_arcane_blink=true,item_swift_blink=true,
  phantom_assassin_phantom_strike=true,antimage_blink=true,queenofpain_blink=true,faceless_void_time_walk=true}
 local moveSpell=spell and mobility[spell:GetName()]
 local ordinarySpell=spell and not moveSpell
 if not foot and not moveSpell and not ordinarySpell then return nil end
 if b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()then return nil end
 local f=EnemyFountain(b);local here=b:GetLocation();local destination
 if action:find('OnLocation',1,true)then destination=location
 elseif action:find('OnEntity',1,true)then destination=location and not location:IsNull()and location:GetLocation()
 elseif action:find('Move',1,true)then destination=target
 elseif action:find('AttackUnit',1,true)then destination=target and not target:IsNull()and target:GetLocation()end
 local radius=Dist(here,f);local bad=false;local outgoing=false
 if ordinarySpell then
  if not State(b)and not(destination and X.Forbidden(b,destination))then return nil end
  local saves={item_black_king_bar=true,item_manta=true,item_ghost=true,item_glimmer_cape=true,
   item_lotus_orb=true,item_satanic=true,item_cyclone=true,item_wind_waker=true,
   life_stealer_rage=true,abaddon_aphotic_shield=true,dazzle_shallow_grave=true,
   oracle_false_promise=true,omniknight_purification=true,invoker_ghost_walk=true,
   slark_shadow_dance=true,slark_dark_pact=true,ursa_enrage=true}
  local name=spell:GetName()
  if saves[name]and(not location or location==b)then return nil end
  if name=='life_stealer_infest'and location and not location:IsNull()and location:GetTeam()==b:GetTeam()
   and Dist(location:GetLocation(),f)>radius+100 then return nil end
  return X.Exit(b,true)
 end
 if destination and destination.x then
  local x,y=destination.x-here.x,destination.y-here.y
  local fraction=math.max(0,math.min(1,((f.x-here.x)*x+(f.y-here.y)*y)/math.max(1,x*x+y*y)))
  local closest=Vector(here.x+x*fraction,here.y+y*fraction,here.z)
  outgoing=Dist(closest,f)>=radius-10 and Dist(destination,f)>radius+100
  bad=(Dist(closest,f)<1650 or X.Forbidden(b,destination))and not outgoing
 end
 if not bad and not State(b)then return nil end
 if outgoing then return nil end
 return X.Exit(b,true)
end
return X

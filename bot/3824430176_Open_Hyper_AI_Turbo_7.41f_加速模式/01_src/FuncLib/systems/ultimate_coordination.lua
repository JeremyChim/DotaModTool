-- Local ultimate placement and formation only; never creates a team task.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Real(u,Fu)return V(u)and u:CanBeSeen()and u:IsHero()and not Fu.IsSuspiciousIllusion(u)end
function X.ChronoLocation(b,p,r,range,Fu)
 local enemies=Fu.GetEnemiesNearLoc(p,r+700)or{};local allies=Fu.GetAlliesNearLoc(p,r+900)or{}
 local candidates={p};for i=0,7 do local a=i*math.pi/4;candidates[#candidates+1]=Vector(p.x+math.cos(a)*r*.7,p.y+math.sin(a)*r*.7,p.z)end
 local best,value
 for _,q in ipairs(candidates)do if D(b:GetLocation(),q)<=range+25 then
  local hits,cost=0,0
  for _,e in ipairs(enemies)do if Real(e,Fu)and not e:IsAttackImmune()and D(e:GetLocation(),q)<r-35 then hits=hits+1 end end
  for _,a in ipairs(allies)do if a~=b and V(a)and not a:IsIllusion()then
   if D(a:GetLocation(),q)<r+35 then
    cost=cost+(a:HasModifier('modifier_legion_commander_duel')and 3 or a:GetAttackRange()<350 and 1.3 or .6)
   end
   local landing=a._solarLanding
   if landing and DotaTime()<landing.untilTime and D(landing.loc,q)<r+100 then cost=cost+2 end
  end end
  local score=hits*2-cost-D(p,q)*.0005
  if hits>0 and score>0 and(not value or score>value)then best,value=q,score end
 end end
 return best
end
function X.Zones(b)
 local cache=b._ultZones;local now=DotaTime()
 if cache and now<cache.next then return cache.zones end
 local out={}
 for _,u in ipairs(GetUnitList(UNIT_LIST_ALL)or{})do
  if V(u)and(u:GetTeam()==b:GetTeam()or u:CanBeSeen())then
   if (u:HasModifier('modifier_faceless_void_chronosphere_aura')or u:HasModifier('modifier_faceless_void_chronosphere'))then
    local radius=500
    for _,h in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)or{})do
     if V(h)and h:GetUnitName()=='npc_dota_hero_faceless_void'then local a=h:GetAbilityByName('faceless_void_chronosphere');if a then radius=math.max(radius,a:GetSpecialValueInt('radius'))end end
    end
    out[#out+1]={loc=u:GetLocation(),radius=radius}
   end
  end
 end
 -- A visible frozen body is evidence even when the bot API omits the thinker.
 if #out==0 then for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do
  if V(u)and u:CanBeSeen()and u:HasModifier('modifier_faceless_void_chronosphere_freeze')then out[#out+1]={loc=u:GetLocation(),radius=300}end
 end end
 b._ultZones={next=now+.25,zones=out}
 return out
end
function X.Landing(b,p,Fu)
 local zones=X.Zones(b);if #zones==0 then return p end
 local function Good(q)
  if not IsLocationPassable(q)then return false end
  for _,z in ipairs(zones)do if D(q,z.loc)<z.radius+85 then return false end end
  for _,a in ipairs(Fu.GetAlliesNearLoc(q,500)or{})do if V(a)and a~=b then return true end end
  return false
 end
 if Good(p)then return p end
 for _,z in ipairs(zones)do for i=0,11 do local a=i*math.pi/6;local q=Vector(z.loc.x+math.cos(a)*(z.radius+130),z.loc.y+math.sin(a)*(z.radius+130),p.z)
  if D(q,p)<800 and Good(q)then return q end
 end end
end
function X.ProtectTarget(b,Fu)
 local channel=false
 for _,a in ipairs(b:GetNearbyHeroes(1200,false,BOT_MODE_NONE)or{})do
  if V(a)and a~=b and a:GetUnitName()=='npc_dota_hero_enigma'and a:IsChanneling()then
   local skill=a:GetCurrentActiveAbility();if skill and skill:GetName()=='enigma_black_hole'then channel=true end
  end
 end
 if channel then for _,e in ipairs(b:GetNearbyHeroes(1400,true,BOT_MODE_NONE)or{})do
  if Real(e,Fu)and e:GetUnitName()=='npc_dota_hero_rubick'and not Fu.IsDisabled(e)then return e end
 end end
end
function X.OrderGoal(b,action,target)
 if not V(b)or b~=GetBot()or b:IsIllusion()or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
  or b:IsStunned()or b:IsRooted()or b:IsHexed()or b:IsInvulnerable()or b:NumQueuedActions()>0
  or b:GetUnitName()=='npc_dota_hero_faceless_void'or b:HasModifier('modifier_faceless_void_chronosphere_speed')
  or b:HasModifier('modifier_bloodseeker_rupture')then return nil end
 if not action:find('Move',1,true)and not action:find('AttackUnit',1,true)then return nil end
 local point=target and target.x and target or V(target)and target:CanBeSeen()and target:GetLocation()
 if not point then return nil end
 local here=b:GetLocation()
 if target and not target.x and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+20 then return nil end
 for _,z in ipairs(X.Zones(b))do if D(point,z.loc)<z.radius+70 and D(here,z.loc)>z.radius then
  local d=math.max(1,D(here,z.loc));local q=Vector(z.loc.x+(here.x-z.loc.x)/d*(z.radius+110),z.loc.y+(here.y-z.loc.y)/d*(z.radius+110),here.z)
  if require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,q)then return q end
 end end
end
function X.Try(b,Fu)
 if not V(b)or b~=GetBot()or b:IsIllusion()or b:IsInvulnerable()or b:IsChanneling()or b:IsUsingAbility()
  or b:IsCastingAbility()or b:IsStunned()or b:IsRooted()or b:IsHexed()or b:NumQueuedActions()>0
  or b:HasModifier('modifier_bloodseeker_rupture')or DotaTime()<(b._ohaAbilityOrderAt or -999)+.4
  or DotaTime()<(b._ultSpacingNext or -1)then return false end
 local here=b:GetLocation();local zones=X.Zones(b);local target=b:GetAttackTarget();local goal
 if b:GetUnitName()~='npc_dota_hero_faceless_void'and V(target)and target:CanBeSeen()then
  for _,z in ipairs(zones)do if D(target:GetLocation(),z.loc)<z.radius+150 and D(here,z.loc)>z.radius then
   local distance=z.radius+110
   if D(here,z.loc)<distance+120 then local d=math.max(1,D(here,z.loc));goal=Vector(z.loc.x+(here.x-z.loc.x)/d*distance,z.loc.y+(here.y-z.loc.y)/d*distance,here.z)end
  end end
 end
 if not goal and b:GetAttackRange()>=400 and X.ProtectTarget(b,Fu)then
  local crowd=0
  for _,a in ipairs(b:GetNearbyHeroes(350,false,BOT_MODE_NONE)or{})do if V(a)and a~=b and not a:IsIllusion()then crowd=crowd+1 end end
  if crowd>=2 then local a=(b:GetPlayerID()%5)*math.pi*.4;goal=Vector(here.x+math.cos(a)*260,here.y+math.sin(a)*260,here.z)end
 end
 if not goal or D(here,goal)<60 or not require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,goal)then return false end
 b._ultSpacingNext=DotaTime()+1;b:Action_MoveToLocation(goal)
 print('[ULT_COORDINATION] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=local_spacing');return true
end
return X

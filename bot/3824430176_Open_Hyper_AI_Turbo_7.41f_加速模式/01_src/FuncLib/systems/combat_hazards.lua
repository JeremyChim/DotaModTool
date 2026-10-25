-- Visible threats only; short movement corrections, no mode/task scheduling.
local X={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function Point(p)return p and type(p.x)=='number'and type(p.y)=='number'and p.x==p.x and p.y==p.y end
local function D(a,b)if not Point(a)or not Point(b)then return math.huge end;local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Own(b)return b==GetBot()and V(b)and b:IsHero()and not b:IsIllusion()end
local function Protected(b)
 return not Own(b)or b:IsInvulnerable()or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
  or b:IsStunned()or b:IsRooted()or b:IsHexed()or b:IsInvisible()or b:HasModifier('modifier_smoke_of_deceit')
  or b:HasModifier('modifier_batrider_flaming_lasso')or b:HasModifier('modifier_bloodseeker_rupture')
end
local function BounceUnit(u)
 if not V(u)or u:IsBuilding()or u:IsInvulnerable()then return false end
 local name=u:GetUnitName()
 return not(name:find('ward',1,true)or name:find('courier',1,true)or name:find('thinker',1,true)
  or name:find('earth_spirit_stone',1,true)or name:find('observer',1,true))
end
local function Stack(b)
 local i=b:GetModifierByName('modifier_batrider_sticky_napalm')
 if i and i>=0 then return b:GetModifierStackCount(i)end
 return 0
end
local function Segment(p,a,c)
 if not Point(p)or not Point(a)or not Point(c)then return math.huge end
 local x,y=c.x-a.x,c.y-a.y;local f=math.max(0,math.min(1,((p.x-a.x)*x+(p.y-a.y)*y)/math.max(1,x*x+y*y)))
 return D(p,Vector(a.x+x*f,a.y+y*f,p.z))
end
local function Log(b,phase)
 local s=b._combatHazard;local now=DotaTime()
 if now>=(s.logNext or -1)then s.logNext=now+2;print(string.format('[COMBAT_HAZARD] t=%.2f pid=%d phase=%s',now,b:GetPlayerID(),phase))end
end
function X.Update(b)
 if not Own(b)then return nil end
 local now=DotaTime();local s=b._combatHazard or{trails={},bats={},cold={}};b._combatHazard=s
 if now<(s.next or -1)then return s end;s.next=now+.15
 local here=b:GetLocation();local friends={};local hot={};s.enemies={};s.spires={}
 local incoming=false
 for _,p in ipairs(b:GetIncomingTrackingProjectiles()or{})do
  if p.ability and p.ability:GetName()=='lich_chain_frost'then incoming=true end
 end
 for _,u in ipairs(GetUnitList(UNIT_LIST_ALLIES)or{})do
  if BounceUnit(u)and D(here,u:GetLocation())<1600 then
   friends[#friends+1]=u
   if u:HasModifier('modifier_lich_chainfrost_slow')then s.cold[u]=now+1.1 end
  end
 end
 if b:HasModifier('modifier_lich_chainfrost_slow')or incoming then s.cold[b]=now+1.1 end
 s.bounce=700 -- Baseline range plus a margin; visible ability values may widen it.
 for _,u in ipairs(GetUnitList(UNIT_LIST_ENEMIES)or{})do
  if V(u)and u:CanBeSeen()and D(here,u:GetLocation())<2000 then
   local name=u:GetUnitName()
   if u:IsHero()and not u:IsIllusion()then s.enemies[#s.enemies+1]=u end
   if name=='npc_dota_hero_lich'then
    local a=u:GetAbilityByName('lich_chain_frost')
    if a then local range=a:GetSpecialValueInt('jump_range');if range>0 then s.bounce=math.max(s.bounce,math.min(1100,range+100))end end
   end
   if name:find('lich_ice_spire',1,true)then s.spires[#s.spires+1]=u end
   if name=='npc_dota_hero_batrider'and u:HasModifier('modifier_batrider_firefly')then
    local old=s.bats[u];local loc=u:GetLocation()
    local fire=u:GetAbilityByName('batrider_firefly');local radius=fire and fire:GetSpecialValueInt('radius')or 0
    radius=radius>0 and math.min(500,radius+30)or 250
    if not old or D(old.loc,loc)>70 then
     local a=old and now-old.at<.6 and D(old.loc,loc)<700 and old.loc or loc
     local trail={a=a,c=loc,untilTime=now+6,caster=u,radius=radius}
     s.trails[#s.trails+1]=trail
     s.bats[u]={loc=loc,at=now,tail=trail}
    else
     old.at=now
     if old.tail then old.tail.untilTime=now+6 end
    end
   end
  end
 end
 for u,untilTime in pairs(s.cold)do
  if not V(u)or now>untilTime then s.cold[u]=nil
  elseif D(here,u:GetLocation())<1600 then hot[#hot+1]=u end
 end
 local ownHot=s.cold[b]and now<s.cold[b];s.links={}
 for _,u in ipairs(ownHot and friends or hot)do if u~=b then s.links[#s.links+1]=u end end
 if #hot>0 then for _,u in ipairs(s.spires)do s.links[#s.links+1]=u end end
 s.chain=ownHot or #hot>0;s.friends=friends;s.stack=Stack(b)
 local recent={};s.fire=false
 for _,p in ipairs(s.trails)do
  if now<p.untilTime and D(here,p.c)<2200 then
   recent[#recent+1]=p
   if Segment(here,p.a,p.c)<(p.radius or 250)and V(p.caster)
    and(b:WasRecentlyDamagedByHero(p.caster,1)or s.stack>=3)then s.fire=true end
  end
 end
 s.trails=recent
 if not s.fire then s.fireStarted=nil;s.fireYield=nil end
 if not s.chain and not s.fire then s.goal=nil;s.kind=nil end
 return s
end
local function EnemyRisk(b,s,p)
 local risk=0;local here=b:GetLocation()
 for _,e in ipairs(s.enemies)do
  if V(e)and e:CanBeSeen()then
   local before,after=D(here,e:GetLocation()),D(p,e:GetLocation())
   if after<math.min(400,e:GetAttackRange()+100)and after<before-80 then risk=risk+(before-after)*2 end
  end
 end
 return risk
end
local function ChainRisk(s,p)
 local risk,near=0,99999
 for _,u in ipairs(s.links)do if V(u)then local d=D(p,u:GetLocation());near=math.min(near,d);risk=risk+math.max(0,s.bounce-d)end end
 return risk,near
end
local function FireRisk(s,p)
 local risk=0
 for _,trail in ipairs(s.trails)do risk=math.max(risk,math.max(0,(trail.radius or 250)+20-Segment(p,trail.a,trail.c)))end
 return risk
end
local function FightInstead(b,s)
 local t=b:GetAttackTarget()
 if not V(t)or not t:IsHero()or t:IsIllusion()or not t:CanBeSeen()or t:GetUnitName()~='npc_dota_hero_batrider'
  or GetUnitToUnitDistance(b,t)>b:GetAttackRange()+70 then return false end
 local damage=b:GetEstimatedDamageToTarget(true,t,1.2,DAMAGE_TYPE_PHYSICAL)
 if damage>t:GetHealth()*1.1 then return true end
 local helpers=0
 for _,u in ipairs(s.friends)do if u~=b and u:IsHero()and not u:IsIllusion()and u:GetHealth()/math.max(1,u:GetMaxHealth())>.45
  and not u:IsStunned()and GetUnitToUnitDistance(u,t)<900 then helpers=helpers+1 end end
 return s.stack<3 and b:GetHealth()/math.max(1,b:GetMaxHealth())>.6 and helpers>0 and damage>t:GetHealth()*.4
end
function X.Goal(b)
 local s=X.Update(b);if not s or Protected(b)then return nil end
 local now=DotaTime();local here=b:GetLocation();local chainRisk=ChainRisk(s,here)
 local chain=s.chain and chainRisk>0
 if not chain and(not s.fire or FightInstead(b,s))then s.goal=nil;s.kind=nil;return nil end
 if not chain then
  if now<(s.fireYield or -1)then return nil end
  s.fireStarted=s.fireStarted or now
  if s.stack<3 and b:GetHealth()/math.max(1,b:GetMaxHealth())>.5 and now-s.fireStarted>1 then
   s.fireYield=now+1;s.fireStarted=nil;s.goal=nil;s.kind=nil;Log(b,'fire_yield_to_combat');return nil
  end
 end
 local kind=chain and'chain_frost'or'firefly';local initial=chain and chainRisk or FireRisk(s,here)*4
 local function Risk(p)
  if chain then local risk=ChainRisk(s,p);return risk end
  -- Integrate a few samples so a candidate cannot prefer a long trip along the fire.
  local cost=FireRisk(s,p)*3
  for _,f in ipairs({.25,.5,.75})do cost=cost+FireRisk(s,Vector(here.x+(p.x-here.x)*f,here.y+(p.y-here.y)*f,here.z))*.4 end
  return cost
 end
 if s.goal and s.kind==kind and now<(s.hold or -1)and D(here,s.goal)>65 and Safe(b,s.goal)
  and Risk(s.goal)<initial-40 then return s.goal end
 local best,score;local move=b._originalMove;local axis=move and move.at and now-move.at<3 and move.loc or here;if not Point(axis)then axis=here end
 for i=0,15 do
  local angle=(i*22.5+(b:GetPlayerID()%5)*11)*math.pi/180
  for _,step in ipairs(chain and{420,620}or{260,420})do
   local p=Vector(here.x+math.cos(angle)*step,here.y+math.sin(angle)*step,here.z)
   if Safe(b,p)then
    local risk=Risk(p);local gain=initial-risk
    if gain>50 then
     local value=gain-EnemyRisk(b,s,p)-D(p,axis)*.025-step*.015
     if chain then
      for _,u in ipairs(s.friends)do local other=u._combatHazard
       local goal=other and other.goal
       if u~=b and Point(goal)and now<(other.hold or -1)then value=value-math.max(0,s.bounce-D(p,goal))*.4 end
      end
     end
     if not score or value>score then best,score=p,value end
    end
   end
  end
 end
 if best then s.goal=best;s.hold=now+.9;s.kind=kind;b._hazardExitUntil=now+.9;Log(b,kind..'_exit');return best end
 s.goal=nil;s.kind=nil;return nil
end
function X.AllowApproach(b,p)
 local s=X.Update(b);if not s then return true end
 if s.chain and ChainRisk(s,p)>40 then return false end
 if s.fire and FireRisk(s,p)>0 then return false end
 return true
end
function X.OrderGoal(b,action)
 if not b or not b._combatHazard then return nil end
 local foot=action=='Action_MoveToLocation'or action=='Action_MoveDirectly'or action=='Action_AttackMove'or action=='Action_AttackUnit'
  or action=='ActionPush_MoveToLocation'or action=='ActionQueue_MoveToLocation'or action=='ActionPush_AttackUnit'or action=='ActionQueue_AttackUnit'
 if not foot then return nil end
 return X.Goal(b)
end
function X.Try(b)
 if Protected(b)or b:NumQueuedActions()>0 then return false end
 if DotaTime()<(b._ohaAbilityOrderAt or -999)+.25 then return false end
 local p=X.Goal(b);if not p then return false end
 local s=b._combatHazard
 if b:GetCurrentActionType()~=BOT_ACTION_TYPE_MOVE_TO or DotaTime()>=(s.orderNext or -1)then s.orderNext=DotaTime()+.25;b._hazardOwnOrder=true;b:Action_MoveToLocation(p);b._hazardOwnOrder=nil end
 return true
end
for name,fallback in pairs({Update=function()end,Goal=function()end,OrderGoal=function()end,Try=function()return false end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,result=pcall(raw,b,...);if ok then return result end
  if b and DotaTime()>=(b._hazardErrorNext or -1)then b._hazardErrorNext=DotaTime()+10;print('[COMBAT_HAZARD_ERROR] '..tostring(result))end
  return fallback()
 end
end
return X

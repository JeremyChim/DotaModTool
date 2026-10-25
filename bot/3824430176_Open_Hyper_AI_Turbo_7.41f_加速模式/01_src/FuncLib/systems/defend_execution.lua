-- Execution of an already selected base return; no defender recruitment.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
function X.Landing(b,building,default,critical)
 local center=building:GetLocation();local fort=GetAncient(b:GetTeam());if not V(fort)then return default end
 local home=fort:GetLocation();local dx,dy=home.x-center.x,home.y-center.y;local len=math.max(1,D(home,center));dx,dy=dx/len,dy/len
 if len<20 then dx,dy=b:GetTeam()==2 and -1 or 1,b:GetTeam()==2 and -1 or 1 end
 local enemies={};for _,e in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)or{})do if V(e)and e:CanBeSeen()and not e:IsIllusion()and D(e:GetLocation(),center)<1800 then enemies[#enemies+1]=e end end
 local best,cost
 for _,back in ipairs({200,400})do for _,side in ipairs({0,200,-200})do
  local p=Vector(center.x+dx*back-dy*side,center.y+dy*back+dx*side,center.z)
  if IsLocationPassable(p)then
   local risk=0
   for _,e in ipairs(enemies)do risk=risk+math.max(0,850-D(p,e:GetLocation()))end
   local score=risk+D(p,default)*.03
   if not cost or score<cost then best,cost=p,score end
  end
 end end
 if not best then return critical and default or nil end
 if not critical and cost>1000 then return nil end
 return best
end
function X.AfterLand(b)
 b._defendLanding={untilTime=DotaTime()+3.5}
end
function X.Try(b)
 local s=b._defendLanding
 if not s or DotaTime()>s.untilTime or not V(b)then b._defendLanding=nil;return false end
 if b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()or b:IsStunned()or b:IsRooted()or b:IsHexed()
  or b:NumQueuedActions()>0 or b:HasModifier('modifier_bloodseeker_rupture')or b:GetAttackRange()<400
  or DotaTime()<(b._ohaAbilityOrderAt or -999)+.35 then return false end
 local nearest,distance
 for _,e in ipairs(b:GetNearbyHeroes(950,true,BOT_MODE_NONE)or{})do if V(e)and e:CanBeSeen()and not e:IsIllusion()then
  local d=GetUnitToUnitDistance(b,e);if not distance or d<distance then nearest,distance=e,d end
 end end
 if not nearest or distance>math.min(550,b:GetAttackRange()-50)then return false end
 local here=b:GetLocation();local e=nearest:GetLocation();local d=math.max(1,distance)
 local p=Vector(here.x+(here.x-e.x)/d*260,here.y+(here.y-e.y)/d*260,here.z)
 if not require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,p)then return false end
 if DotaTime()>=(s.next or -1)then s.next=DotaTime()+.45;b:Action_MoveToLocation(p)end
 return true
end
return X

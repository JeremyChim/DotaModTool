-- Short-leash eidolon combat/retreat, preserving safe replication attacks and local siege targets.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,c)local x,y=a.x-c.x,a.y-c.y;return math.sqrt(x*x+y*y)end
function X.Think(b,u,Fu)
 if not V(u)or not u:GetUnitName():find('eidolon',1,true)then return false end
 if u:IsStunned()or u:IsRooted()or u:IsChanneling()then return true end
 if DotaTime()<(u._eidolonNext or -1)then return true end;u._eidolonNext=DotaTime()+.35
 local retreat=not V(b)or Fu.IsRetreating(b)or u:GetHealth()/math.max(1,u:GetMaxHealth())<.28 or u:WasRecentlyDamagedByTower(1)
 local fountain=require(GetScriptDirectory()..'/FuncLib/systems/fountain_safety')
 if fountain.Forbidden(b,u:GetLocation())then retreat=true end
 if retreat then
  local home=V(b)and b:GetLocation()or GetAncient(b:GetTeam()):GetLocation();local here=u:GetLocation();local n=math.max(1,D(here,home))
  local p=Vector(here.x+(home.x-here.x)/n*300,here.y+(home.y-here.y)/n*300,here.z)
  if IsLocationPassable(p)and not fountain.Forbidden(b,p)then u:Action_MoveToLocation(p)end;return true
 end
 local base=require(GetScriptDirectory()..'/FuncLib/systems/base_execution');if base.Minion(b,u)then return true end
 local target
 for _,e in ipairs(u:GetNearbyHeroes(1000,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and not Fu.IsSuspiciousIllusion(e)and e:HasModifier('modifier_enigma_black_hole_pull')then target=e;break end
 end
 target=target or b:GetAttackTarget()
 if V(target)and target:CanBeSeen()and target:GetTeam()~=b:GetTeam()and not target:IsInvulnerable()and not target:IsAttackImmune()
  and GetUnitToUnitDistance(u,target)<1100 and GetUnitToUnitDistance(b,target)<1200 and not fountain.Forbidden(b,target:GetLocation())then
  if u:GetAttackTarget()~=target then u:Action_AttackUnit(target,false)end;return true
 end
 local here=b:GetLocation();if not u._eidolonSlot then b._eidolonSlots=(b._eidolonSlots or 0)+1;u._eidolonSlot=b._eidolonSlots end
 local a=(u._eidolonSlot%7)*.8976;local p=Vector(here.x+math.cos(a)*250,here.y+math.sin(a)*250,here.z)
 if D(u:GetLocation(),p)>300 and IsLocationPassable(p)and not fountain.Forbidden(b,p)then u:Action_MoveToLocation(p)end
 return true
end
return X

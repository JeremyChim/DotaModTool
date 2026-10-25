-- Local losing-base restraint; does not choose new defenders or change defence desire.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,c)local x,y=a.x-c.x,a.y-c.y;return math.sqrt(x*x+y*y)end
function X.Goal(b,action,target)
 if b~=GetBot()or not V(b)or b:IsIllusion()or b:IsChanneling()or b:IsCastingAbility()or b:IsUsingAbility()or b:IsStunned()or b:IsRooted()
  or b._defenceOwnOrder or not(action:find('Move',1,true)or action:find('AttackUnit',1,true))then return nil end
 local home=GetAncient(b:GetTeam());if not V(home)or D(b:GetLocation(),home:GetLocation())>3400 then return nil end
 local goal=target and target.x and target or target and not target:IsNull()and target:GetLocation();if not goal then return nil end
 if target and not target.x and(not target:IsHero()or target:GetTeam()==b:GetTeam())then return nil end
 local dead=0;for _,id in ipairs(GetTeamPlayers(b:GetTeam()))do if not IsHeroAlive(id)then dead=dead+1 end end
 if dead<3 then return nil end
 local nearby=b:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{};local count=0
 for _,e in ipairs(nearby)do if V(e)and e:CanBeSeen()and not e:IsIllusion()then count=count+1 end end
 if count<2 then return nil end
 local from=D(b:GetLocation(),home:GetLocation());local to=D(goal,home:GetLocation())
 local lower=GetHeightLevel and GetHeightLevel(goal)<GetHeightLevel(home:GetLocation())
 if to<=from+120 or not lower and to<2700 then return nil end
 local here=b:GetLocation();local n=math.max(1,from);local p=Vector(here.x+(home:GetLocation().x-here.x)/n*300,here.y+(home:GetLocation().y-here.y)/n*300,here.z)
 if not IsLocationPassable(p)then return nil end
 if DotaTime()>=(b._defenceBoundaryLog or -1)then b._defenceBoundaryLog=DotaTime()+3;print('[DEFENCE_BOUNDARY] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=stay_within_base')end
 return p
end
return X

-- Real tree geometry + observed cast; not Nature's Wrath's similarly named entangle.
local X={};local claims={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,c)local x,y=a.x-c.x,a.y-c.y;return math.sqrt(x*x+y*y)end
local function Name(a)return a and not a:IsNull()and a:GetName()end
local function Goal(u)
 local h=GetAncient(u:GetTeam());if not V(h)then return nil end
 local p=u:GetLocation();local home=h:GetLocation();local n=math.max(1,D(p,home));return Vector(p.x+(home.x-p.x)/n*650,p.y+(home.y-p.y)/n*650,p.z)
end
local function Trees(u)
 local list={};for _,id in ipairs(u:GetNearbyTrees(350)or{})do local p=GetTreeLocation(id);if p then list[#list+1]={id=id,loc=p}end end;return list
end
local function Ring(u,t)
 if #t<5 then return false end;local sectors={};local p=u:GetLocation();local count=0
 for _,v in ipairs(t)do local d=D(v.loc,p);if d>75 and d<330 then
  local a=math.atan2(v.loc.y-p.y,v.loc.x-p.x);local k=math.floor((a+math.pi)/(math.pi/4))%8
  if not sectors[k]then sectors[k]=true;count=count+1 end
 end end;return count>=6
end
function X.Observe(b)
 if not V(b)or b~=GetBot()or b:IsIllusion()then return end
 local now=DotaTime();local s=b._sproutEscape
 for _,e in ipairs(b:GetNearbyHeroes(1300,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and e:GetUnitName()=='npc_dota_hero_furion'then
   local a=e:GetCurrentActiveAbility();local n=Name(a)
   if n=='furion_sprout'or n=='furion_greater_sprout'then b._sproutSeenUntil=now+6 end
  end
 end
 if s and (now>s.deadline or D(b:GetLocation(),s.origin)>380)then b._sproutEscape=nil;s=nil end
 local tree=Trees(b);local ring=Ring(b,tree)
 local sample=b._sproutMotion;local stuck=sample and now-sample.at>.6 and D(sample.loc,b:GetLocation())<35
 if not sample or D(sample.loc,b:GetLocation())>60 or now-sample.at>2 then b._sproutMotion={at=now,loc=b:GetLocation()}end
 local named=b:HasModifier('modifier_furion_sprout_damage')
 local prophet=false;for _,id in ipairs(GetTeamPlayers(b:GetTeam()==2 and 3 or 2))do if GetSelectedHeroName(id)=='npc_dota_hero_furion'then prophet=true end end
 if not s and (named or ring and(now<(b._sproutSeenUntil or -1)or prophet and stuck))then
  if ring or #tree>0 then b._sproutEscape={origin=b:GetLocation(),deadline=now+6.5,goal=Goal(b),at=now};s=b._sproutEscape end
 end
 if s then
  s.trees=tree;s.ring=ring
  if s.cutItem then local a=s.cutItem;if a:IsNull()or a:GetCurrentCharges()<(s.cutCharges or 0)or a:GetCooldownTimeRemaining()>(s.cutCooldown or 0)+.2 then s.gap=true end end
  if s.gap and not s.gapAt then s.gapAt=now;s.gapFrom=b:GetLocation()end
  if s.cutTree then local present=false;for _,v in ipairs(tree)do if v.id==s.cutTree then present=true end end;if not present then s.gap=true end end
 end
end
local function Ready(a)return a and not a:IsNull()and not a:IsHidden()and a:IsFullyCastable()end
local function SafeLanding(u,p)
 return IsLocationPassable(p)and not require(GetScriptDirectory()..'/FuncLib/systems/fountain_safety').Forbidden(u,p)
  and require(GetScriptDirectory()..'/FuncLib/systems/spell_safety').SafePoint(u,p)
end
local function GapBuildings(u,s)
 if s.obstacles and DotaTime()<(s.obstaclesNext or -1)then return s.obstacles end
 s.obstacles={};s.obstaclesNext=DotaTime()+.5
 for _,kind in ipairs({UNIT_LIST_ALLIED_BUILDINGS,UNIT_LIST_ENEMY_BUILDINGS})do
  for _,v in ipairs(GetUnitList(kind)or{})do
   if V(v)and v:IsBuilding()and(v:GetTeam()==u:GetTeam()or v:CanBeSeen())and D(v:GetLocation(),s.origin)<750 then
    s.obstacles[#s.obstacles+1]={loc=v:GetLocation(),radius=v:GetBoundingRadius()+u:GetBoundingRadius()+16}
   end
  end
 end;return s.obstacles
end
local function GapClear(u,s,p)
 if not SafeLanding(u,p)then return false end
 local x,y=p.x-s.origin.x,p.y-s.origin.y;local n=math.max(1,x*x+y*y)
 for _,v in ipairs(GapBuildings(u,s))do
  local t=math.max(0,math.min(1,((v.loc.x-s.origin.x)*x+(v.loc.y-s.origin.y)*y)/n))
  local near=Vector(s.origin.x+x*t,s.origin.y+y*t,s.origin.z)
  if D(near,v.loc)<v.radius then return false end
 end;return true
end
local function Cast(b,a,t,kind)
 b._sproutOwnOrder=true
 if kind=='tree'then b:Action_UseAbilityOnTree(a,t)elseif kind=='point'then b:Action_UseAbilityOnLocation(a,t)
 elseif kind=='unit'then b:Action_UseAbilityOnEntity(a,t)else b:Action_UseAbility(a)end
 b._sproutOwnOrder=nil;b._sproutNext=DotaTime()+.45
 print('[SPROUT_ESCAPE] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=escape_cast spell='..a:GetName());return true
end
function X.Try(b,Fu)
 X.Observe(b)
 if b~=GetBot()or not V(b)or b:IsIllusion()or b:IsStunned()or b:IsHexed()or b:IsChanneling()or b:IsCastingAbility()or b:IsUsingAbility()
  or b:NumQueuedActions()>0 or DotaTime()<(b._sproutNext or -1)then return false end
 local victims={b};for _,a in ipairs(b:GetNearbyHeroes(600,false,BOT_MODE_NONE)or{})do if a~=b and V(a)and a._sproutEscape then victims[#victims+1]=a end end
 for _,u in ipairs(victims)do local s=u._sproutEscape
  if s and s.goal then
   if u==b and s.gap then
    if b:IsRooted()then return false end
    -- A real gap does not imply the terrain beyond it is walkable. Keep the
    -- first cut, then permit displacement/self-protection if movement fails.
    if s.gapAt and DotaTime()-s.gapAt>.9 then
     if D(b:GetLocation(),s.gapFrom)<40 then
      if not s.walkRetried and s.cutLoc then
       s.walkRetried=true;s.moveNext=nil
       local n=math.max(1,D(s.origin,s.cutLoc));s.gapNear=Vector(s.origin.x+(s.cutLoc.x-s.origin.x)/n*(n+40),s.origin.y+(s.cutLoc.y-s.origin.y)/n*(n+40),s.origin.z)
      else s.walkBlocked=true end
     end
     s.gapAt=DotaTime();s.gapFrom=b:GetLocation()
    end
    if not s.walkBlocked then
     if s.gapNear and(D(b:GetLocation(),s.gapNear)<55 or D(b:GetLocation(),s.origin)>D(s.origin,s.gapNear)-55)then s.gapNear=nil;s.moveNext=nil end
     if DotaTime()>=(s.moveNext or -1)then s.moveNext=DotaTime()+.65;b._sproutOwnOrder=true;b:Action_MoveToLocation(s.gapNear or s.gapGoal or s.goal);b._sproutOwnOrder=nil end
     return true
    end
   end
   local tree,cost,fallback,fallbackCost
   for _,v in ipairs(s.trees or{})do local value=D(v.loc,s.goal)
    if not fallbackCost or value<fallbackCost then fallback,fallbackCost=v,value end
    local n=math.max(1,D(s.origin,v.loc));local exit=Vector(s.origin.x+(v.loc.x-s.origin.x)/n*(n+110),s.origin.y+(v.loc.y-s.origin.y)/n*(n+110),s.origin.z)
    if GapClear(u,s,exit)and(not cost or value<cost)then tree,cost=v,value end
   end
   -- Prefer a gap with a walkable outer landing. If every side is blocked,
   -- still allow one cut before displacement or the original combat logic.
   tree=tree or fallback
   if not s.gap and tree and DotaTime()>=(claims[tree.id]or -1)and not b:IsMuted()then
    for _,name in ipairs({'item_quelling_blade','item_bfury','item_tango','item_tango_single'})do
     local i=b:FindItemSlot(name);local a=i>=0 and i<=5 and b:GetItemInSlot(i)
     if Ready(a)and GetUnitToLocationDistance(b,tree.loc)<=math.max(300,a:GetCastRange())then claims[tree.id]=DotaTime()+.5;s.cutTree=tree.id;s.cutLoc=tree.loc;s.cutItem=a;s.cutCharges=a:GetCurrentCharges();s.cutCooldown=a:GetCooldownTimeRemaining();local n=math.max(1,D(s.origin,tree.loc));s.gapGoal=Vector(s.origin.x+(tree.loc.x-s.origin.x)/n*650,s.origin.y+(tree.loc.y-s.origin.y)/n*650,s.origin.z);s.gapNear=Vector(s.origin.x+(tree.loc.x-s.origin.x)/n*(n+110),s.origin.y+(tree.loc.y-s.origin.y)/n*(n+110),s.origin.z);return Cast(b,a,tree.id,'tree')end
    end
   end
   if u==b and not b:IsSilenced()then
    for _,v in ipairs({{'furion_force_of_nature','point'},{'shredder_whirling_death','none'},{'beastmaster_wild_axes','point'},{'tiny_tree_grab','tree'}})do local a=b:GetAbilityByName(v[1])
     if Ready(a)and tree and (v[2]=='none'or GetUnitToLocationDistance(b,tree.loc)<=math.max(300,a:GetCastRange()))then return Cast(b,a,v[2]=='tree'and tree.id or s.goal,v[2])end
    end
    if not b:IsRooted()then for _,name in ipairs({'antimage_blink','queenofpain_blink','faceless_void_time_walk'})do local a=b:GetAbilityByName(name)
     if Ready(a)and SafeLanding(b,s.goal)and GetUnitToLocationDistance(b,s.goal)<=a:GetCastRange()then return Cast(b,a,s.goal,'point')end
    end end
   end
   if not b:IsMuted()then for _,name in ipairs({'item_force_staff','item_hurricane_pike'})do local i=b:FindItemSlot(name);local a=i>=0 and i<=5 and b:GetItemInSlot(i)
    if Ready(a)and SafeLanding(u,s.goal)and GetUnitToUnitDistance(b,u)<=a:GetCastRange()+20 then
     if u:IsFacingLocation(s.goal,20)then return Cast(b,a,u,'unit')
     elseif u==b then b._sproutOwnOrder=true;b:Action_MoveToLocation(s.goal);b._sproutOwnOrder=nil;return true end
    end
   end end
   if u==b and not s.ring and not s.walkBlocked then
    b._sproutOwnOrder=true;b:Action_MoveToLocation(s.goal);b._sproutOwnOrder=nil;return true
   end
   if u==b and b:GetHealth()/math.max(1,b:GetMaxHealth())<.3 and b:WasRecentlyDamagedByAnyHero(.8)and not b:IsMuted()then
    for _,name in ipairs({'item_wind_waker','item_cyclone'})do local i=b:FindItemSlot(name);local a=i>=0 and i<=5 and b:GetItemInSlot(i)
     if Ready(a)then return Cast(b,a,b,'unit')end
    end
   end
  end
 end;return false
end
local raw=X.Try;X.Try=function(b,...)
 local ok,v=pcall(raw,b,...);if ok then return v end
 if b then b._sproutOwnOrder=nil;if DotaTime()>=(b._sproutErrorNext or -1)then b._sproutErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=sprout_escape error='..tostring(v))end end;return false
end
return X

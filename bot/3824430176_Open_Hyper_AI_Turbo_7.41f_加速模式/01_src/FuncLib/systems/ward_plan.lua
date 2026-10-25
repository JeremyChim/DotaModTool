-- Post-horn warding never acquires movement. Combat detection is separate.
local X={}
local retries={}
local function Key(s)return string.format("%.0f:%.0f",s.location.x,s.location.y)end
local Spots=require(GetScriptDirectory()..'/FuncLib/data/ward_spots')
local function Dist(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Valid(u)return u and not u:IsNull() and u:IsAlive()end
function X.Range(h)return math.max(0,h:GetCastRange()>0 and h:GetCastRange()or 500)end
function X.HasKind(h,kind)
 if not h or h:IsNull() or not h:IsFullyCastable() then return false end
 local n=h:GetName()
 if n=='item_ward_dispenser'then return(kind=='obs'and h:GetCurrentCharges()>0)or(kind=='sentry'and h:GetSecondaryCharges()>0)end
 return n==(kind=='obs'and'item_ward_observer'or'item_ward_sentry')
end
local function Name(kind)return kind=='obs'and'npc_dota_observer_wards'or'npc_dota_sentry_wards'end
function X.Near(loc,kind,radius)
 for _,u in pairs(GetUnitList(UNIT_LIST_ALLIED_WARDS)or{})do
  if Valid(u)and u:GetUnitName()==Name(kind)and Dist(u:GetLocation(),loc)<radius then return u end
 end
end
function X.EnemySentry(loc)
 for _,u in pairs(GetUnitList(UNIT_LIST_ENEMY_WARDS)or{})do
  if Valid(u)and u:CanBeSeen()and u:GetUnitName()=='npc_dota_sentry_wards'and Dist(u:GetLocation(),loc)<1050 then return true end
 end
 return false
end
function X.RouteScore(b,spot,h)
 local loc=b:GetLocation();local d=Dist(loc,spot.location)
 if DotaTime()>=0 and d>X.Range(h)-20 then return nil end
 local move=b._originalMove
 local penalty=0
 if move and DotaTime()-move.at<1.5 and Dist(loc,move.loc)>200 then
  local toward=Dist(spot.location,move.loc)-Dist(loc,move.loc)
  if toward>120 then return nil end -- do not drop behind the current route
  penalty=toward*.25
 end
 return d+penalty
end
local function Reserved(b,s,kind)
 if type(GetTeamMember)~='function'then return false end
 for i=1,5 do local a=GetTeamMember(i);local p=a and a._wardRoutePending
  if a~=b and p and p.kind==kind and DotaTime()-p.at<1.5 and Dist(p.spot.location,s.location)<850 then return true end
 end
 return false
end
function X.Select(b,h,kind,legacy)
 local best,score
 local candidates=kind=='obs'and Spots.Available(b:GetTeam(),DotaTime())or(legacy or{})
 if kind=='sentry'then
  local copy={};for _,s in ipairs(candidates)do copy[#copy+1]=s end;candidates=copy
  for _,s in ipairs(Spots.Available(b:GetTeam(),DotaTime()))do
   local planted=s.plant_time_obs or 0
   if X.Near(s.location,'obs',400)or planted>0 and DotaTime()-planted<360 then candidates[#candidates+1]=s end
  end
  for _,u in pairs(GetUnitList(UNIT_LIST_ENEMY_WARDS)or{})do
   if Valid(u)and u:CanBeSeen()then candidates[#candidates+1]={id='visible_enemy_ward',location=u:GetLocation()}end
  end
 end
 for _,s in ipairs(candidates)do
  local at=s['plant_time_'..kind]or 0
  local n=X.RouteScore(b,s,h)
  if n and not Reserved(b,s,kind) and DotaTime()>=(retries[Key(s)]or 0)and DotaTime()>=(s.retry_after or 0)and(at==0 or DotaTime()-at>(kind=='obs'and 360 or 420))
   and not X.Near(s.location,kind,kind=='obs'and 900 or 850)
   and(kind~='obs'or not X.EnemySentry(s.location))then
   if n and(not score or n<score)then best,score=s,n end
  end
 end
 return best
end
function X.Confirm(pending)
 if not pending then return nil end
 if X.Near(pending.spot.location,pending.kind,180)then
  pending.spot['plant_time_'..pending.kind]=DotaTime();return 'placed'
 end
 if DotaTime()-pending.at>1.2 then pending.spot.retry_after=DotaTime()+8;retries[Key(pending.spot)]=DotaTime()+8;return 'failed'end
end
return X

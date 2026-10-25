-- Visible evidence only. Duplicate models are one possible player, not extra players.
local X={}
function X.Count(b,list,filter,centre,radius)
 local seen,n={},0
 for _,u in ipairs(list or {})do
  if u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()and u:IsHero()and u:GetTeam()~=b:GetTeam()
   and(not filter or not filter(u))and(not centre or GetUnitToLocationDistance(u,centre)<=radius)then
   local id=u:GetPlayerID();local key=id>=0 and tostring(id)or u:GetUnitName()
   if not seen[key]then seen[key]=true;n=n+1 end
  end
 end
 return n
end
return X

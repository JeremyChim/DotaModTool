-- Shared visible identity evidence and local target evaluation; no task scheduling.
local X={};local teams={}
local function V(u)return u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Fake(b,u,Fu)
 if Fu.IsSuspiciousIllusion(u)then return true end
 -- Copies of our own roster cannot be an enemy original (Morphling is exempt).
 if GetSelectedHeroName(u:GetPlayerID())~='npc_dota_hero_morphling'then
  for _,id in ipairs(GetTeamPlayers(b:GetTeam()))do
   if GetSelectedHeroName(id)==u:GetUnitName()then return true end
  end
 end
 return false
end
function X.Observe(b,Fu)
 if b~=GetBot()or not b:IsAlive()then return end
 local now=DotaTime();local t=teams[b:GetTeam()]or{evidence={}};teams[b:GetTeam()]=t
 if now<(b._identityNext or -1)then return end;b._identityNext=now+.15
 local grouped={};local prior=b._identityGroups or{};local observed={}
 for _,u in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(u)and not Fake(b,u,Fu)then
   local id=u:GetPlayerID();grouped[id]=grouped[id]or{};table.insert(grouped[id],u)
   observed[id]=observed[id]or{at=now,units={}};observed[id].units[u]=true
   if u:IsCastingAbility()or u:IsUsingAbility()or u:IsChanneling()then
    t.evidence[id]={unit=u,untilTime=now+3,observed=now}
   end
  end
 end
 for id,ev in pairs(t.evidence)do
  if now>ev.untilTime or not V(ev.unit)or Fake(b,ev.unit,Fu)then t.evidence[id]=nil
  elseif grouped[id]then
   -- A newly ambiguous group invalidates pre-split evidence; current casting renews it.
   local old=prior[id];local added=false
   if old and now-old.at<1 then
    for _,u in ipairs(grouped[id])do if not old.units[u]then added=true end end
   end
   if #grouped[id]>1 and added and ev.observed<=(old and old.at or -999)then t.evidence[id]=nil end
  end
 end
b._identityGroups=observed
end
function X.Real(b,u,Fu,strict)
 if not V(u)or not u:IsHero()or u:GetTeam()==b:GetTeam()or Fake(b,u,Fu)then return false end
 if not strict then return true end
 X.Observe(b,Fu)
 local ev=teams[b:GetTeam()]and teams[b:GetTeam()].evidence[u:GetPlayerID()]
 if ev and ev.unit==u and DotaTime()<ev.untilTime then return true end
 local n=0
 for _,v in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(v)and v:GetPlayerID()==u:GetPlayerID()and not Fake(b,v,Fu)then n=n+1 end
 end
 return n<=1
end
function X.Enemies(b,loc,radius,Fu,strict)
 X.Observe(b,Fu);local out,ids={},{}
 for _,u in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if X.Real(b,u,Fu,strict)and D(u:GetLocation(),loc)<=radius and not ids[u:GetPlayerID()]then
   ids[u:GetPlayerID()]=true;out[#out+1]=u
  end
 end
 return out
end
function X.Resolve(b,current,Fu)
 if not V(current)or not current:IsHero()or current:GetTeam()==b:GetTeam()then return current end
 X.Observe(b,Fu)
 local ev=teams[b:GetTeam()]and teams[b:GetTeam()].evidence[current:GetPlayerID()]
 if ev and V(ev.unit)and DotaTime()<ev.untilTime and ev.unit~=current
  and GetUnitToUnitDistance(b,ev.unit)<=math.max(700,b:GetAttackRange()+250)then return ev.unit end
 if Fake(b,current,Fu)then
  local chosen,score
  for _,u in ipairs(b:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{})do
   if X.Real(b,u,Fu,true)and not u:IsInvulnerable()and not u:IsAttackImmune()then
    local d=GetUnitToUnitDistance(b,u)
    if d<=math.max(700,b:GetAttackRange()+200)then
     local value=(u:IsChanneling()and 600 or 0)+(u:GetAttackTarget()==b and 150 or 0)-d
     if not score or value>score then chosen,score=u,value end
    end
   end
  end
  if chosen then return chosen end
 end
 return current
end
function X.Focus(b,current,range,Fu)
 if not Fu.IsGoingOnSomeone(b)or Fu.IsRetreating(b)then return current end
 local function Score(u)
  if not X.Real(b,u,Fu,true)or u:IsInvulnerable()or u:IsAttackImmune()
   or D(b:GetLocation(),u:GetLocation())>range or not Fu.CanCastOnNonMagicImmune(u)then return nil end
  if u:HasModifier('modifier_abaddon_borrowed_time')or u:HasModifier('modifier_dazzle_shallow_grave')then return nil end
  local d=GetUnitToUnitDistance(b,u);local friends,foes=0,0
  for _,a in ipairs(b:GetNearbyHeroes(1600,false,BOT_MODE_NONE)or{})do
   if V(a)and a~=b and not a:IsIllusion()and not a:IsStunned()and D(a:GetLocation(),u:GetLocation())<850 then friends=friends+1 end
  end
  foes=#X.Enemies(b,u:GetLocation(),750,Fu,false)
  local towers=u:GetNearbyTowers(850,false)or{}
  local damage=b:GetEstimatedDamageToTarget(true,u,2.5,DAMAGE_TYPE_PHYSICAL)
  if #towers>0 and friends<2 and damage<u:GetHealth()*1.15 then return nil end
  if foes>friends+2 and damage<u:GetHealth()*1.15 then return nil end
  return damage/math.max(200,u:GetHealth())*300-d*.15+(u:IsChanneling()and 200 or 0)
   +(u:GetAttackTarget()==b and 45 or 0)-math.max(0,foes-friends-1)*85
 end
 local score=Score(current);local best=score and current or nil
 for _,u in ipairs(b:GetNearbyHeroes(math.min(1600,range),true,BOT_MODE_NONE)or{})do
  local v=Score(u)
  if v and(not score or v>score+80)then best,score=u,v end
 end
 return best
end
-- Never pull distant teammates into a fight. Only supplement an existing nearby exchange.
function X.SupportTarget(b,range,Fu)
 if Fu.IsRetreating(b)or b:GetHealth()/math.max(1,b:GetMaxHealth())<.4 then return nil end
 local own=b:GetAttackTarget();if V(own)and own:IsHero()then return nil end
 for _,a in ipairs(b:GetNearbyHeroes(1400,false,BOT_MODE_NONE)or{})do
  if a~=b and V(a)and not a:IsIllusion()and a:WasRecentlyDamagedByAnyHero(1.2)then
   local target=a:GetAttackTarget();if not V(target)then target=a:GetTarget()end
   if X.Real(b,target,Fu,true)and GetUnitToUnitDistance(b,target)<=range
    and #X.Enemies(b,a:GetLocation(),800,Fu,false)<=3 then return target end
  end
 end
end
function X.ChannelProtected(b,action)
 if not b:IsChanneling()then return false end
 local a=b:GetCurrentActiveAbility();local name=a and a:GetName()or''
 if name~='enigma_black_hole'and name~='witch_doctor_death_ward'and name~='crystal_maiden_freezing_field'and name~='ringmaster_tame_the_beasts'then return false end
 return action=='Action_ClearActions'or action:find('Move',1,true)~=nil or action:find('Attack',1,true)~=nil
end
function X.MayChannel(b,Fu)
 if b:IsMagicImmune()then return true end
 local exposedAlly=false
 for _,a in ipairs(b:GetNearbyHeroes(500,false,BOT_MODE_NONE)or{})do
  if a~=b and V(a)and a:IsChanneling()then exposedAlly=true end
 end
 if not exposedAlly then return true end
 for _,e in ipairs(X.Enemies(b,b:GetLocation(),900,Fu,true))do
  if e:GetUnitName()=='npc_dota_hero_naga_siren'and not Fu.IsDisabled(e)then
   local slot=b:FindItemSlot('item_black_king_bar');local a=slot>=0 and slot<=5 and b:GetItemInSlot(slot)
   return a and a:IsFullyCastable()or false
  end
 end
 return true
end
function X.PrepareUltimate(b,Fu,ultimate)
 if b:IsMagicImmune()then return false end
 local enemies=X.Enemies(b,b:GetLocation(),1100,Fu,true)
 if #enemies==0 then return false end
 for _,name in ipairs({'item_black_king_bar','item_glimmer_cape'})do
  local i=b:FindItemSlot(name);local item=i>=0 and i<=5 and b:GetItemInSlot(i)or nil
  if item and item:IsFullyCastable()and (not ultimate or b:GetMana()>=item:GetManaCost()+ultimate:GetManaCost())
   and(name~='item_glimmer_cape'or not b:IsInvisible())then
   if name=='item_glimmer_cape'then
    if DotaTime()<(b._ultimateGlimmerUntil or -1)then return false end
    b._ultimateGlimmerUntil=DotaTime()+4;b:Action_UseAbilityOnEntity(item,b)
   else b:Action_UseAbility(item)end
   return true
  end
 end
 return false
end

for name,fallback in pairs({Observe=function()end,Real=function()return false end,Enemies=function()return{}end,Resolve=function(_,t)return t end,Focus=function(_,t)return t end,SupportTarget=function()end,ChannelProtected=function()return false end,PrepareUltimate=function()return false end,MayChannel=function()return true end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,a,d=pcall(raw,b,...);if ok then return a,d end
  if b and DotaTime()>=(b._engagement_policyErrorNext or -1)then
   b._engagement_policyErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=engagement_policy function='..name..' error='..tostring(a))
  end
  return fallback(b,...)
 end
end
return X

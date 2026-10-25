-- Visible, short incidental pickups only. No long routes, TP or scheduled rotation.
local X={};local teams={}
local function Dist(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Valid(u) return u and not u:IsNull() end
local function Team(b)
 local t=teams[b:GetTeam()];if not t then t={cooldowns={},nextScan=0,units={}};teams[b:GetTeam()]=t end;return t
end
local function Busy(b,own)
 if not Valid(b) or not b:IsAlive() or not b:IsHero() or b:IsIllusion() or not IsPlayerBot(b:GetPlayerID())
  or b:IsInvulnerable() or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility()
  or b:IsStunned() or b:IsRooted() or b:IsHexed() or (b:NumQueuedActions()>0 and not own)
  or b:GetHealth()/math.max(1,b:GetMaxHealth())<.6 or b:WasRecentlyDamagedByAnyHero(3)
  or b:GetActiveMode()==BOT_MODE_RETREAT or b._guardTravel or b._guardBaseArea then return true end
 if b:GetActiveMode()==BOT_MODE_ATTACK or b:GetActiveMode()==BOT_MODE_GANK then return true end
 if (b._earlyLotus and b._earlyLotus.active) or (b._wisdomOnce and b._wisdomOnce.active)
  or (b._outpostTask and b._outpostTask.active) then return true end
 if b:GetActiveMode()==BOT_MODE_DEFEND_TOWER_TOP or b:GetActiveMode()==BOT_MODE_DEFEND_TOWER_MID
  or b:GetActiveMode()==BOT_MODE_DEFEND_TOWER_BOT or b:GetActiveMode()==BOT_MODE_ROSHAN then return true end
 for _,e in ipairs(b:GetNearbyHeroes(1200,true,BOT_MODE_NONE) or {}) do if Valid(e) and e:IsAlive() and e:CanBeSeen() then return true end end
 local target=b:GetAttackTarget()
 if Valid(target) and target:IsAlive() and (target:IsHero() or target:IsBuilding()) then return true end
 return false
end
local function Safe(b,p)
 if not IsLocationVisible(p) or not IsLocationPassable(p) then return false end
 local l=b:GetLocation();local mid=Vector((l.x+p.x)/2,(l.y+p.y)/2,l.z)
 if not IsLocationPassable(mid) then return false end
 for _,tower in ipairs(b:GetNearbyTowers(1400,true) or {}) do
  if Valid(tower) and tower:IsAlive() and Dist(p,tower:GetLocation())<950 then return false end
 end
 return true
end
local function Count(b)
 local n=0;local value={item_famango=1,item_great_famango=3,item_greater_famango=9}
 for i=0,8 do local h=b:GetItemInSlot(i);if h and value[h:GetName()] then n=n+value[h:GetName()]*math.max(1,h:GetCurrentCharges()) end end
 return n
end
local function Charges(u)
 if not Valid(u) or not IsLocationVisible(u:GetLocation()) then return nil end
 local ok,a=pcall(function()return u:GetAbilityByName('ability_xp_fountain')end)
 if not ok or not a then return nil end
 local success,count=pcall(function()return a:GetCurrentCharges()end)
 return success and count or nil,a
end
local function Finish(b,s,reason)
 local t=Team(b);t.cooldowns[s.key]=DotaTime()+(reason=='collected' and 10 or 15)
 if t.actor==b:GetPlayerID() then t.actor=nil;t.key=nil;t.untilTime=nil end
 b._opportunity=nil
 print(string.format('[PASSING_RESOURCE] t=%.2f pid=%d kind=%s phase=%s',DotaTime(),b:GetPlayerID(),s.kind,reason))
end
-- This exception never walks to a rune: only a single pickup already in reach.
function X.BlockFootOrder(b,action)
 local s=b._footBounty;if not s or DotaTime()>=s.untilTime then return false end
 if not b:IsAlive() or b:GetActiveMode()==BOT_MODE_RETREAT or b:IsStunned()
  or b:GetHealth()/math.max(1,b:GetMaxHealth())<.45 or b._guardTravel or b._guardBaseArea then
  b._footBounty=nil;return false
 end
 if string.find(action,'UseAbility',1,true) then b._footBounty=nil;return false end
 return string.find(action,'Move',1,true)~=nil or string.find(action,'Attack',1,true)~=nil or action=='Action_ClearActions'
end
function X.TryFoot(b)
 local now=DotaTime();if now<30 or b~=GetBot() then return false end
 local old=b._footBounty
 if old then
  if GetRuneStatus(old.id)==RUNE_STATUS_MISSING or b:GetGold()-old.gold>25 then
   local phase=GetRuneStatus(old.id)==RUNE_STATUS_MISSING and 'rune_gone' or 'pickup_gold_observed'
   print(string.format('[FOOT_BOUNTY] t=%.2f pid=%d phase=%s gold_gain=%d',now,b:GetPlayerID(),phase,b:GetGold()-old.gold));b._footBounty=nil
  elseif now<old.untilTime and Dist(b:GetLocation(),old.origin)<=80 and X.BlockFootOrder(b,'Action_MoveToLocation') then return true
  else
   b._footBounty=nil
   -- A nearby pickup must not turn into a long path around terrain. Clear
   -- only this interaction, never a subsequent combat or ability order.
   if b:GetCurrentActionType()==BOT_ACTION_TYPE_PICK_UP_RUNE then b:Action_ClearActions(false) end
   if now>=(b._footBountyDiag or -1) then b._footBountyDiag=now+5;print(string.format('[FOOT_BOUNTY] t=%.2f pid=%d phase=unconfirmed',now,b:GetPlayerID())) end
   b._footBounty=nil
  end
 end
 if now<(b._footBountyNext or -1) then return false end;b._footBountyNext=now+.2
 if not Valid(b) or not b:IsHero() or not b:IsAlive() or b:IsIllusion() or b:IsInvulnerable()
  or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted() or b:IsHexed()
  or b:NumQueuedActions()>0 or b:GetHealth()/math.max(1,b:GetMaxHealth())<.65
  or b:GetActiveMode()==BOT_MODE_RETREAT or b._guardTravel or b._guardBaseArea or b._opportunity then return false end
 for _,id in ipairs({RUNE_BOUNTY_1,RUNE_BOUNTY_2,RUNE_BOUNTY_3,RUNE_BOUNTY_4}) do
  local p=GetRuneSpawnLocation(id)
  if p and Dist(b:GetLocation(),p)<=100 and IsLocationVisible(p) and GetRuneStatus(id)==RUNE_STATUS_AVAILABLE then
   local t=Team(b);t.footCooldowns=t.footCooldowns or {}
   if t.footUntil and now<t.footUntil or now<(t.footCooldowns[id] or -1) then return false end
   t.footCooldowns[id]=now+15
   t.footUntil=now+.5;b._footBounty={id=id,gold=b:GetGold(),origin=b:GetLocation(),untilTime=now+.4};b._footBountyNext=now+2
   b:Action_PickUpRune(id)
   print(string.format('[FOOT_BOUNTY] t=%.2f pid=%d phase=pickup_order id=%d',now,b:GetPlayerID(),id));return true
  end
 end
 return false
end
function X.GetDesire(b)
 if b~=GetBot() then return 0 end
 local now=DotaTime();local t=Team(b);local s=b._opportunity
 if s then
  if not Valid(b) or GetHeroDeaths(b:GetPlayerID())~=s.deaths or Busy(b,true) then Finish(b,s,'interrupted');return 0 end
  local radius=s.kind=='lotus' and 450 or s.kind=='wisdom' and 360 or 220
  if now>s.deadline and s.pickupAt and b:NumQueuedActions()>0 then b:Action_ClearActions(false) end
  if now>s.deadline or Dist(b:GetLocation(),s.loc)>radius+30 then Finish(b,s,'budget_exit');return 0 end
  return .94
 end
 if now<30 or Busy(b) or now<(b._opportunityNext or -1) then return 0 end
 b._opportunityNext=now+.35
 if t.actor and now<(t.untilTime or -1) then return 0 end
 local l=b:GetLocation();local old=b._opportunityMotion
 b._opportunityMotion={loc=l,at=now}
 local function Nearby(p,radius,approach)
  local distance=Dist(l,p)
  if distance>radius or not Safe(b,approach or p) then return false end
  if distance>100 and old and now-old.at<1.5 then
   local x,y=l.x-old.loc.x,l.y-old.loc.y;local length=math.sqrt(x*x+y*y)
   if length>25 and (p.x-l.x)*x+(p.y-l.y)*y<0 then return false end
  end
  for i=1,5 do local a=GetTeamMember(i)
   if a and a~=b and Valid(a) and a:IsAlive() and IsPlayerBot(a:GetPlayerID()) then
    local seen=a._opportunityReady
    if seen and now-seen.at<.7 and seen.ready then
     local d=Dist(a:GetLocation(),p)
     if d<distance or d==distance and a:GetPlayerID()<b:GetPlayerID() then return false end
    end
   end
  end
  return true
 end
 b._opportunityReady={at=now,ready=true}
 local choices={}
 for _,id in ipairs({RUNE_BOUNTY_1,RUNE_BOUNTY_2,RUNE_BOUNTY_3,RUNE_BOUNTY_4}) do
  local p=GetRuneSpawnLocation(id)
  local length=p and math.max(1,Dist(l,p)) or 1
  local approach=p and Vector(p.x+(l.x-p.x)/length*40,p.y+(l.y-p.y)/length*40,p.z)
  if p and (math.abs(p.x)+math.abs(p.y)>100) and GetRuneStatus(id)==RUNE_STATUS_AVAILABLE and Nearby(p,220,approach) then
   choices[#choices+1]={key='rune:'..id,kind='bounty',id=id,loc=p,moveLoc=approach}
  end
 end
 table.sort(choices,function(a,c)return Dist(l,a.loc)<Dist(l,c.loc) end)
 for _,job in ipairs(choices) do
  if now>=(t.cooldowns[job.key] or -1) then
   job.deaths=GetHeroDeaths(b:GetPlayerID());job.deadline=now+(job.kind=='wisdom' and 5 or 2.5)
   job.gold=b:GetGold();job.lotus=Count(b);job.level=b:GetLevel();job.xp=b:GetXPNeededToLevel()
   b._opportunity=job;t.actor=b:GetPlayerID();t.key=job.key;t.untilTime=job.deadline
   print(string.format('[PASSING_RESOURCE] t=%.2f pid=%d kind=%s phase=claimed x=%.0f y=%.0f',now,b:GetPlayerID(),job.kind,job.loc.x,job.loc.y))
   return .94
  end
 end
 return 0
end
function X.Think(b)
 if not b._opportunity or X.GetDesire(b)==0 then return false end
 local s=b._opportunity;local now=DotaTime();local distance=Dist(b:GetLocation(),s.loc)
 if GetRuneStatus(s.id)==RUNE_STATUS_MISSING then
  Finish(b,s,b:GetGold()>s.gold+15 and 'collected' or 'resource_gone');return true
 end
 if s.pickupAt then
  -- Keep a single queued interaction intact; never stack pickup orders.
  local action=b:GetCurrentActionType()
  if b:NumQueuedActions()==0 and action==BOT_ACTION_TYPE_IDLE and now-s.pickupAt>=.4 then
   Finish(b,s,'pickup_action_finished');return true
  end
  return true
 end
 if now>=(s.nextOrder or -1) then
  s.nextOrder=now+.3
  if distance>80 then b:Action_MoveToLocation(s.moveLoc or s.loc)
  else
   s.pickupAt=now;b:ActionQueue_PickUpRune(s.id)
  end
 end
 return true
end
function X.OnEnd(b) if b._opportunity then Finish(b,b._opportunity,'mode_handoff') end end
return X

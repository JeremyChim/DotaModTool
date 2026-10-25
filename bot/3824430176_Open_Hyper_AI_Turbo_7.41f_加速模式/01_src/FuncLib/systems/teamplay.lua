-- Bounded advisory layer. Native modes keep their desire, lane and build decisions.
-- Only GetBot publishes private cooldown/damage information. Peers expire in 0.9s.
local X={}
local WallExit=require(GetScriptDirectory()..'/FuncLib/systems/wall_escape')
function X.SetHeroFilter(filter,position) X.suspicious=filter;X.position=position end
local Pressure=require(GetScriptDirectory()..'/FuncLib/systems/lane_pressure')
local function Valid(u) return u and not u:IsNull() and u:IsAlive() end
local function Dist(a,b) local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y) end
local function Hero(b,u)
 if Valid(u)and u:CanBeSeen()and require(GetScriptDirectory()..'/FuncLib/systems/fountain_safety').Forbidden(b,u:GetLocation())then return false end
 return Valid(u) and u:CanBeSeen() and u:IsHero() and u:GetTeam()~=b:GetTeam()
  and not u:IsInvulnerable() and not u:HasModifier('modifier_illusion')
  and not (X.suspicious and X.suspicious(u))
end
local function Push(mode)
 return mode==BOT_MODE_PUSH_TOWER_TOP or mode==BOT_MODE_PUSH_TOWER_MID or mode==BOT_MODE_PUSH_TOWER_BOT
end
local function Combat(mode) return mode==BOT_MODE_ATTACK or mode==BOT_MODE_ROAM or mode==BOT_MODE_TEAM_ROAM or mode==BOT_MODE_GANK end
local function Protected(b)
 return not Valid(b) or b~=GetBot() or not b:IsHero() or b:IsIllusion() or b:IsInvulnerable()
  or b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility() or b:IsStunned() or b:IsRooted()
end
local function Log(b,phase)
 local now=DotaTime();local times=b._teamplayLogs or {};b._teamplayLogs=times
 if now>=(times[phase] or -999) then
  times[phase]=now+8;print(string.format('[TEAMPLAY] t=%.2f pid=%d phase=%s',now,b:GetPlayerID(),phase))
 end
end
function X.Update(b)
 if b~=GetBot() or not Valid(b) or not b:IsHero() or b:IsIllusion() then
  if b==GetBot() then b._teamplay=nil end;return nil
 end
 local now=DotaTime();local s=b._teamplay
 if s and now<s.next then return s end
 s=s or {spellEvents={},casting={}};b._teamplay=s;s.at=now;s.next=now+0.25
 s.mode=b:GetActiveMode();s.loc=b:GetLocation();s.hp=b:GetHealth()/math.max(1,b:GetMaxHealth())
 s.disabled=b:IsStunned() or b:IsHexed()
 s.utility=(b._earlyLotus and b._earlyLotus.active) or (b._wisdomOnce and b._wisdomOnce.active)
  or (b._outpostTask and b._outpostTask.active) or b._guardTravel or b._guardBaseArea
 s.hurt=b:WasRecentlyDamagedByAnyHero(2);s.pressure=Pressure.Get(b)
 s.target=b:GetAttackTarget();if not Valid(s.target) then s.target=b:GetTarget() end
 s.enemies={};s.allies={};s.ready=0;s.helpers=0;s.readyAbilities={}
 -- Own, usable abilities/items only. No remote or enemy cooldown queries.
 for i=0,7 do local a=b:GetAbilityInSlot(i)
  if a and not a:IsHidden() and a:IsTrained() and a:IsFullyCastable() and a:GetManaCost()>0 then
   s.ready=s.ready+1;s.readyAbilities[#s.readyAbilities+1]=a
  end
 end
 s.bkb=false;s.blink=false
 for i=0,5 do local a=b:GetItemInSlot(i)
  if a and a:GetName()=='item_black_king_bar' and a:IsFullyCastable() then s.bkb=true end
  if a and (a:GetName()=='item_blink' or a:GetName()=='item_overwhelming_blink' or a:GetName()=='item_arcane_blink'
   or a:GetName()=='item_swift_blink') and a:IsFullyCastable() then s.blink=true end
 end
 for _,u in ipairs(b:GetNearbyHeroes(1400,true,BOT_MODE_NONE) or {}) do
  if Hero(b,u) then
   s.enemies[#s.enemies+1]=u
   local casting=u:IsUsingAbility() or u:IsCastingAbility()
   local id=u:GetPlayerID()
   if casting and not s.casting[id] then s.spellEvents[#s.spellEvents+1]=now end
   s.casting[id]=casting
  end
 end
 while s.spellEvents[1] and now-s.spellEvents[1]>20 do table.remove(s.spellEvents,1) end
 local threat=b._teamplayBuildThreat or {at=now,control=0,focus=0};b._teamplayBuildThreat=threat
 local dt=math.max(0,math.min(0.5,now-threat.at));threat.at=now
 threat.control=math.max(0,threat.control-dt*0.08)
 threat.focus=math.max(0,threat.focus-dt*0.08)
 if (s.hurt or #s.enemies>0) and (s.disabled or b:IsRooted() or b:IsSilenced()) then threat.control=threat.control+dt end
 if s.hurt and s.hp<0.6 and #s.enemies>=2 then threat.focus=threat.focus+dt end
 -- Only fresh publications from nearby bots count as committed assistance.
 for _,u in ipairs(b:GetNearbyHeroes(1400,false,BOT_MODE_NONE) or {}) do
  if Valid(u) and u~=b and not u:IsIllusion() then
   s.allies[#s.allies+1]=u
   local p=u._teamplay
   if p and now-p.at<0.9 and not p.disabled and p.hp>0.3 and (p.ready>0 or p.bkb or Combat(p.mode) or Push(p.mode) or p.mode==BOT_MODE_ROSHAN) then
    s.helpers=s.helpers+1
   end
  end
 end
 if Hero(b,s.target) then s.lastFightTarget=s.target;s.fightUntil=now+8 end
 return s
end
function X.Intent(b)
 local s=X.Update(b);if not s then return nil end
 local votes={};local locations={};local now=DotaTime()
 if now<(s.intentNext or -999) then return s.intent end
 s.intentNext=now+0.25;local previous=s.intent;s.intent=nil
 local function Vote(p)
  if p and not p.utility and now-p.at<0.9 and Dist(s.loc,p.loc)<1800 and (Push(p.mode) or p.mode==BOT_MODE_ROSHAN or Combat(p.mode)) then
   local mode=Combat(p.mode) and BOT_MODE_ATTACK or p.mode
   votes[mode]=(votes[mode] or 0)+1;locations[mode]=p.loc
  end
 end
 Vote(s);for _,u in ipairs(s.allies) do Vote(u._teamplay) end
 local mode,count=nil,1
 for m,n in pairs(votes) do if n>count or (n==count and m==s.mode) then mode,count=m,n end end
 if previous and now<(s.intentHoldUntil or 0) and (votes[previous.mode] or 0)>=2 then
  mode,count=previous.mode,votes[previous.mode]
 end
 if not mode or count<2 then return nil end
 if not previous or previous.mode~=mode then s.intentHoldUntil=now+1.5 end
 s.intent={mode=mode,count=count,location=locations[mode],push=Push(mode),combat=Combat(mode)}
 return s.intent
end
function X.Focus(b,current)
 if b==GetBot()then current=require(GetScriptDirectory()..'/FuncLib/systems/engagement_policy').Resolve(b,current,require(GetScriptDirectory()..'/FuncLib/func_utils'))end
 if b~=GetBot() then return current end
 local s=X.Update(b);if not s or s.mode==BOT_MODE_RETREAT or b._guardTravel or b._guardBaseArea then return current end
 if Hero(b,current) then
  -- Keep a reachable current victim; consensus must not bounce targets each tick.
  if GetUnitToUnitDistance(b,current)<=b:GetAttackRange()+100 or current:IsChanneling() then return current end
 end
 if not Combat(s.mode) and not (s.pressure and s.pressure.active) then return current end
 if s.pressure and s.pressure.active and Hero(b,s.pressure.target)
  and GetUnitToUnitDistance(b,s.pressure.target)<=math.max(700,b:GetAttackRange()+150) then
  Log(b,'lane_hero_response');return s.pressure.target
 end
 if s.pressure and s.pressure.active then
  for _,enemy in ipairs(s.enemies) do
   if Hero(b,enemy) and GetUnitToUnitDistance(b,enemy)<=math.max(700,b:GetAttackRange()+150)
    and (enemy:GetAttackTarget()==b or b:WasRecentlyDamagedByPlayer(enemy:GetPlayerID(),1)) then
    Log(b,'lane_hero_response');return enemy
   end
  end
 end
 local locked=s.focusLock
 if locked and DotaTime()<(s.focusUntil or 0) and Hero(b,locked)
  and GetUnitToUnitDistance(b,locked)<=math.max(850,b:GetAttackRange()+250) then return locked end
 local chosen,score=nil,0
 for _,u in ipairs(s.enemies) do
  if Hero(b,u) then
  local d=GetUnitToUnitDistance(b,u)
  if d<=math.max(850,b:GetAttackRange()+250) and not u:IsAttackImmune() then
   local supporters=0
   for _,ally in ipairs(s.allies) do local p=ally._teamplay
    if p and not p.disabled and DotaTime()-p.at<0.9 and p.target==u and Dist(p.loc,u:GetLocation())<900 then supporters=supporters+1 end
   end
   local n=supporters*2+(u:GetAttackTarget()==b and 2 or 0)+(1-u:GetHealth()/math.max(1,u:GetMaxHealth()))-d/1600
   if supporters>0 and n>score then chosen,score=u,n end
  end
  end
 end
 if chosen and chosen~=current then s.focusLock=chosen;s.focusUntil=DotaTime()+1.2;Log(b,'shared_focus');return chosen end
 return current
end
function X.Chase(b,target)
 local s=X.Update(b)
 if not s or not Hero(b,target) then return true,'not_visible_hero' end
 local d=GetUnitToUnitDistance(b,target);local reach=b:GetAttackRange()+100
 if d<=reach then return true,'in_range' end
 local towers=b:GetNearbyTowers(1100,true) or {}
 local unsafe=s.hp<0.4 or #s.enemies>s.helpers+1 or #towers>0
 local fort=GetAncient(GetOpposingTeam())
 if fort and not fort:IsNull()and GetUnitToUnitDistance(b,fort)<2600 then unsafe=true end
 if not unsafe and (target:IsStunned()or target:IsRooted()or target:IsHexed())then return true,'controlled' end
 local speed=b:GetCurrentMovementSpeed()-target:GetCurrentMovementSpeed()
 local arrival=math.max(0,d-reach)/math.max(80,b:GetCurrentMovementSpeed())
 local duration=math.max(0,2.5-arrival)
 local damage=b:GetEstimatedDamageToTarget(true,target,duration,DAMAGE_TYPE_PHYSICAL)
 for _,ally in ipairs(s.allies) do local p=ally._teamplay
  if Valid(ally) and p and not p.disabled and not p.utility and DotaTime()-p.at<0.9 and p.target==target and Dist(p.loc,target:GetLocation())<=ally:GetAttackRange()+120 then
   damage=damage+ally:GetEstimatedDamageToTarget(true,target,1.5,DAMAGE_TYPE_PHYSICAL)
  end
 end
 if damage>=target:GetHealth()*1.2 then return true,'short_finish' end
 local controls={lion_voodoo=true,lion_impale=true,shadow_shaman_voodoo=true,shadow_shaman_shackles=true,
  skeleton_king_hellfire_blast=true,vengefulspirit_magic_missile=true,chaos_knight_chaos_bolt=true,
  sven_storm_bolt=true,shredder_timber_chain=true}
 local rangedFinish=false
 local mana=b:GetMana()
 for _,a in ipairs(s.readyAbilities) do
  if a and (not a.IsNull or not a:IsNull()) and a:IsFullyCastable() and a:GetCastRange()+50>=d and a:GetCastPoint()<=0.6 and a:GetManaCost()<=mana then
   if not unsafe and controls[a:GetName()] and not target:IsMagicImmune() then return true,'reachable_control' end
   mana=mana-a:GetManaCost()
   if not target:IsMagicImmune() then damage=damage+target:GetActualIncomingDamage(a:GetAbilityDamage(),DAMAGE_TYPE_MAGICAL) end
   rangedFinish=damage>=target:GetHealth()*1.2
  end
 end
 if rangedFinish then return true,'reachable_spell_finish' end
 if not unsafe and s.blink and d<1200 then return true,'gap_closer_ready' end
 if unsafe and d>reach+180 then return false,'unreachable_risky' end
 return true,'original_chase'
end
function X.RememberMove(b,loc)
 if b~=GetBot() or not loc or not Valid(b) or not b:IsHero() or b:IsIllusion() then return end
 if Dist(b:GetLocation(),loc)>120 then b._originalMove={loc=loc,at=DotaTime()} end
end
local function WallCopy(b,u)
 if not Valid(u) or not u:CanBeSeen() or not u:IsHero() or u:GetTeam()==b:GetTeam() then return false end
 if u:HasModifier('modifier_darkseer_wallofreplica_illusion') then return true end
 -- Enemy replicas of our own roster are visible evidence, not hidden illusion flags.
 if u:GetUnitName()=='npc_dota_hero_morphling' or u:IsCastingAbility() or u:IsUsingAbility() or u:IsChanneling() then return false end
 for _,id in ipairs(GetTeamPlayers(b:GetTeam(),true)) do
  if GetSelectedHeroName(id)==u:GetUnitName() then return true end
 end
 return false
end
function X.WallAlternative(b,target)
 if not WallCopy(b,target) then return nil end
 local s=X.Update(b);if not s then return nil end
 for _,u in ipairs(s.enemies) do
  if Hero(b,u) and not u:IsAttackImmune() and GetUnitToUnitDistance(b,u)<=b:GetAttackRange()+160 then
   Log(b,'wall_copy_to_real');return u
  end
 end
 local creeps=b:GetNearbyLaneCreeps(850,false) or {}
 if #creeps>0 and (Push(s.mode) or Combat(s.mode)) then
  for _,u in ipairs(b:GetNearbyTowers(900,true) or {}) do
   if Valid(u) and u:CanBeSeen() and not u:IsInvulnerable() and not u:IsAttackImmune()
    and GetUnitToUnitDistance(b,u)<=b:GetAttackRange()+120 then Log(b,'wall_copy_to_building');return u end
  end
  for _,u in ipairs(b:GetNearbyBarracks(900,true) or {}) do
   if Valid(u) and u:CanBeSeen() and not u:IsInvulnerable() and not u:IsAttackImmune()
    and GetUnitToUnitDistance(b,u)<=b:GetAttackRange()+120 then Log(b,'wall_copy_to_building');return u end
  end
 end
 local escape=WallExit.Goal(b,target,require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe)
 if escape then return nil,escape end
 local move=b._originalMove
 if move and DotaTime()-move.at<4 and Dist(b:GetLocation(),move.loc)>120
  and not b:HasModifier('modifier_dark_seer_wall_slow')
  and require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,move.loc) then
  Log(b,'wall_copy_keep_route');return nil,move.loc
 end
 -- No invented route: only an already reachable copy may be fought defensively.
 if GetUnitToUnitDistance(b,target)>b:GetAttackRange()+80 then
  for _,c in ipairs(b:GetNearbyLaneCreeps(700,true) or {}) do
   if Valid(c) and c:CanBeSeen() then Log(b,'wall_copy_to_lane');return c end
  end
 end
 return nil
end
function X.WallOrderGoal(b,action,target)
 if not b or not b._wallExit then return nil end
 if Protected(b)or b:IsInvisible()or b:HasModifier('modifier_smoke_of_deceit')
  or DotaTime()<(b._lotusUseUntil or -1)or b._guardTravel or b._guardBaseArea then return nil end
 local foot=action=='Action_MoveToLocation'or action=='Action_MoveDirectly'or action=='Action_AttackMove'
  or action=='Action_AttackUnit'or action=='ActionPush_MoveToLocation'or action=='ActionQueue_MoveToLocation'
  or action=='ActionPush_AttackUnit'or action=='ActionQueue_AttackUnit'
 if not foot then return nil end
 local goal=WallExit.Active(b,require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe)
 if not goal then return nil end
 if string.find(action,'AttackUnit',1,true)and Valid(target)
  and (Hero(b,target)or target:IsBuilding())then
  b._wallExit.untilTime=DotaTime();return nil
 end
 return goal
end
function X.WallThink(b)
 if Protected(b)or b:NumQueuedActions()>0 or b:IsInvisible()
  or b:HasModifier('modifier_smoke_of_deceit')or DotaTime()<(b._lotusUseUntil or -1)then return false end
 local target=b:GetAttackTarget();if not Valid(target)then target=b:GetTarget()end
 if not WallCopy(b,target)then return false end
 local alternative,goal=X.WallAlternative(b,target)
 if alternative or not goal then return false end
 if b:GetCurrentActionType()~=BOT_ACTION_TYPE_MOVE_TO or DotaTime()>=(b._wallExitOrderNext or -1)then
  b._wallExitOrderNext=DotaTime()+.25;b:Action_MoveToLocation(goal)
 end
 return true
end
function X.AttackTarget(b,target)
 if Protected(b) or not Valid(target) or target:GetTeam()==b:GetTeam() then return target end
 local alternative,goal=X.WallAlternative(b,target)
 if alternative or goal then return alternative,goal end
 local s=X.Update(b)
 if s and not target:IsBuilding() then
  -- Strategic summons retain original treatment; only ordinary bait yields.
  local name=target:GetUnitName()
  local bait=string.find(name,'forged_spirit',1,true) or string.find(name,'clinkz_skeleton',1,true)
   or target:HasModifier('modifier_illusion') or (target:IsHero() and X.suspicious and X.suspicious(target))
  if (bait or s.pressure and s.pressure.active and not target:IsHero() and s.mode==BOT_MODE_LANING) and target:GetHealth()>b:GetAttackDamage()*0.8 then
   local focus=X.Focus(b,target)
   if not Hero(b,focus) then
    for _,u in ipairs(s.enemies) do
     if Hero(b,u) and GetUnitToUnitDistance(b,u)<=b:GetAttackRange()+180
      and (u:GetAttackTarget()==b or b:WasRecentlyDamagedByPlayer(u:GetPlayerID(),1))then focus=u;break end
    end
   end
   if Hero(b,focus) then Log(b,'bait_to_real');return focus end
  end
 end
 if Hero(b,target) and Combat(s.mode) then
  local focus=X.Focus(b,target);local chase=X.Chase(b,focus)
  if chase then return focus end
  -- Do not stop field Ganks. Only substitute a verified local building.
  local building=X.Building(b)
  if building then Log(b,'chase_to_building');return building end
 end
 return target
end
function X.AllowEntitySpell(b,a,target)
 if b~=GetBot()or not a or not Valid(target)or target:GetTeam()==b:GetTeam()or not target:CanBeSeen()then return true end
 if not target:IsHero()or not (WallCopy(b,target)or X.suspicious and X.suspicious(target))then return true end
 if a:IsItem()then return true end
 if b:GetHealth()/math.max(1,b:GetMaxHealth())<.35 and GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+100 then return true end
 local s=X.Update(b)
 if s then for _,u in ipairs(s.enemies)do
  if Hero(b,u)and GetUnitToUnitDistance(b,u)<=a:GetCastRange()+100 then Log(b,'replica_spell_yield');return false end
 end end
 return not WallCopy(b,target)
end
function X.Building(b)
 local s=X.Update(b);if not s or b:WasRecentlyDamagedByAnyHero(.75) or s.hp<.45 or b._guardTravel or b._guardBaseArea then return nil end
 for _,enemy in ipairs(s.enemies) do if GetUnitToUnitDistance(b,enemy)<850 then return nil end end
 local creeps=b:GetNearbyLaneCreeps(800,false) or {};if #creeps==0 then return nil end
 local list=b:GetNearbyTowers(900,true) or {}
 for _,u in ipairs(b:GetNearbyBarracks(900,true) or {}) do list[#list+1]=u end
 local fort=GetAncient(GetOpposingTeam())
 if Valid(fort)and fort:CanBeSeen()and not fort:IsInvulnerable()and not fort:IsAttackImmune()
  and GetUnitToUnitDistance(b,fort)<=b:GetAttackRange()+180 then return fort end
 local best,distance=nil,99999
 for _,u in ipairs(list) do
  if Valid(u) and u:CanBeSeen() and not u:IsInvulnerable() and not u:IsAttackImmune() then
   local d=GetUnitToUnitDistance(b,u)
   if d<=b:GetAttackRange()+180 and d<distance then best,distance=u,d end
  end
 end
 return best
end
function X.Convert(b)
 if Protected(b) or b:GetActiveMode()==BOT_MODE_RETREAT or b._guardTravel or b._guardBaseArea then return false end
 local s=X.Update(b)
 if not s or not Combat(s.mode) or not s.fightUntil or DotaTime()>s.fightUntil
  or not s.lastFightTarget or s.lastFightTarget:IsNull() then return false end
 if s.lastFightTarget:IsAlive() and s.lastFightTarget:CanBeSeen() then return false end
 local target=b:GetAttackTarget();if Valid(target) and (target:IsBuilding() or target:IsHero() and target:CanBeSeen()) then return false end
 local building=X.Building(b)
 if building and DotaTime()>=(s.convertNext or 0) then
  s.convertNext=DotaTime()+0.8;Log(b,'won_fight_building');b:Action_AttackUnit(building,false);return true
 end
 return false
end
function X.WardScore(b,loc,distance)
 local intent=X.Intent(b)
 if not intent or DotaTime()<0 then return distance end
 if distance>1100 then return distance+3000 end
 return distance+math.min(1200,Dist(loc,intent.location))*0.4
end
function X.Smoke(b)
 local s=X.Update(b);local intent=X.Intent(b)
 if not s or not intent or (not intent.combat and intent.mode~=BOT_MODE_ROSHAN) then return false end
 if s.hp<0.55 or s.hurt or #s.enemies>0 or s.helpers<1 then return false end
 for _,u in ipairs(b:GetNearbyTowers(1200,true) or {}) do if Valid(u) then return false end end
 for _,u in ipairs(s.allies) do if u:HasModifier('modifier_smoke_of_deceit') then return false end end
 local ready=0
 for _,u in ipairs(s.allies) do local p=u._teamplay
  if p and not p.disabled and DotaTime()-p.at<0.9 and p.hp>0.4 and Dist(s.loc,p.loc)<1000 then ready=ready+1 end
 end
 return ready>0
end
function X.ReadyForInitiation(b,target)
 local s=X.Update(b);if not s or not Hero(b,target) then return true end
 if target:IsChanneling() or target:GetAttackTarget()==b or s.hurt then return true end
 local arrived=0
 for _,u in ipairs(s.allies) do local p=u._teamplay
  if p and not p.disabled and DotaTime()-p.at<0.9 and p.hp>0.3
   and Dist(p.loc,target:GetLocation())<900 and (p.ready>0 or p.target==target) then arrived=arrived+1 end
 end
 if #s.enemies<2 or arrived>0 or s.bkb or s.hp>0.8 and s.ready>=2 then return true end
 return GetUnitToUnitDistance(b,target)<=b:GetAttackRange()+100
end
function X.Purchase(b)
 local now=DotaTime();if now<60 or not Valid(b) or b~=GetBot() or now<(b._teamplayBuyNext or 0) then return end
 b._teamplayBuyNext=now+3
 local s=X.Update(b);if not s then return end
 local threat=b._teamplayBuildThreat
 -- Advance one already planned defensive item at a completed-item boundary.
 -- Never replace a partially bought item, change core builds or add duplicates.
 if now>600 and not b._teamplayDefenceAdvance and threat and b:GetLevel()>=12 and b:GetNetWorth()>=6500
  and b.currBuyingItemInPurchaseList==nil and b.currBuyingBasicItem==nil
  and #(b.currBuyingBasicItemList or {})==0 and b:GetStashValue()==0 and b:GetCourierValue()==0 then
  local role=X.position and X.position(b) or 3
  local item=role<=3 and threat.control>=4 and 'item_black_king_bar'
   or role>=4 and (threat.control>=4 or threat.focus>=4) and 'item_glimmer_cape' or nil
  if item and b:FindItemSlot(item)<0 then
   local queue=b.purchaseListInReverseOrder or {}
   for i=#queue-1,1,-1 do
    if queue[i]==item then
     table.remove(queue,i);queue[#queue+1]=item;b._teamplayDefenceAdvance=true
     Log(b,'planned_defence_advanced');return
    end
   end
  end
 end
 local role=X.position and X.position(b)or 3
 local intent=X.Intent(b)
 if now>600 and role>=4 and intent and (intent.combat or intent.mode==BOT_MODE_ROSHAN)
  and s.helpers>=2 and not s.hurt and #s.enemies==0 and b:FindItemSlot('item_smoke_of_deceit')<0
  and now>=(b._smokeSupplyNext or 0)and b:GetCourierValue()==0 and b:GetStashValue()==0 then
  b._smokeSupplyNext=now+30
  local free=false;for i=0,5 do if not b:GetItemInSlot(i)then free=true end end
  local cost=GetItemCost('item_smoke_of_deceit')
  local reserve=b.currBuyingBasicItem and GetItemCost(b.currBuyingBasicItem)or 500
  if free and cost>0 and b:GetGold()>=cost+math.max(500,reserve)
   and (not GetItemStockCount or GetItemStockCount('item_smoke_of_deceit')>0)then
   if b:ActionImmediate_PurchaseItem('item_smoke_of_deceit')==PURCHASE_ITEM_SUCCESS then Log(b,'current_action_smoke_supplied')end
  else Log(b,'smoke_supply_deferred')end
 end
 if now>600 or #s.spellEvents<3 or b._teamplayStickBought then return end
 if b:FindItemSlot('item_magic_stick')>=0 or b:FindItemSlot('item_magic_wand')>=0 or b:FindItemSlot('item_holy_locket')>=0 then return end
 local slot=false;for i=0,5 do if not b:GetItemInSlot(i) then slot=true end end
 if not slot or b:GetStashValue()>0 or b:GetCourierValue()>0 then return end
 local cost=GetItemCost('item_magic_stick');local basic=b.currBuyingBasicItem
 local reserve=basic and GetItemCost(basic) or 500
 if b:GetGold()<cost+math.max(500,reserve) then return end
 if b:ActionImmediate_PurchaseItem('item_magic_stick')==PURCHASE_ITEM_SUCCESS then
  b._teamplayStickBought=true;Log(b,'reactive_stick_purchase')
 end
end
-- Any unexpected native API failure releases this advice for ten seconds.
-- A failed supplement must never prevent the existing item/ability/mode AI.
local defaults={WallOrderGoal=function()end,WallThink=function()return false end,Update=function() end,Intent=function() end,Focus=function(_,target) return target end,
 AttackTarget=function(_,target) return target end,Building=function() end,Convert=function() return false end,
 WardScore=function(_,_,distance) return distance end,Smoke=function() return false end,
 RememberMove=function()end,AllowEntitySpell=function()return true end,
 ReadyForInitiation=function() return true end,Chase=function() return true,'original_on_error' end,Purchase=function() end}
for name,fallback in pairs(defaults) do
 local original=X[name]
 X[name]=function(b,...)
  if b and DotaTime()<(b._teamplayFaultUntil or -999) then return fallback(b,...) end
  local ok,a,c=pcall(original,b,...)
  if ok then return a,c end
  if b and not b:IsNull() and b==GetBot() then
   b._teamplayFaultUntil=DotaTime()+10
   print(string.format('[TEAMPLAY_ERROR] t=%.2f pid=%d function=%s error=%s',DotaTime(),b:GetPlayerID(),name,tostring(a)))
  end
  return fallback(b,...)
 end
end
return X

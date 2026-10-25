-- Chen's real controlled army. No spawned units or hidden enemy information.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Name(u)return u:GetUnitName()end
local function Zealot(u)return Name(u):find('chen_zealot',1,true)or Name(u):find('chen_convert',1,true)end
function X.Register(b,u)
 if not V(u)or u:GetTeam()~=b:GetTeam()or u:IsBuilding()or u:IsIllusion()then return false end
 local name=Name(u)
 if u:IsHero()or name:find('ward',1,true)or name:find('courier',1,true)then return false end
 b._chenObserved=b._chenObserved or{};b._chenObserved[u]=true
 if not u._chenSlot then b._chenSlot=(b._chenSlot or 0)+1;u._chenSlot=b._chenSlot end
 return true
end
function X.Units(b)
 b._chenObserved=b._chenObserved or{}
 for _,u in ipairs(GetUnitList(UNIT_LIST_ALLIES)or{})do
  if V(u)and u:GetPlayerID()==b:GetPlayerID()and u:GetTeam()==b:GetTeam()and not u:IsHero()and not u:IsBuilding()
   and(u:HasModifier('modifier_chen_holy_persuasion')or Zealot(u))then b._chenObserved[u]=true end
 end
 local out={}
 for u in pairs(b._chenObserved)do
  if V(u)and u:GetTeam()==b:GetTeam()then out[#out+1]=u else b._chenObserved[u]=nil end
 end
 return out
end
function X.Count(b)
 local count,ancients=0,0
 for _,u in ipairs(X.Units(b))do if u:HasModifier('modifier_chen_holy_persuasion')then count=count+1;if u:IsAncientCreep()then ancients=ancients+1 end end end
 return count,ancients
end
local weights={npc_dota_neutral_centaur_khan=85,npc_dota_neutral_dark_troll_warlord=72,
 npc_dota_neutral_satyr_hellcaller=78,npc_dota_neutral_satyr_trickster=72,npc_dota_neutral_ogre_magi=70,
 npc_dota_neutral_alpha_wolf=80,npc_dota_neutral_enraged_wildkin=75,npc_dota_neutral_harpy_storm=68,
 npc_dota_neutral_forest_troll_high_priest=65,npc_dota_neutral_warpine_raider=75,
 npc_dota_neutral_big_thunder_lizard=95,npc_dota_neutral_black_dragon=95}
function X.Recruit(b,a,Fu)
 if not a:IsFullyCastable()or Fu.IsRetreating(b)or b:WasRecentlyDamagedByAnyHero(1)then return 0,nil end
 local count,ancients=X.Count(b);local cap=a:GetSpecialValueInt('max_units');local level=a:GetSpecialValueInt('level_req')
 if cap<=0 or level<=0 or count>=cap then return 0,nil end
 local god=b:GetAbilityByName('chen_hand_of_god');local ancientCap=god and god:GetLevel()or 0
 local range=Fu.GetProperCastRange(false,b,a:GetCastRange());local best,score
 for _,u in ipairs(b:GetNearbyNeutralCreeps(range)or{})do
  if V(u)and u:CanBeSeen()and not u:IsInvulnerable()and u:GetTeam()~=b:GetTeam()and u:GetLevel()<=level
   and(not u:IsAncientCreep()or b:HasModifier('modifier_item_aghanims_shard')and ancientCap>ancients)
   and not u:HasModifier('modifier_chen_holy_persuasion')then
   local value=(weights[Name(u)]or 35)-GetUnitToUnitDistance(b,u)*.015
   for _,old in ipairs(X.Units(b))do if Name(old)==Name(u)then value=value-25 end end
   if not score or value>score then best,score=u,value end
  end
 end
 if DotaTime()>=(b._chenArmyLog or -1)then b._chenArmyLog=DotaTime()+12
  print('[CHEN_ARMY] t='..DotaTime()..' pid='..b:GetPlayerID()..' count='..count..' cap='..cap..' phase='..(best and'recruit_candidate'or'no_legal_nearby_creep'))end
 if best then return BOT_ACTION_DESIRE_HIGH,best end
 return BOT_ACTION_DESIRE_NONE,nil
end
function X.Recall(b,a,Fu)
 if not a:IsFullyCastable()or Fu.IsRetreating(b)or Fu.IsGoingOnSomeone(b)or b:WasRecentlyDamagedByAnyHero(3)
  or #(b:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{})>0 then return 0 end
 for _,u in ipairs(X.Units(b))do if GetUnitToUnitDistance(b,u)>1400 and not u:WasRecentlyDamagedByAnyHero(3)
  and not u:HasModifier('modifier_chen_teleport')then return BOT_ACTION_DESIRE_HIGH end end
 return 0
end
-- Recruitment may use at most a short step already along the current route.
function X.RouteRecruit(b,a,Fu)
 if not a:IsFullyCastable()or Fu.IsGoingOnSomeone(b)or Fu.IsRetreating(b)or Fu.IsPushing(b)or Fu.IsDefending(b)
  or b._counterTask or b._guardTravel or b._guardBaseArea or Fu.IsAttacking(b)or b:WasRecentlyDamagedByAnyHero(3)
  or DotaTime()<(b._chenRouteNext or -1)then return false end
 local count=X.Count(b);if count>=a:GetSpecialValueInt('max_units')then return false end
 local move=b._originalMove;local now=DotaTime()
 if not move or not move.loc or not move.at or now-move.at>2 then return false end
 local here=b:GetLocation();local axis=move.loc;local dx,dy=axis.x-here.x,axis.y-here.y;local len=math.max(1,D(here,axis))
 for _,u in ipairs(b:GetNearbyNeutralCreeps(math.min(1000,a:GetCastRange()+220))or{})do
  if V(u)and u:CanBeSeen()and not u:IsAncientCreep()and u:GetLevel()<=a:GetSpecialValueInt('level_req')then
   local p=u:GetLocation();local along=((p.x-here.x)*dx+(p.y-here.y)*dy)/len
   local side=math.abs((p.x-here.x)*dy-(p.y-here.y)*dx)/len
   if along>0 and side<220 and D(here,p)>a:GetCastRange()then
    local step=math.min(200,D(here,p)-a:GetCastRange()+50);local d=math.max(1,D(here,p));local q=Vector(here.x+(p.x-here.x)/d*step,here.y+(p.y-here.y)/d*step,here.z)
    if require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,q)then
     b._chenRouteNext=now+8;b:Action_MoveToLocation(q);return true
    end
   end
  end
 end
 return false
end
local function Real(u,Fu)return V(u)and u:CanBeSeen()and u:IsHero()and not u:IsAttackImmune()and not Fu.IsSuspiciousIllusion(u)end
local control={centaur_khan_war_stomp='none',dark_troll_warlord_ensnare='unit',mud_golem_hurl_boulder='unit',mud_golem_rock_throw='unit',polar_furbolg_ursa_warrior_thunder_clap='none'}
local damage={satyr_hellcaller_shockwave='point',harpy_storm_chain_lightning='unit',warpine_raider_seed_shot='unit'}
local buff={ogre_magi_frost_armor=true,big_thunder_lizard_frenzy=true}
local function Cast(u,a,target,kind)
 u._chenNext=DotaTime()+.35
 if kind=='point'then u:Action_UseAbilityOnLocation(a,target)elseif kind=='unit'then u:Action_UseAbilityOnEntity(a,target)else u:Action_UseAbility(a)end
 return true
end
function X.Think(b,u,Fu)
 if require(GetScriptDirectory()..'/FuncLib/systems/channel_rescue').Try(b,Fu,u)then return true end
 if require(GetScriptDirectory()..'/FuncLib/systems/base_execution').Minion(b,u)then return true end
 if not X.Register(b,u)then return false end
 if u:IsUsingAbility()or u:IsCastingAbility()or u:IsChanneling()or u:IsStunned()or u:IsHexed()
  or DotaTime()<(u._chenNext or -1)then return true end
 u._chenNext=DotaTime()+.25
 local target=b:GetAttackTarget();if not V(target)then target=Fu.GetProperTarget(b)end
 local retreat=not b:IsAlive()or Fu.IsRetreating(b)or HP(u)<.25 or b._battleExit and DotaTime()<b._battleExit.untilTime
 local enemies=u:GetNearbyHeroes(1200,true,BOT_MODE_NONE)or{}
 if not Real(target,Fu)and not(V(target)and target:IsBuilding())then target=nil end
 if target and target:IsHero()and (retreat or GetUnitToUnitDistance(b,target)>1300)then target=nil end
 local enemy=target and target:IsHero()and target or nil
 if not enemy then for _,e in ipairs(enemies)do if Real(e,Fu)and(b:WasRecentlyDamagedByHero(e,2)or e:IsChanneling())then enemy=e;break end end end
 if not u:IsSilenced()then for slot=0,23 do local a=u:GetAbilityInSlot(slot)
  if a and not a:IsNull()and not a:IsHidden()and not a:IsPassive()and a:IsFullyCastable()then
   local name=a:GetName();local range=a:GetCastRange();local kind=control[name]or damage[name]
   if kind and enemy and Fu.CanCastOnNonMagicImmune(enemy)then
    local r=kind=='none'and a:GetSpecialValueInt('radius')or range
    local held=require(GetScriptDirectory()..'/FuncLib/systems/control_chain').Remaining(enemy)
    local ready=not control[name]or enemy:IsChanneling()or held<a:GetCastPoint()+.45
    if ready and GetUnitToUnitDistance(u,enemy)<=math.max(100,r)-15 and(not retreat or control[name])then
     if kind=='point'then local speed=a:GetSpecialValueInt('speed');return Cast(u,a,Fu.GetCorrectLoc(enemy,a:GetCastPoint()+GetUnitToUnitDistance(u,enemy)/math.max(600,speed)),kind)
     else return Cast(u,a,enemy,kind)end
    end
   elseif name=='dark_troll_warlord_raise_dead'and not retreat and target and GetUnitToUnitDistance(u,target)<700
    and(target:IsHero()or target:IsBuilding()and Fu.IsPushing(b))then return Cast(u,a,nil,'none')
   elseif buff[name]then
    for _,ally in ipairs(u:GetNearbyHeroes(range,false,BOT_MODE_NONE)or{})do if V(ally)and not ally:IsIllusion()and(ally:WasRecentlyDamagedByAnyHero(2)or Fu.IsGoingOnSomeone(ally))then
     local modifier=name=='ogre_magi_frost_armor'and'modifier_ogre_magi_frost_armor'or'modifier_big_thunder_lizard_frenzy'
     if not ally:HasModifier(modifier)then return Cast(u,a,ally,'unit')end
    end end
   elseif name=='forest_troll_high_priest_heal'then
    for _,ally in ipairs(u:GetNearbyHeroes(range,false,BOT_MODE_NONE)or{})do if V(ally)and not ally:IsIllusion()and HP(ally)<.7 then return Cast(u,a,ally,'unit')end end
   elseif name=='satyr_trickster_purge'and enemy and GetUnitToUnitDistance(u,enemy)<range and not enemy:IsMagicImmune()
    and(enemy:HasModifier('modifier_ghost_state')or enemy:GetCurrentMovementSpeed()>420)then return Cast(u,a,enemy,'unit')
   elseif name=='chen_martyrdom'then
    local behavior=a:GetBehavior();local targeted=math.floor(behavior/8)%2==1
    for _,ally in ipairs(u:GetNearbyHeroes(math.max(250,range),false,BOT_MODE_NONE)or{})do
     if V(ally)and not ally:IsIllusion()and HP(ally)<.45 and(HP(u)<.35 or ally:WasRecentlyDamagedByAnyHero(1))then
      return Cast(u,a,ally,targeted and'unit'or'none')
     end
    end
    if enemy and HP(u)<.3 and GetUnitToUnitDistance(u,enemy)<=math.max(200,range)and not enemy:IsMagicImmune()then return Cast(u,a,enemy,targeted and'unit'or'none')end
   end
  end
 end end
 local safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
 if retreat then
  local here=u:GetLocation();local anchor=b:IsAlive()and b:GetLocation()or GetAncient(b:GetTeam()):GetLocation()
  local len=math.max(1,D(here,anchor));local q=Vector(here.x+(anchor.x-here.x)/len*350,here.y+(anchor.y-here.y)/len*350,here.z)
  if D(here,anchor)>250 and safe(u,q)then u:Action_MoveToLocation(q)end
  return true
 end
 if target and GetUnitToUnitDistance(u,target)<1400 and not target:IsInvulnerable()and not target:IsAttackImmune()then
  local here,to=u:GetLocation(),target:GetLocation();local safeApproach=target:IsBuilding()or safe(u,to)
  if safeApproach then if u:GetAttackTarget()~=target then u:Action_AttackUnit(target,false)end;return true end
 end
 if b:IsAlive()then
  local here=b:GetLocation();local angle=((u._chenSlot or 1)%7)*.8976;local distance=u:GetAttackRange()>350 and 380 or 200
  local q=Vector(here.x+math.cos(angle)*distance,here.y+math.sin(angle)*distance,here.z)
  if D(u:GetLocation(),q)>260 and safe(u,q)then u:Action_MoveToLocation(q)end
 end
 return true
end
return X

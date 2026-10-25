-- Shared, local response to a publicly observed active Static Link. Never schedules a team task.
local X={}
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local debuff='modifier_razor_static_link_debuff'
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,c)if not a or not c then return math.huge end;return math.sqrt((a.x-c.x)^2+(a.y-c.y)^2)end
local function Own(b)return V(b)and b==GetBot()and b:IsHero()and not b:IsIllusion()end
local function Busy(b)return not Own(b)or b:IsInvulnerable()or b:IsChanneling()or b:IsUsingAbility()or b:IsCastingAbility()
 or b:IsStunned()or b:IsHexed()or b:IsInvisible()or b:NumQueuedActions()>0
 or b:HasModifier('modifier_bloodseeker_rupture')or b:HasModifier('modifier_batrider_flaming_lasso')end
local function Log(b,phase)
 local s=b._staticLinkState;local now=DotaTime()
 if now>=(s.logNext or -1)then s.logNext=now+1;print('[STATIC_LINK] t='..now..' pid='..b:GetPlayerID()..' phase='..phase)end
end
local function Mod(u)
 local i=u:GetModifierByName(debuff);if not i or i<0 then return nil end
 return u:GetModifierRemainingDuration(i),u:GetModifierStackCount(i)
end
local function Walk(b,r,v)
 local here=b:GetLocation();local source=r:GetLocation();local best,score
 for i=0,15 do local angle=i*math.pi/8
  local p=Vector(here.x+math.cos(angle)*420,here.y+math.sin(angle)*420,here.z)
  local gain=D(p,source)-D(here,source)
  if gain>120 and Safe(b,p)then
   local good=true
   for j=1,5 do if not Safe(b,Vector(here.x+(p.x-here.x)*j/5,here.y+(p.y-here.y)*j/5,here.z))then good=false;break end end
   if good then local value=gain;local home=GetAncient(b:GetTeam());if V(home)then value=value-D(p,home:GetLocation())*.01 end
    if not score or value>score then best,score=p,value end
   end
  end
 end
 return best
end
function X.Update(b)
 if not Own(b)then return nil end
 local now=DotaTime();local s=b._staticLinkState or{victims={}};b._staticLinkState=s
 if now<(s.next or -999)then return s end;s.next=now+.1;s.active=nil;s.assist=nil;b._staticLinkEscape=nil
 local victims={b};for _,a in ipairs(b:GetNearbyHeroes(1100,false,BOT_MODE_NONE)or{})do if a~=b and V(a)and not a:IsIllusion()then victims[#victims+1]=a end end
 local razor
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()and e:GetUnitName()=='npc_dota_hero_razor'then razor=e;break end
 end
 if not razor then return s end
 local skill=razor:GetAbilityByName('razor_static_link');if not skill then return s end
 local range=skill:GetCastRange()+skill:GetSpecialValueInt('drain_range_buffer');if range<700 then range=800 end
 local linger=skill:GetSpecialValueInt('drain_duration');if linger<=0 then linger=12 end
 for _,v in ipairs(victims)do
  local rem,stacks=Mod(v);local id=v:GetPlayerID();local old=s.victims[id]
  if not rem then s.victims[id]=nil
  else
   if not old or rem>(old.remaining or rem)+2 then old={first=now,lastGrowth=now};s.victims[id]=old end
   if stacks~=(old.stacks or stacks)then old.lastGrowth=now end
   old.stacks=stacks;old.remaining=rem
   local distance=GetUnitToUnitDistance(v,razor)
   if distance>range+90 then
    if not old.sealed then Log(b,'range_break_observed')end;old.sealed=true
   elseif not old.sealed and rem<linger-.6 and now-(old.lastGrowth or now)>.7 then old.sealed=true end
   if not old.sealed and now-old.first<11 then
    local rec={victim=v,razor=razor,range=range}
    if v==b then s.active=rec;b._staticLinkEscape=true
    elseif not s.assist or v:GetHealth()/v:GetMaxHealth()<s.assist.victim:GetHealth()/s.assist.victim:GetMaxHealth()then s.assist=rec end
   end
  end
 end
 return s
end
local blinks={item_blink=true,item_overwhelming_blink=true,item_arcane_blink=true,item_swift_blink=true,
 antimage_blink=true,queenofpain_blink=true,faceless_void_time_walk=true}
local controls={lion_impale='point',lion_voodoo='entity',shadow_shaman_voodoo='entity',vengefulspirit_magic_missile='entity',
 sven_storm_bolt='entity',chaos_knight_chaos_bolt='entity',crystal_maiden_frostbite='entity',
 ogre_magi_fireblast='entity',tiny_avalanche='point',lina_light_strike_array='point',leshrac_split_earth='point',
 jakiro_ice_path='point',earthshaker_fissure='point'}
local function Ready(a,b)
 if not a or a:IsNull()or not a:IsFullyCastable()or a:IsHidden()then return false end
 local item=a:GetName():find('item_',1,true)==1
 return not(item and b.IsMuted and b:IsMuted()or not item and b:IsSilenced())
end
local function PointAway(u,r,step)
 local p,c=u:GetLocation(),r:GetLocation();local d=math.max(1,D(p,c));return Vector(p.x+(p.x-c.x)*step/d,p.y+(p.y-c.y)*step/d,p.z)
end
local function FacingPoint(u,step)
 local p=u:GetLocation();local a=u:GetFacing()*math.pi/180;return Vector(p.x+math.cos(a)*step,p.y+math.sin(a)*step,p.z)
end
function X.Try(b)
 local s=X.Update(b);if not s or Busy(b)then return false end
 local rec=s.active or s.assist;if not rec then return false end
 local v,r=rec.victim,rec.razor;if not V(v)or not V(r)or not r:CanBeSeen()then return false end
 if v==b and b:GetEstimatedDamageToTarget(true,r,.8,DAMAGE_TYPE_PHYSICAL)>r:GetHealth()*1.25
  and GetUnitToUnitDistance(b,r)<=b:GetAttackRange()+50 then b._staticLinkEscape=nil;s.killUntil=DotaTime()+.3;return false end
 local walk=v==b and not b:IsRooted()and Walk(b,r,v)or nil
 if DotaTime()>=(s.spellNext or -999)then
  local spells={};for i=0,5 do spells[#spells+1]=b:GetItemInSlot(i)end
  for i=0,23 do local a=b:GetAbilityInSlot(i);if a then spells[#spells+1]=a end end
  for _,a in ipairs(spells)do if Ready(a,b)then local n=a:GetName();local cast=a:GetCastRange()
   if v==b and blinks[n]and not b:IsRooted()then
    local p=PointAway(b,r,math.min(900,math.max(350,cast)))
    if Safe(b,p)and D(p,r:GetLocation())>rec.range+80 then b:Action_UseAbilityOnLocation(a,p);s.spellNext=DotaTime()+.8;Log(b,'self_displacement');return true end
   elseif(n=='item_force_staff'or n=='item_hurricane_pike')and GetUnitToUnitDistance(b,v)<=cast+50 then
    local p=FacingPoint(v,600)
    if D(p,r:GetLocation())>GetUnitToUnitDistance(v,r)+200 and Safe(v,p)then
     b:Action_UseAbilityOnEntity(a,v);s.spellNext=DotaTime()+.8;Log(b,'ally_push_away');return true
    end
   elseif n=='vengefulspirit_nether_swap'and v~=b and GetUnitToUnitDistance(b,r)<=cast
    and not require(GetScriptDirectory()..'/FuncLib/func_utils').IsReflectingSpells(r)
    and GetUnitToUnitDistance(b,v)>rec.range+100 and b:GetHealth()/b:GetMaxHealth()>.65 and Safe(b,r:GetLocation())then
    b:Action_UseAbilityOnEntity(a,r);s.spellNext=DotaTime()+.8;Log(b,'enemy_displacement');return true
   elseif controls[n]and not r:IsMagicImmune()and not r:IsStunned()and not r:IsHexed()and GetUnitToUnitDistance(b,r)<=cast then
    local f=require(GetScriptDirectory()..'/FuncLib/func_utils')
    if not f.IsReflectingSpells(r)then
     if controls[n]=='entity'then b:Action_UseAbilityOnEntity(a,r)else b:Action_UseAbilityOnLocation(a,r:GetLocation())end
     s.spellNext=DotaTime()+.8;Log(b,'control_escape_window');return true
    end
   end
  end end
 end
 if walk then
  b._staticLinkGoal=walk;b._staticLinkGoalUntil=DotaTime()+.3
  if DotaTime()>=(s.moveNext or -999)then s.moveNext=DotaTime()+.3;b:Action_MoveToLocation(walk);Log(b,'increase_separation')end
  return true
 end
 return false
end
function X.OrderGoal(b,action)
 if Busy(b)or b:IsRooted()then return nil end
 if not(action:find('Move',1,true)or action:find('Attack',1,true))then return nil end
 local s=X.Update(b);if not s or not s.active or DotaTime()<(s.killUntil or -999)then return nil end
 local goal=b._staticLinkGoal
 if goal and DotaTime()<(b._staticLinkGoalUntil or -999)then return goal end
 return Walk(b,s.active.razor,b)
end
for name,fallback in pairs({Update=function()end,Try=function()return false end,OrderGoal=function()end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,r=pcall(raw,b,...);if ok then return r end
  if b and DotaTime()>=(b._staticLinkErrorNext or -999)then b._staticLinkErrorNext=DotaTime()+10;print('[STATIC_LINK_ERROR] '..tostring(r))end
  return fallback()
 end
end
return X

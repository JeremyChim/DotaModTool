-- A locally selected combo owns its approach and spell orders until confirmed or released.
local X={};local Policy=require(GetScriptDirectory()..'/FuncLib/systems/engagement_policy')
local Safe=require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe
local function Log(b,phase)print('[ENIGMA_COMBO] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase='..phase)end
local function Release(b,why)
 b._enigmaCombo=nil;b._comboOwnOrder=nil;b._enigmaRetryAt=DotaTime()+.35;Log(b,why);return false
end
local function Valid(b,s,Fu)
 return s.hole:IsFullyCastable()and not Fu.IsRetreating(b)
  and #Policy.Enemies(b,s.loc,s.radius,Fu,true)>=s.minimum
  and require(GetScriptDirectory()..'/FuncLib/systems/enigma_value').Allow(b,Fu,s.loc,s.hole,false)
end
function X.Begin(b,Fu,loc,hole,pulse,blink,bkb,minimum)
 if b._enigmaCombo then return true end
 if DotaTime()<(b._enigmaRetryAt or -1)then return false end
 local s={loc=loc,hole=hole,radius=hole:GetSpecialValueInt('radius')*.85,minimum=minimum or 1,
  deadline=DotaTime()+4.5,steps={},index=1}
 if not Valid(b,s,Fu)then return Release(b,'initial_target_rejected')end
 local range=Fu.GetProperCastRange(false,b,hole:GetCastRange())
 local distance=GetUnitToLocationDistance(b,loc)
 if not blink and distance>range+20 then
  local walk=distance-math.max(0,range-30)
  if walk>350 then return Release(b,'approach_too_far')end
  local here=b:GetLocation();local p=Vector(here.x+(loc.x-here.x)*walk/math.max(1,distance),here.y+(loc.y-here.y)*walk/math.max(1,distance),here.z)
  if not Safe(b,p)then return Release(b,'unsafe_approach')end
  s.steps[#s.steps+1]={walk=true,loc=p,range=range}
 end
 local useBkb=bkb and bkb:IsFullyCastable()and not b:IsMagicImmune()
 local reserved=hole:GetManaCost()+(blink and blink:GetManaCost()or 0)+(useBkb and bkb:GetManaCost()or 0)
 if b:GetMana()<reserved then return Release(b,'insufficient_combo_mana')end
 if useBkb then s.steps[#s.steps+1]={a=bkb}end
 if blink then s.steps[#s.steps+1]={a=blink,location=true,blink=true}end
 if pulse and pulse:IsFullyCastable()and b:GetMana()>=reserved+pulse:GetManaCost()then s.steps[#s.steps+1]={a=pulse,location=true}end
 s.steps[#s.steps+1]={a=hole,location=true,hole=true}
 b._enigmaCombo=s;Log(b,'selected');return X.Step(b,Fu)
end
function X.Step(b,Fu)
 local s=b._enigmaCombo;if not s then return false end
 local now=DotaTime();local step=s.steps[s.index]
 if not b:IsAlive()or now>s.deadline or Fu.IsRetreating(b)then return Release(b,'deadline_or_danger_release')end
 if s.sent then
  if step.a:GetCooldownTimeRemaining()>s.cooldown+.1 then
   if step.hole then require(GetScriptDirectory()..'/FuncLib/systems/enigma_value').Record(b,Fu,s.loc,s.hole);b._enigmaCombo=nil;Log(b,'black_hole_cast_observed');return true end
   s.index=s.index+1;s.sent=nil;step=s.steps[s.index]
  elseif now-s.sent>(s.ackAfter or 1)and not b:IsUsingAbility()and not b:IsCastingAbility()then
   return Release(b,'unconfirmed_release')
  else return true end
 end
 if b:IsUsingAbility()or b:IsCastingAbility()or b:IsChanneling()or b:IsStunned()or b:IsHexed()then return true end
 if not Valid(b,s,Fu)then return Release(b,'target_left_release')end
 if step.walk then
  if GetUnitToLocationDistance(b,s.loc)<=step.range+20 then s.index=s.index+1;return true end
  if not Safe(b,step.loc)then return Release(b,'unsafe_approach')end
  if now>=(s.moveNext or -1)then
   s.moveNext=now+.4;b._comboOwnOrder=true;b:Action_MoveToLocation(step.loc);b._comboOwnOrder=nil
  end
  return true
 end
 if b:NumQueuedActions()>0 then return true end
 local range=step.location and Fu.GetProperCastRange(false,b,step.a:GetCastRange())or 0
 if step.location and not step.blink and GetUnitToLocationDistance(b,s.loc)>range+35 then return Release(b,'out_of_range_release')end
 if not step.a:IsFullyCastable()then return Release(b,'unavailable_release')end
 s.cooldown=step.a:GetCooldownTimeRemaining();s.sent=now;s.ackAfter=math.max(1,step.a:GetCastPoint()+.6)
 b._comboOwnOrder=true
 if step.location then b:Action_UseAbilityOnLocation(step.a,s.loc)else b:Action_UseAbility(step.a)end
 b._comboOwnOrder=nil
 Log(b,step.hole and 'black_hole_order'or step.blink and 'blink_order'or step.location and 'pulse_order'or 'bkb_order')
 return true
end
for name,fallback in pairs({Begin=function()return false end,Step=function()return false end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,result=pcall(raw,b,...);if ok then return result end
  b._enigmaCombo=nil;b._comboOwnOrder=nil;b._enigmaRetryAt=DotaTime()+1
  print('[LOCAL_ADVICE_ERROR] module=enigma_combo function='..name..' error='..tostring(result));return fallback()
 end
end
return X

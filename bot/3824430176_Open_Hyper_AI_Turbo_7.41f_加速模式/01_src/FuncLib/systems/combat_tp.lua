-- A local combat handoff gate shared by generic and coordinated TP entries.
local X={}
local closers={phantom_assassin_phantom_strike=true,antimage_blink=true,queenofpain_blink=true,
 item_blink=true,item_overwhelming_blink=true,item_swift_blink=true,item_arcane_blink=true,
 item_abyssal_blade=true,slark_pounce=true,faceless_void_time_walk=true}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
function X.Record(b,a,target)
 if not b or b~=GetBot()or not a then return end
 local n=a:GetName()
 local enemy=(type(target)=='table'or type(target)=='userdata')and target.IsHero and V(target)and target:IsHero()and target:GetTeam()~=b:GetTeam()
 if closers[n]or enemy then b._combatTPUntil=DotaTime()+1.6;b._combatTPSpell=n end
 -- A normal teleport landing may need a short local rescue handoff.
 if n=='item_tpscroll'then b._rescueTP={at=DotaTime(),source=b:GetLocation(),seen=false}end
end
function X.Allow(b,destination,urgent)
 if not b or b~=GetBot()or not destination then return true end
 local reason
 if GetUnitToLocationDistance(b,destination)<900 then reason='already_local'
 elseif not urgent then
  local t=b:GetAttackTarget()
  if DotaTime()<(b._combatTPUntil or -999)then reason='recent_combat_order'
  elseif V(t)and t:IsHero()and t:CanBeSeen()and t:GetTeam()~=b:GetTeam()
   and GetUnitToUnitDistance(b,t)<=b:GetAttackRange()+180 then reason='close_combat' end
  -- Urgent survival TP remains the escape evaluator's responsibility.
  if b:GetActiveMode()==BOT_MODE_RETREAT or b:GetHealth()/math.max(1,b:GetMaxHealth())<.25 then reason=nil end
 end
 if not reason then return true end
 if DotaTime()>=(b._combatTPLogNext or -999)then b._combatTPLogNext=DotaTime()+2
  print('[COMBAT_TP] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase=veto reason='..reason)end
 return false
end
return X

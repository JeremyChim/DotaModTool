-- Ready spells only, no approach orders and no team task creation.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()and u:CanBeSeen()end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local save={lich_frost_shield={modifier='modifier_lich_frost_shield'},
 abaddon_aphotic_shield={modifier='modifier_abaddon_aphotic_shield'},
 dazzle_shallow_grave={modifier='modifier_dazzle_shallow_grave',maxHP=.3},
 oracle_false_promise={modifier='modifier_oracle_false_promise',maxHP=.35},
 omniknight_purification={maxHP=.6},treant_living_armor={modifier='modifier_treant_living_armor',maxHP=.55}}
local control={lion_voodoo='entity',lion_impale='point',shadow_shaman_voodoo='entity',
 crystal_maiden_frostbite='entity',witch_doctor_paralyzing_cask='entity',techies_sticky_bomb='point',
 vengefulspirit_magic_missile='entity',sven_storm_bolt='entity',chaos_knight_chaos_bolt='entity',
 lich_sinister_gaze='entity',leshrac_split_earth='point',lina_light_strike_array='point',
 nyx_assassin_impale='point',tiny_avalanche='point',jakiro_ice_path='point',earthshaker_fissure='point'}
local function Kind(a,wanted)
 local flags=a:GetBehavior();local entity=math.floor(flags/8)%2==1;local point=math.floor(flags/16)%2==1
 if wanted=='point'and point then return 'point' end
 if entity then return 'entity' end
 if point then return 'point' end
end
local function AbilityName(a)
 if not a then return nil end
 local ok,n=pcall(function()if not a:IsNull()then return a:GetName()end end)
 return ok and type(n)=='string'and n or nil
end
local function Capture(b)
 local a=b:GetCurrentActiveAbility();return b:IsChanneling()and AbilityName(a)=='ability_capture'
end
local function ObserveTP(b)
 local s=b and b._rescueTP;if not s then return end
 local now=DotaTime()
 if not b:IsAlive()or now-s.at>20 then b._rescueTP=nil;return end
 if b:HasModifier('modifier_teleporting')then s.seen=true
 elseif s.seen and not s.landed then
  local a,c=s.source,b:GetLocation();local dx,dy=a.x-c.x,a.y-c.y
  if dx*dx+dy*dy>1200*1200 then s.landed=now;s.untilTime=now+5
  else b._rescueTP=nil end
 end
end
local function Approach(b,Fu)
 local tp=b._rescueTP;local now=DotaTime()
 if not tp or not tp.landed or now>tp.untilTime or HP(b)<.6 or b._guardTravel or b._guardBaseArea
  or b._counterTask or Fu.IsRetreating(b)or Fu.IsDefending(b)or Fu.IsDoingRoshan(b)or Fu.IsDoingTormentor(b)
  or b:WasRecentlyDamagedByAnyHero(1)then return false end
 local allies=b:GetNearbyHeroes(1600,false,BOT_MODE_NONE)or{}
 local enemies=b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{};local friends=1;local foes=0
 for _,a in ipairs(allies)do if a~=b and V(a)and not a:IsIllusion()and HP(a)>.35 then friends=friends+1 end end
 for _,e in ipairs(enemies)do if V(e)and not Fu.IsSuspiciousIllusion(e)then foes=foes+1 end end
 if foes>friends then return false end
 for _,ally in ipairs(allies)do
  if ally~=b and V(ally)and not ally:IsIllusion()and HP(ally)>.2 and HP(ally)<.7 and ally:WasRecentlyDamagedByAnyHero(.8)then
   for _,e in ipairs(enemies)do
    if V(e)and not Fu.IsSuspiciousIllusion(e)and ally:WasRecentlyDamagedByHero(e,1)
     and Fu.CanCastOnNonMagicImmune(e)and not Fu.IsDisabled(e)then
     for slot=0,23 do local a=b:GetAbilityInSlot(slot)
      if AbilityName(a)and control[AbilityName(a)]and not a:IsHidden()and a:GetLevel()>0 and a:IsFullyCastable()
       and b:GetMana()>=a:GetManaCost()+50 and Kind(a,control[a:GetName()])
       and (Kind(a,control[a:GetName()])=='point'or Fu.CanCastOnTargetAdvanced(e))then
       local range=Fu.GetProperCastRange(false,b,a:GetCastRange());local d=GetUnitToUnitDistance(b,e)
       if d>range-15 and d<=range+400 then
        local here,to=b:GetLocation(),e:GetLocation();local step=math.min(400,d-range+60)
        local point=Vector(here.x+(to.x-here.x)/math.max(1,d)*step,here.y+(to.y-here.y)/math.max(1,d)*step,here.z)
        local safe=true
        for i=1,6 do if not require(GetScriptDirectory()..'/FuncLib/systems/local_evasion').Safe(b,Vector(here.x+(point.x-here.x)*i/6,here.y+(point.y-here.y)*i/6,here.z))then safe=false end end
        if safe then
         if now>=(tp.nextMove or -1)then tp.nextMove=now+.4;b._localRescueUntil=now+.6;b:Action_MoveToLocation(point)
          if now>=(tp.nextLog or -1)then tp.nextLog=now+1;print('[NEARBY_RESCUE] t='..now..' pid='..b:GetPlayerID()..' phase=tp_local_approach spell='..a:GetName())end end
         return true
        end
       end
      end
     end
    end
   end
  end
 end
 return false
end
function X.Try(b,Fu)
 if require(GetScriptDirectory()..'/FuncLib/systems/channel_rescue').Try(b,Fu)then return true end
 ObserveTP(b)
 local capture=b and Capture(b)
 if not b or b~=GetBot()or not V(b)or b:IsIllusion()or b:IsInvulnerable()or b:IsInvisible()
  or (b:IsUsingAbility()and not capture)or b:IsCastingAbility()or b:IsStunned()or b:IsHexed()or b:IsSilenced()
  or b._enigmaCombo or b._invokerPlan or HP(b)<.3 or b:HasModifier('modifier_smoke_of_deceit')
  or DotaTime()<(b._rescueNext or -999)or DotaTime()<(b._ohaAbilityOrderAt or -999)+.3 then return false end

 if b:IsChanneling()and not capture or b:NumQueuedActions()>0 and not capture then return false end
 local enemies=b:GetNearbyHeroes(1400,true,BOT_MODE_NONE)or{}
 local best,score
 local protect=require(GetScriptDirectory()..'/FuncLib/systems/ultimate_coordination').ProtectTarget(b,Fu)
 if protect then for slot=0,23 do local a=b:GetAbilityInSlot(slot);local name=AbilityName(a)
  if name and control[name]and not a:IsHidden()and a:IsFullyCastable()and b:GetMana()>=a:GetManaCost()+50
   and Fu.CanCastOnNonMagicImmune(protect)and GetUnitToUnitDistance(b,protect)<=Fu.GetProperCastRange(false,b,a:GetCastRange())-15
   and(Kind(a,control[name])=='point'or Fu.CanCastOnTargetAdvanced(protect))then
   best={a=a,name=name,target=protect,kind=Kind(a,control[name])};score=125;break
  end
 end end
 for _,ally in ipairs(b:GetNearbyHeroes(1000,false,BOT_MODE_NONE)or{})do
  if ally~=b and V(ally)and not ally:IsIllusion()and not ally:IsInvulnerable()and ally:WasRecentlyDamagedByAnyHero(1)
   and HP(ally)<.7 then
   local attacker
   for _,e in ipairs(enemies)do
    if V(e)and not Fu.IsSuspiciousIllusion(e)and ally:WasRecentlyDamagedByHero(e,1)
     and GetUnitToUnitDistance(e,ally)<900 then attacker=e;break end
   end
   -- An actual hit from a hidden attacker permits ally saves, never entity attacks into fog.
   if attacker or ally:WasRecentlyDamagedByAnyHero(.5)then
    for slot=0,23 do local a=b:GetAbilityInSlot(slot)
     if a and not a:IsNull()and not a:IsHidden()and a:GetLevel()>0 and a:IsFullyCastable()
      and b:GetMana()>=a:GetManaCost()+50 then
      local name=a:GetName();local cfg=save[name];local victim,kind,value
      local range=Fu.GetProperCastRange(false,b,a:GetCastRange())
      if cfg and Kind(a,'entity')=='entity'and HP(ally)<(cfg.maxHP or .7)and(not cfg.modifier or not ally:HasModifier(cfg.modifier))
       and GetUnitToUnitDistance(b,ally)<=range-15 then victim=ally;kind='entity';value=100+(1-HP(ally))*100
      elseif control[name]and Kind(a,control[name])and attacker and GetUnitToUnitDistance(b,attacker)<=range-15
       and Fu.CanCastOnNonMagicImmune(attacker)and not Fu.IsDisabled(attacker)
       and(Kind(a,control[name])=='point'or Fu.CanCastOnTargetAdvanced(attacker))then
       victim=attacker;kind=Kind(a,control[name]);value=60+(1-HP(ally))*100
      end
      if victim and(not score or value>score)then best={a=a,name=name,target=victim,kind=kind};score=value end
     end
    end
   end
  end
 end
 if not best then return Approach(b,Fu) end
 local live=b:GetAbilityByName(best.name)
 if not AbilityName(live)then for slot=0,23 do local a=b:GetAbilityInSlot(slot);if AbilityName(a)==best.name then live=a;break end end end
 if not AbilityName(live)or not live:IsFullyCastable()or not V(best.target)then return false end
 best.a=live
 if capture then b:Action_ClearActions(false)end
 b._rescueNext=DotaTime()+.6;b._localRescueUntil=DotaTime()+1.1
 if best.kind=='point'then b:Action_UseAbilityOnLocation(best.a,Fu.GetCorrectLoc(best.target,best.a:GetCastPoint()+.15))
 else b:Action_UseAbilityOnEntity(best.a,best.target)end
 print('[NEARBY_RESCUE] t='..DotaTime()..' pid='..b:GetPlayerID()..' phase='..(capture and'capture_yield_cast'or'in_range_cast')..' spell='..best.name)
 return true
end
function X.BlockCapture(b,ability)
 return b and b==GetBot()and AbilityName(ability)=='ability_capture'and DotaTime()<(b._localRescueUntil or -999)
end
local raw=X.Try
function X.Try(b,...)
 local ok,result=pcall(raw,b,...);if ok then return result end
 if b and DotaTime()>=(b._rescueErrorNext or -999)then b._rescueErrorNext=DotaTime()+10
  print('[EXECUTION_ERROR] module=nearby_rescue error='..tostring(result))end
 return false
end
return X

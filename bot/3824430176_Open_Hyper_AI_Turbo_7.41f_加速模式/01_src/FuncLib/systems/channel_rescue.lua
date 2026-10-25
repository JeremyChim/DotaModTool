-- Shared response to a visible damaging/control channel affecting a real nearby ally.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function HP(u)return u:GetHealth()/math.max(1,u:GetMaxHealth())end
local channels={shadow_shaman_shackles='modifier_shadow_shaman_shackles',pudge_dismember='modifier_pudge_dismember',
 bane_fiends_grip='modifier_bane_fiends_grip',enigma_black_hole='modifier_enigma_black_hole_pull',
 lich_sinister_gaze='modifier_lich_sinister_gaze',witch_doctor_death_ward=false,crystal_maiden_freezing_field=false}
-- kind, effective landing delay, projectile speed, pierces immunity. Roots/slows are intentionally absent.
local spells={
 lion_voodoo={'entity',0},lion_impale={'point',.1,1600},shadow_shaman_voodoo={'entity',0},shadow_shaman_shackles={'entity',0},
 vengefulspirit_magic_missile={'entity',0,1500},sven_storm_bolt={'entity',0,1000},chaos_knight_chaos_bolt={'entity',0,700},
 ogre_magi_fireblast={'entity',0},ogre_magi_unrefined_fireblast={'entity',0},skeleton_king_hellfire_blast={'entity',0,1000},
 lina_light_strike_array={'point',.5},leshrac_split_earth={'point',.35},nyx_assassin_impale={'point',.1,1600},jakiro_ice_path={'point',.5},
 earthshaker_fissure={'point',0},earthshaker_enchant_totem={'none',0},tiny_avalanche={'point',.3},
 beastmaster_primal_roar={'entity',0,nil,true},doom_bringer_doom={'entity',0,nil,true},
 -- Remnant-dependent Earth Spirit casts stay with the hero's geometry-aware AI.
 puck_waning_rift={'point',0},death_prophet_silence={'point',0},drow_ranger_wave_of_silence={'point',0,2000},
 skywrath_mage_ancient_seal={'entity',0},silencer_last_word={'entity',0},
 night_stalker_crippling_fear={'none',0},riki_smoke_screen={'point',0},
 naga_siren_ensnare=nil,slardar_slithereen_crush={'none',0},centaur_hoof_stomp={'none',0},
 centaur_khan_war_stomp={'none',0},polar_furbolg_ursa_warrior_thunder_clap=nil,
 mud_golem_hurl_boulder={'entity',0,1200},dark_troll_warlord_ensnare=nil,
 morphling_adaptive_strike_str={'entity',0,1150},sandking_burrowstrike={'point',0},
 dragon_knight_dragon_tail={'entity',0,1600},tusk_walrus_punch={'entity',0},tidehunter_ravage={'none',.2},
 disruptor_static_storm={'point',.1},brewmaster_earth_hurl_boulder={'entity',0,1000},
 brewmaster_storm_cyclone={'entity',0},rubick_telekinesis={'entity',0},
 lina_flame_cloak=nil,windrunner_shackleshot={'entity',0,1650},
 spirit_breaker_nether_strike={'entity',1,nil,true},kunkka_ghostship={'point',2.5},kunkka_torrent={'point',1.6},
 bane_nightmare={'entity',0},techies_suicide={'point',.8},mars_spear={'point',.1,1400},
 -- Bushwhack needs a tree; Chronosphere can trap the victim too. Keep their original placement evaluators.
 dawmbreaker_fire_wreath=nil,
 magnataur_reverse_polarity={'none',0,nil,true},
 batrider_flaming_lasso={'entity',0,nil,true},bat_rider_flaming_lasso={'entity',0,nil,true}}
local items={item_sheepstick={'entity',0},item_cyclone={'entity',0},item_wind_waker={'entity',0},
 item_abyssal_blade={'entity',0,nil,true},item_orchid={'entity',0},item_bloodthorn={'entity',0}}
local function Name(a)if not a then return nil end;local ok,n=pcall(function()if not a:IsNull()then return a:GetName()end end);return ok and n or nil end
local function Kind(a,k)local f=a:GetBehavior();if k=='point'and math.floor(f/16)%2==1 then return'point'end;if k=='entity'and math.floor(f/8)%2==1 then return'entity'end;if k=='none'and math.floor(f/4)%2==1 then return'none'end end
function X.Try(b,Fu,unit)
 local u=unit or b;local now=DotaTime()
 if b~=GetBot()or not V(b)or not V(u)or u:IsIllusion()or u:IsInvulnerable()or u:IsStunned()or u:IsHexed()
  or u:IsChanneling()or u:IsUsingAbility()or u:IsCastingAbility()or u:NumQueuedActions()>0 or HP(u)<.25
  or b._enigmaCombo or b._invokerPlan or now<(u._interruptNext or -1)or u==b and now<(b._ohaAbilityOrderAt or -999)+.25 then return false end
 local allies=u:GetNearbyHeroes(1300,false,BOT_MODE_NONE)or{};local enemies=u:GetNearbyHeroes(1500,true,BOT_MODE_NONE)or{}
 local choice,score
 for _,e in ipairs(enemies)do if V(e)and e:CanBeSeen()and not Fu.IsSuspiciousIllusion(e)and e:IsChanneling()then
  local active=e:GetCurrentActiveAbility();local n=Name(active);local mod=n and channels[n];local supported=n and channels[n]~=nil
  local victim
  for _,a in ipairs(allies)do
   if V(a)and a:GetTeam()==b:GetTeam()and not a:IsIllusion()and not a:IsInvulnerable()
    and ((mod and a:HasModifier(mod))or supported and mod==false and a:WasRecentlyDamagedByHero(e,.8))then victim=a;break end
  end
  local claim=e._ohaInterruptClaim
  if claim and (not V(claim.unit)or now>claim.untilTime)then e._ohaInterruptClaim=nil;claim=nil end
  if victim and(not claim or claim.unit==u)then
   local candidates={}
   if not u:IsSilenced()then for i=0,23 do local a=u:GetAbilityInSlot(i);local name=Name(a);if name and spells[name]then candidates[#candidates+1]={a=a,cfg=spells[name],name=name,item=false}end end end
   if u==b and not u:IsMuted()then for i=0,5 do local a=u:GetItemInSlot(i);local name=Name(a);if name and items[name]then candidates[#candidates+1]={a=a,cfg=items[name],name=name,item=true}end end end
   for _,v in ipairs(candidates)do local a,cfg=v.a,v.cfg;local kind=Kind(a,cfg[1])
    if kind and not a:IsHidden()and a:IsFullyCastable()and u:GetMana()>=a:GetManaCost()
     and not e:IsInvulnerable()and(not e:IsMagicImmune()or cfg[4])
     and(kind~='entity'or Fu.CanCastOnTargetAdvanced(e))then
     local distance=GetUnitToUnitDistance(u,e);local range=kind=='none'and math.max(a:GetSpecialValueInt('radius'),a:GetAOERadius())or Fu.GetProperCastRange(false,u,a:GetCastRange())
     local delay=a:GetCastPoint()+(cfg[2]or 0)+(cfg[3]and distance/cfg[3]or 0)
     local remaining=mod and require(GetScriptDirectory()..'/FuncLib/systems/control_chain').Remaining(victim)or 4
     if mod and remaining<=0 then local i=victim:GetModifierByName(mod);remaining=i and i>=0 and victim:GetModifierRemainingDuration(i)or 0 end
     local value=200-delay*40-(a:IsUltimate()and 80 or 0)-(v.item and 5 or 0)
     if distance<=math.max(100,range)-15 and (remaining<=0 or delay<remaining-.1)and(not score or value>score)then choice={a=a,target=e,kind=kind,name=v.name};score=value end
    end
   end
  end
 end end
 if not choice then return false end
 choice.target._ohaInterruptClaim={unit=u,untilTime=now+.65};u._interruptNext=now+.3;b._localRescueUntil=now+.8
 if choice.kind=='entity'then u:Action_UseAbilityOnEntity(choice.a,choice.target)
 elseif choice.kind=='point'then u:Action_UseAbilityOnLocation(choice.a,Fu.GetCorrectLoc(choice.target,choice.a:GetCastPoint()+.1))
 else u:Action_UseAbility(choice.a)end
 print('[CHANNEL_RESCUE] t='..now..' pid='..b:GetPlayerID()..' unit='..u:GetUnitName()..' spell='..choice.name..' caster='..choice.target:GetUnitName())
 return true
end
local raw=X.Try;X.Try=function(b,...)
 local ok,v=pcall(raw,b,...);if ok then return v end
 if b and DotaTime()>=(b._channelRescueErrorNext or -1)then b._channelRescueErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=channel_rescue error='..tostring(v))end;return false
end
return X

-- Explicit ordinary damage spells, shared by ALL heroes that own one of them.
-- AOE metadata alone never makes an unknown skill safe to spend on copies.
local X={}
local function Add(names,kind,radius,extra)
 for name in names:gmatch('%S+')do
  local p={kind=kind,radius=radius}
  for k,v in pairs(extra or {})do p[k]=v end
  X[name]=p
 end
end
-- Ground circles; casting must be possible without an approach order.
Add('abyssal_underlord_firestorm','point',350)
Add('alchemist_acid_spray','point',300)
Add('bloodseeker_blood_bath','point',500)
Add('crystal_maiden_crystal_nova','point',350)
Add('dragon_knight_fireball','point',250)
Add('enigma_midnight_pulse','point',350)
Add('kunkka_torrent','point',200)
Add('largo_frogstomp','point',200)
Add('leshrac_split_earth','point',150)
Add('pugna_nether_blast','point',300)
Add('silencer_curse_of_the_silent','point',300)
-- The bot API's GetCurrentCharges is item-only on this build. Do not call it
-- on Shrapnel: use native castability and at most one cluster response per 40s.
Add('sniper_shrapnel','point',350,{minModels=3,reuse=40})
Add('techies_sticky_bomb','point',200)
Add('tiny_avalanche','point',250)
Add('undying_decay','point',250)
Add('viper_nethertoxin','point',300)
Add('tinker_march_of_the_machines','point',300)
-- Narrow corridors. Width is NOT the spell's full travel distance.
Add('beastmaster_wild_axes','line',100)
Add('death_prophet_carrion_swarm','line',100)
Add('dragon_knight_breathe_fire','line',110)
Add('grimstroke_dark_artistry','line',100)
Add('jakiro_dual_breath','line',150)
Add('lina_dragon_slave','line',150)
Add('lion_impale','pointline',100)
Add('magnataur_shockwave','line',130)
Add('monkey_king_boundless_strike','line',110)
Add('nyx_assassin_impale','line',100)
Add('puck_illusory_orb','line',140)
Add('shadow_demon_shadow_poison','line',130)
Add('treant_natures_grasp','line',100)
Add('vengefulspirit_wave_of_terror','line',130)
Add('venomancer_venomous_gale','line',100)
Add('troll_warlord_whirling_axes_ranged','line',100)
-- Self circles. A changed point-target/leap form is rejected at runtime.
Add('brewmaster_thunder_clap','self',350)
Add('bristleback_quill_spray','self',600)
Add('centaur_hoof_stomp','self',300)
Add('gyrocopter_rocket_barrage','self',300)
Add('huskar_inner_fire','self',400)
Add('mirana_starfall','self',600)
Add('necrolyte_death_pulse','self',450)
Add('queenofpain_scream_of_pain','self',450)
Add('razor_plasma_field','self',650)
Add('shredder_whirling_death','self',300)
Add('slardar_slithereen_crush','self',300)
Add('storm_spirit_static_remnant','selfpoint',220)
Add('tidehunter_anchor_smash','self',330)
Add('troll_warlord_whirling_axes_melee','self',400)
Add('void_spirit_resonant_pulse','self',400)
Add('phantom_assassin_fan_of_knives','self',450)
-- Splash/bounce skills; entity targeting needs a legal, reachable primary.
Add('disruptor_thunder_strike','entity',200)
Add('hoodwink_acorn_shot','entity',350)
Add('leshrac_lightning_storm','entity',350)
Add('lich_frost_nova','entity',250)
Add('medusa_mystic_snake','entity',350)
Add('ogre_magi_ignite','entity',300)
Add('rubick_fade_bolt','entity',350)
Add('sven_storm_bolt','entity',200)
Add('witch_doctor_paralyzing_cask','entity',350)
Add('zuus_arc_lightning','entity',350)
Add('winter_wyvern_splinter_blast','entity',400,{excludePrimary=true})
Add('shadow_shaman_ether_shock','entityline',100)
-- Base single-target versions stay with the original hero AI.
Add('bane_brain_sap','entity',0,{nativeAOE=true})
Add('night_stalker_void','entity',0,{nativeAOE=true})
Add('phantom_lancer_spirit_lance','entity',0,{nativeAOE=true})
-- Invoker only uses an already invoked ordinary spell, never forces invoke.
Add('invoker_deafening_blast','line',110)
Add('legion_commander_overwhelming_odds','selfpoint',400)
Add('mars_gods_rebuke','cone',70,{reach=450,angle=55})
Add('snapfire_scatterblast','cone',70,{reach=700,angle=25})
Add('nevermore_shadowraze1','fixed',200,{offset=200})
Add('nevermore_shadowraze2','fixed',200,{offset=450})
Add('nevermore_shadowraze3','fixed',200,{offset=700})
return X

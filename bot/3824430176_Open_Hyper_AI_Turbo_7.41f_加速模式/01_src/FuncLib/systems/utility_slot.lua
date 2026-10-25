-- Shared tool-slot policy. Never sell items, move boots, or remove key saves.
local X={}
local protected={item_gem=true,item_black_king_bar=true,item_glimmer_cape=true,item_force_staff=true,
 item_hurricane_pike=true,item_aeon_disk=true,item_ghost=true,item_cyclone=true,item_wind_waker=true,
 item_blink=true,item_overwhelming_blink=true,item_swift_blink=true,item_arcane_blink=true,
 item_heart=true,item_satanic=true,item_refresher=true,item_sphere=true,item_lotus_orb=true,
 item_invis_sword=true,item_silver_edge=true,
 item_sheepstick=true,item_abyssal_blade=true,item_disperser=true,
 item_greater_crit=true,item_monkey_king_bar=true,item_butterfly=true,item_radiance=true,
 item_bfury=true,item_rapier=true,item_skadi=true,item_assault=true,item_shivas_guard=true,
 item_manta=true,item_bloodstone=true,item_pipe=true,item_crimson_guard=true,
 item_ultimate_scepter=true,item_ultimate_scepter_2=true}
local disposable={item_branches=true,item_quelling_blade=true,item_bracer=true,item_wraith_band=true,
 item_null_talisman=true,item_infused_raindrop=true,item_magic_stick=true,item_magic_wand=true}
function X.IsProtected(n)
 return protected[n] or n=='item_power_treads' or n=='item_phase_boots' or n=='item_tranquil_boots' or n=='item_arcane_boots'
  or n=='item_guardian_greaves' or n=='item_boots_of_bearing' or string.find(n,'boots',1,true)~=nil
end
function X.Select(b,owner,expanded,excluded)
 local slot,price,gear
 for i=0,5 do local h=b:GetItemInSlot(i)
  if not h then return i,nil end
  local n=h:GetName()
  local tool=n=='item_famango' or n=='item_great_famango' or n=='item_greater_famango'
  local boots=n=='item_power_treads' or n=='item_phase_boots' or n=='item_tranquil_boots' or n=='item_arcane_boots'
      or n=='item_guardian_greaves' or n=='item_boots_of_bearing' or string.find(n,'boots',1,true)
  local allowed=disposable[n] or expanded and not protected[n] and not boots
      and not tool and not string.find(n,'recipe',1,true)
  -- Ward management actively equips these slots; do not make them the gem
  -- receiving vacancy. Consumable delivery must not fight the ward manager.
  if owner=='ward'and not disposable[n]then allowed=expanded and not X.IsProtected(n)and not tool and GetItemCost(n)<=1500 and not string.find(n,'recipe',1,true)end
  if owner=='gem' and (n=='item_ward_observer' or n=='item_ward_sentry' or n=='item_ward_dispenser') then allowed=false end
  if owner=='lotus'and not disposable[n]and GetItemCost(n)>1500 then allowed=false end
  if excluded and (excluded[n]or -999)>DotaTime()then allowed=false end
  if allowed then
   local cost=GetItemCost(n)
   -- Prefer cheap early items; expanded policy only when they are absent.
   local value=cost+(disposable[n] and 0 or 100000)
   if not price or value<price then slot,price,gear=i,value,h end
  end
 end
 return slot,gear
end
return X

-- One late optional slot; only visible equipment evidence and completed-item boundaries.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function Have(b,name)return b:FindItemSlot(name)>=0 end
function X.Observe(b)
 if not V(b)or b~=GetBot()or b:IsIllusion()then return end
 local now=DotaTime();local s=b._adaptiveItems or{escape={},regen={},control={}};b._adaptiveItems=s
 if now<(s.next or -1)then return end;s.next=now+2
 for _,e in ipairs(b:GetNearbyHeroes(1600,true,BOT_MODE_NONE)or{})do
  if V(e)and e:CanBeSeen()then
   local id=e:GetPlayerID()
   for i=0,5 do local item=e:GetItemInSlot(i)
    if item then local name=item:GetName()
     if name=='item_ghost'or name=='item_ethereal_blade'or name=='item_cyclone'or name=='item_wind_waker'or name=='item_glimmer_cape'then s.escape[id]=now end
     if name=='item_heart'or name=='item_satanic'or name=='item_bloodstone'then s.regen[id]=now end
     if name=='item_sheepstick'or name=='item_orchid'or name=='item_bloodthorn'or name=='item_abyssal_blade'then s.control[id]=now end
    end
   end
  end
 end
 local function Count(t)local n=0;for id,at in pairs(t)do if now-at>180 then t[id]=nil else n=n+1 end end;return n end
 local escape,regen,control=Count(s.escape),Count(s.regen),Count(s.control)
 local choice
 local physical=b:GetAttackDamage()>=180 and Have(b,'item_black_king_bar')
 if escape>=2 and physical then choice='item_nullifier'
 elseif regen>=2 and physical and b:GetAttackRange()>400 then choice='item_skadi'
 elseif control>=2 and not Have(b,'item_black_king_bar')then choice='item_black_king_bar'end
 if choice~=s.choice then s.choice=choice;s.since=now end
end
function X.Purchase(b,Fu)
 X.Observe(b);local s=b._adaptiveItems;local now=DotaTime()
 if not s or not s.choice or s.applied or now-(s.since or now)<12 or now<720
  or b:GetNetWorth()<9000 or b:GetLevel()<12 or Fu.Role.GetPosition(b)>3
  or b.currBuyingItemInPurchaseList or b.currBuyingBasicItem or #(b.currBuyingBasicItemList or{})>0
  or b:GetStashValue()>0 or b:GetCourierValue()>0 or Have(b,s.choice)then return end
 local q=b.purchaseListInReverseOrder or{};if #q<1 then return end
 -- An already planned counter is advanced, never purchased twice.
 for i=#q,1,-1 do if q[i]==s.choice then
  if i~=#q then table.remove(q,i);q[#q+1]=s.choice end
  s.applied=true;print('[ADAPTIVE_ITEM] t='..now..' phase=planned_counter_advanced item='..s.choice);return
 end end
 local optional={item_moon_shard=true,item_octarine_core=true,item_heart=true,item_skadi=true,
  item_greater_crit=true,item_butterfly=true,item_mjollnir=true,item_bloodthorn=true,item_sheepstick=true}
 if not optional[q[#q]]then return end
 local replaced=q[#q];q[#q]=s.choice;s.applied=true
 print('[ADAPTIVE_ITEM] t='..now..' pid='..b:GetPlayerID()..' phase=late_slot_replaced old='..replaced..' item='..s.choice)
end

for name,fallback in pairs({Observe=function()end,Purchase=function()end})do
 local raw=X[name];X[name]=function(b,...)
  local ok,a,d=pcall(raw,b,...);if ok then return a,d end
  if b and DotaTime()>=(b._adaptive_itemsErrorNext or -1)then
   b._adaptive_itemsErrorNext=DotaTime()+10;print('[EXECUTION_ERROR] module=adaptive_items function='..name..' error='..tostring(a))
  end
  return fallback(b,...)
 end
end
return X

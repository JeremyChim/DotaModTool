local bot=GetBot()
if bot:IsInvulnerable()or not bot:IsHero()or bot:IsIllusion()then return end
local Fu=require(GetScriptDirectory()..'/FuncLib/func_utils')
local W=require(GetScriptDirectory()..'/FuncLib/systems/ward')
local P=require(GetScriptDirectory()..'/FuncLib/systems/ward_plan')
local Inventory=require(GetScriptDirectory()..'/FuncLib/systems/inventory_reservation')
local Emit=require(GetScriptDirectory()..'/FuncLib/systems/log').emit or print
local choice,pending=nil,nil
local WI=require(GetScriptDirectory()..'/FuncLib/systems/ward_inventory')
local nextWard=-math.huge
local function Trace(phase,p)
 Emit(string.format('[WARD_ROUTE] t=%.2f pid=%d phase=%s kind=%s spot=%s distance=%.0f',DotaTime(),bot:GetPlayerID(),phase,p.kind,p.spot.id or'legacy',GetUnitToLocationDistance(bot,p.spot.location)))
end
local function Confirm()
 local result=P.Confirm(pending)
 if result then Trace(result,pending);if result=='placed'then WI.OnPlaced(bot)end;pending=nil;bot._wardRoutePending=nil;Inventory.Release(bot,'ward') end
end
local function Suitable()return WI.Suitable(bot,true)end

function GetDesire()
 if ShouldSkipBotThink(bot)then return 0 end
 WI.Prepare(bot);Confirm();choice=nil
 if DotaTime()<0 and DotaTime()<=(Fu.IsModeTurbo()and -45 or -60)then return BOT_MODE_DESIRE_NONE end
 if bot.itemSwapTime and DotaTime()-bot.itemSwapTime<6.2 then return BOT_MODE_DESIRE_NONE end
 if pending or DotaTime()<nextWard or not Suitable()then return BOT_MODE_DESIRE_NONE end
 for _,kind in ipairs({'obs','sentry'})do
  for i=0,5 do local h=bot:GetItemInSlot(i)
   if P.HasKind(h,kind)then
    local s
    if DotaTime()<0 and kind=='obs'then
     local pool=W.GetAvailabeObserverWardSpots(bot);s=W.GetClosestObserverWardSpot(bot,pool)
    elseif DotaTime()>=0 then
     s=P.Select(bot,h,kind,kind=='sentry'and W.GetPossibleSentryWardSpots(bot)or nil)
    end
    if s then
     choice={spot=s,item=h,kind=kind,at=DotaTime()}
     local desire=DotaTime()<0 and BOT_MODE_DESIRE_ABSOLUTE or BOT_MODE_DESIRE_VERYHIGH
     return desire*math.min(1,math.max(0,Fu.GetHP(bot)*desire))
    end
   end
  end
 end
 return BOT_MODE_DESIRE_NONE
end
function Think()
 if not choice or not Suitable()or not P.HasKind(choice.item,choice.kind)then choice=nil;return end
 if DotaTime()-choice.at>0.5 then choice=nil;return end
 local s,h=choice.spot,choice.item
 local slot
 for i=0,5 do if bot:GetItemInSlot(i)==h then slot=i;break end end
 if not slot or(bot.itemSwapTime and DotaTime()-bot.itemSwapTime<6.2)then choice=nil;return end
 if GetUnitToLocationDistance(bot,s.location)>P.Range(h)-20 then
  if DotaTime()<0 then bot:Action_MoveToLocation(s.location)end
  choice=nil;return
 end
 if DotaTime()>=0 and not P.RouteScore(bot,s,h)then choice=nil;return end
 if P.Near(s.location,choice.kind,choice.kind=='obs'and 900 or 850)then choice=nil;return end
 if not Inventory.Reserve(bot,slot,slot,'ward',1.5)then choice=nil;return end
 if h:GetName()=='item_ward_dispenser'and h:GetToggleState()~=(choice.kind=='obs')then
  bot._wardRoutePending={spot=s,kind=choice.kind,at=DotaTime()};bot:Action_UseAbilityOnEntity(h,bot);choice=nil;return
 end
 bot:Action_UseAbilityOnLocation(h,s.location)
 pending={spot=s,kind=choice.kind,at=DotaTime()};bot._wardRoutePending=pending;Trace('order',pending)
 nextWard=DotaTime()+1.5;choice=nil
end
function OnEnd()choice=nil;if not pending then Inventory.Release(bot,'ward')end end
if SafeCall then GetDesire=SafeCall(GetDesire,0,'WARD_GetDesire');Think=SafeCall(Think,nil,'WARD_Think')end

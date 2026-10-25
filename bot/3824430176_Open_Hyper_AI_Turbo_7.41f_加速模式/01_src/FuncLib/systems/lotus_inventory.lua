-- Conservative lotus use with original desire rules. Never displace critical gear.
local X={}
local Inventory=require(GetScriptDirectory()..'/FuncLib/systems/inventory_reservation')
local Utility=require(GetScriptDirectory()..'/FuncLib/systems/utility_slot')
local values={item_famango=1,item_great_famango=3,item_greater_famango=9}
local disposable={item_branches=true,item_quelling_blade=true,item_bracer=true,item_wraith_band=true,
    item_null_talisman=true,item_infused_raindrop=true,item_magic_stick=true,item_magic_wand=true}
local function Count(b)
    local n=0
    for i=0,8 do local h=b:GetItemInSlot(i)
        if h and values[h:GetName()] then n=n+values[h:GetName()]*math.max(1,h:GetCurrentCharges()) end
    end
    return n
end
local function Log(b,phase,extra)
    print(string.format('[LOTUS_ITEM] t=%.1f pid=%d phase=%s %s',DotaTime(),b:GetPlayerID(),phase,extra or ''))
end
local function Safe(b)
    return b:IsAlive() and not b:IsInvulnerable() and not b:IsChanneling() and not b:IsUsingAbility()
        and not b:IsCastingAbility() and not b:IsStunned() and not b:IsHexed() and not b:IsMuted()
        and b:NumQueuedActions()==0
end
local function SafeSwap(b)
    return Safe(b) and not b:WasRecentlyDamagedByAnyHero(3)
        and #(b:GetNearbyHeroes(1000,true,BOT_MODE_NONE) or {})==0
        and DotaTime()-(b.itemSwapTime or 0)>(b._lotusSlotPin and 0.5 or 11)
end
local function Swap(b,a,c)
    b._lotusOwnSwap=true
    local ok,err=pcall(b.ActionImmediate_SwapItems,b,a,c)
    b._lotusOwnSwap=nil
    if not ok then error(err) end
end
local function ClearPin(b,s) Inventory.Release(b,'lotus');b._lotusSlotPin=nil;s.pending=nil end
local function Signature(b)
 local names={};for i=0,8 do local h=b:GetItemInSlot(i);names[#names+1]=h and h:GetName()or'empty'end
 return table.concat(names,'|')
end
local function Backoff(s,b)
 s.promoteAfter=DotaTime()+45
 if b then s.failedInventory=Signature(b);s.failedHP=b:GetHealth()/math.max(1,b:GetMaxHealth());s.failedMP=b:GetMana()/math.max(1,b:GetMaxMana())end
end
function X.Update(b,consider)
    if DotaTime()<0 then return false end
    Inventory.Observe(b)
    local now=DotaTime();local s=b._lotusInventory or {next=0};b._lotusInventory=s
    if not b:IsAlive() then
        if s.pending then Log(b,'death_transaction_release');ClearPin(b,s) end
        s.use,s.holdUntil,s.restore=nil,nil,nil;return false
    end
    if s.pending and now>=(s.pending.hardDeadline or s.pending.untilTime) then
        local p=s.pending
        if p.gear and b:GetItemInSlot(p.bp)==p.gear then s.restore={main=p.main,bp=p.bp,gear=p.gear,untilTime=now+30} end
        Log(b,'transaction_deadline_release');Backoff(s,b);ClearPin(b,s)
    end
    if s.restore then
        local p=s.restore;local main=b:GetItemInSlot(p.main)
        if now>=p.untilTime or b:GetItemInSlot(p.bp)~=p.gear then s.restore=nil
        elseif not Inventory.Get(b) and SafeSwap(b) and (not main or values[main:GetName()]) then
            Swap(b,p.bp,p.main)
            if b:GetItemInSlot(p.main)==p.gear then Log(b,'deferred_gear_restored');s.restore=nil end
        end
        if s.restore then return false end
    end
    local total=Count(b)
    if s.use and total<s.use.count then
        -- Weighted count preserves automatic 3-to-1 upgrades. This is observed loss after a use order.
        Log(b,'consumption_observed','before='..s.use.count..' after='..total)
        s.use=nil;if not s.pending then Inventory.Release(b,'lotus') end
    elseif s.use and now>s.use.at+8 then Log(b,'use_unconfirmed');s.use=nil end
    if s.holdUntil and now<s.holdUntil then return Safe(b) end
    if now<s.next then return false end;s.next=now+0.25
    if not Safe(b) then return false end
    if total>0 and now>=(s.inventoryDiagNext or 0) then
        s.inventoryDiagNext=now+30
        for slot=0,8 do local h=b:GetItemInSlot(slot)
            if h and values[h:GetName()] then
                local desire=consider[h:GetName()] and consider[h:GetName()](h) or 0
                local pin=Inventory.Get(b)
                Log(b,'inventory_check','item='..h:GetName()..' slot='..slot..' desire='..tostring(desire)
                    ..' ready='..tostring(h:IsFullyCastable())..' reservation='..(pin and pin.owner or 'none'))
            end
        end
    end
    local pending=s.pending
    if pending then
        local main,bp=b:GetItemInSlot(pending.main),b:GetItemInSlot(pending.bp)
        if not pending.gear and not main and not bp then ClearPin(b,s);return false end
        if main==pending.gear and bp and values[bp:GetName()] then
            -- A sub-second reversal is not successful completion: retain the reservation,
            -- diagnose the native/other manager and make at most two safe retries.
            if not pending.restoring and now<pending.untilTime and (pending.retries or 0)<1 then
                if not pending.reversalLogged then
                    if pending.gear then
                        local name=pending.gear:GetName();s.pairFailures=s.pairFailures or{};s.pairFailures[name]=(s.pairFailures[name]or 0)+1
                        if s.pairFailures[name]>=2 then s.excluded=s.excluded or{};s.excluded[name]=now+120 end
                    end
                    Log(b,'slot_reversed_before_use','elapsed='..string.format('%.1f',now-pending.started));pending.reversalLogged=true
                    local slots={}
                    for i=0,8 do local h=b:GetItemInSlot(i);slots[#slots+1]=i..':'..(h and h:GetName() or 'empty') end
                    Log(b,'reversal_inventory','wrapped_swaps='..tostring(b._inventorySwapSequence or 0)..' last_wrapped_at='..tostring(b._inventorySwapAt)..' '..table.concat(slots,','))
                end
                if bp and values[bp:GetName()] and SafeSwap(b) then
                    pending.retries=(pending.retries or 0)+1;pending.readyAt=now+6.2
                    pending.untilTime=pending.hardDeadline or pending.untilTime;b._lotusSlotPin.untilTime=pending.untilTime;Inventory.Renew(b,'lotus',pending.untilTime)
                    Swap(b,pending.bp,pending.main);Log(b,'reserved_slot_retry');s.next=now+0.5
                end
                return false
            end
            Log(b,'gear_restored');ClearPin(b,s)
            if pending.reversalLogged then Backoff(s,b);s.next=now+1 end
            return false
        elseif bp==pending.gear and (not main or values[main:GetName()]) then
            local desire=main and consider[main:GetName()] and consider[main:GetName()](main) or 0
            if not main or now>=pending.untilTime or (now>=pending.readyAt and desire<=0) then
                if SafeSwap(b) then
                    pending.restoring=true;Swap(b,pending.bp,pending.main)
                    if b:GetItemInSlot(pending.main)==pending.gear then
                        Log(b,'gear_restored');ClearPin(b,s);s.next=now+1
                    end
                end
                return false
            end
        else
            -- Another inventory manager changed these slots. Never swap an unrelated new item.
            Log(b,'slots_changed_release');Backoff(s,b);ClearPin(b,s)
        end
    end
    for i=0,5 do local h=b:GetItemInSlot(i)
        if h and values[h:GetName()] and h:IsFullyCastable() and consider[h:GetName()] then
            local desire,target=consider[h:GetName()](h)
            local range=h:GetCastRange()
            local inRange=target==b or target and target:IsAlive() and GetUnitToUnitDistance(b,target)<=math.max(150,range)
            if desire>0 and inRange and not s.use and (not s.pending or now>=s.pending.readyAt)
                and (not s.ready or s.ready.slot~=i or now>=s.ready.at) then
                s.use={count=total,at=now};s.holdUntil=now+0.6;b._lotusUseUntil=s.holdUntil
                local itemName=h:GetName();b:Action_UseAbilityOnEntity(h,target)
                Log(b,'use_order','item='..itemName);return true
            end
        end
    end
    if s.pending or Inventory.Get(b) or now<(s.promoteAfter or -999) or not SafeSwap(b) then return false end
    if s.failedInventory==Signature(b)and math.abs(b:GetHealth()/math.max(1,b:GetMaxHealth())-(s.failedHP or 0))<.15
      and math.abs(b:GetMana()/math.max(1,b:GetMaxMana())-(s.failedMP or 0))<.15 then return false end
    s.failedInventory=nil
    for bp=6,8 do local h=b:GetItemInSlot(bp)
        if h and values[h:GetName()] and consider[h:GetName()] then
            local desire=consider[h:GetName()](h)
            if desire>0 then
                -- Only temporary safe displacement; gear is restored after consumption.
                local main,gear=Utility.Select(b,'lotus',true,s.excluded)
                if main then
                    if not Inventory.Reserve(b,main,bp,'lotus',18) then return false end
                    s.pending={main=main,bp=bp,gear=gear,readyAt=now+6.2,untilTime=now+18,hardDeadline=now+18,started=now}
                    b._lotusSlotPin={main=main,bp=bp,untilTime=now+18}
                    s.ready={slot=main,at=now+6.2};Swap(b,bp,main)
                    if b:GetItemInSlot(main)==h then
                        Log(b,'moved_to_main','slot='..main..' item='..h:GetName());s.next=now+0.5
                    else
                        Log(b,'swap_requested','slot='..main);Inventory.Release(b,'lotus');s.next=now+0.5
                    end
                elseif now>=(s.diagNext or 0) then
                    s.diagNext=now+20;Log(b,'no_safe_slot')
                end
                return false
            end
        end
    end
    return false
end
return X

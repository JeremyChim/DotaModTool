-- One reservation owner per hero; changes are logged, not every frame.
local X={};local pins={}
local function Log(b,phase,extra)
 print(string.format('[INVENTORY_TRACE] t=%.3f pid=%d phase=%s %s',DotaTime(),b:GetPlayerID(),phase,extra or ''))
end
local function Item(h)
 if not h or h:IsNull() then return 'empty' end
 local cd=h.GetCooldownTimeRemaining and h:GetCooldownTimeRemaining() or -1
 return string.format('%s:%s:charges=%d:cd=%.2f:usable=%s',h:GetName(),tostring(h),h:GetCurrentCharges(),cd,tostring(h:IsFullyCastable()))
end
function X.Get(b)
 if not b:IsHero() or b:IsIllusion() or b:HasModifier('modifier_arc_warden_tempest_double')
  or b:HasModifier('modifier_meepo_divided_we_stand') then return nil end
 local p=b._ohaInventoryReservation or pins[b:GetPlayerID()]
 if p and (DotaTime()>=p.untilTime or not b:IsAlive()) then pins[b:GetPlayerID()]=nil;b._ohaInventoryReservation=nil;p=nil end
 return p
end
function X.Reserve(b,main,bp,owner,seconds)
 local existing=X.Get(b);if existing and existing.owner~=owner then return false end
 local p={main=main,bp=bp,owner=owner,untilTime=DotaTime()+seconds,nextTrace=0}
 pins[b:GetPlayerID()]=p;b._ohaInventoryReservation=p
 Log(b,'reserve',string.format('owner=%s main=%d bp=%d',owner,main,bp));return true
end
function X.Release(b,owner)
 local p=X.Get(b);if p and p.owner==owner then pins[b:GetPlayerID()]=nil;b._ohaInventoryReservation=nil;Log(b,'release','owner='..owner) end
end
function X.Renew(b,owner,untilTime)
 local p=X.Get(b);if p and p.owner==owner then p.untilTime=untilTime end
end
function X.Observe(b)
 local p=X.Get(b);if not p or DotaTime()<p.nextTrace then return end;p.nextTrace=DotaTime()+0.25
 local main,bp=b:GetItemInSlot(p.main),b:GetItemInSlot(p.bp)
 local sig=Item(main)..'|'..Item(bp)
 -- Cooldowns are included in a throttled snapshot; handles/charges reveal merges and replacement.
 local identity=tostring(main)..':'..(main and main:GetCurrentCharges() or 0)..'|'..tostring(bp)..':'..(bp and bp:GetCurrentCharges() or 0)
 if identity~=p.identity or DotaTime()>=(p.nextSnapshot or 0) then
  p.identity=identity;p.nextSnapshot=DotaTime()+4
  Log(b,'slots','owner='..p.owner..' main={'..Item(main)..'} bp={'..Item(bp)..'}')
 end
end
function X.BeforeSwap(b,a,c)
 local p=X.Get(b);if not p then return false end
 if a~=p.main and c~=p.main and a~=p.bp and c~=p.bp then return false end
 local own=b._inventorySwapOwner==p.owner or p.owner=='lotus' and b._lotusOwnSwap
 if own then Log(b,'owner_swap','owner='..p.owner..' slots='..a..','..c);return false end
 if DotaTime()>=(p.nextBlocked or 0) then
  p.nextBlocked=DotaTime()+2
  local source=debug and debug.traceback and debug.traceback('',2) or 'unavailable'
  Log(b,'blocked_swap','owner='..p.owner..' slots='..a..','..c..' source='..source:gsub('\n',' > '))
 end
 return true
end
function X.Swap(b,a,c,owner)
 b._inventorySwapOwner=owner;local ok,err=pcall(b.ActionImmediate_SwapItems,b,a,c);b._inventorySwapOwner=nil
 if not ok then error(err) end
end
return X

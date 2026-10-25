local X={}
function X.Block(b,h)
 if not b then return false end
 if DotaTime()>=0 and b._gemPickupUntil and DotaTime()<b._gemPickupUntil and b:IsAlive()
  and b:GetHealth()/math.max(1,b:GetMaxHealth())>=0.25 and b:GetActiveMode()~=BOT_MODE_RETREAT
  and not require(GetScriptDirectory()..'/FuncLib/systems/highground_guard').HasActiveThreat(b) then return true end
 if not b._guardTravel then return false end
 local Guard=require(GetScriptDirectory()..'/FuncLib/systems/highground_guard')
 if not Guard.ProtectReturn(b) then return false end
 return not (h and h.GetName and h:GetName()=='item_tpscroll')
end
return X

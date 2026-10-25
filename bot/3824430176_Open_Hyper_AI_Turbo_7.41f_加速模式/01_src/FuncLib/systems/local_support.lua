-- Only screens optional remote rescues; no new movement or mode desire.
local X={}
local function V(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
local function Log(b,why)
 local now=DotaTime();if now>=(b._supportLogNext or -1)then b._supportLogNext=now+4
  print(string.format('[LOCAL_SUPPORT] t=%.2f pid=%d phase=%s',now,b:GetPlayerID(),why))end
end
local function Deaths(b,now)
 local s=b._supportWatch or{units={},losses={}};b._supportWatch=s
 if now<(s.next or -1)then return s.losses end;s.next=now+.5
 for i=1,5 do local a=GetTeamMember(i)
  if a and not a:IsNull()then local id=a:GetPlayerID();local old=s.units[id]
   if a:IsAlive()then s.units[id]={alive=true,loc=a:GetLocation()}
   elseif old and old.alive then s.losses[#s.losses+1]={at=now,loc=old.loc};old.alive=false end
  end
 end
 while s.losses[1]and now-s.losses[1].at>12 do table.remove(s.losses,1)end
 while #s.losses>8 do table.remove(s.losses,1)end
 return s.losses
end
function X.Allow(b,ally,enemies,allies,Fu)
 if not V(b)or not V(ally)then return true end
 local now=DotaTime();local losses=Deaths(b,now);local dist=GetUnitToUnitDistance(b,ally)
 if dist<1400 or now<600 then return true end
 local fort=GetAncient(b:GetTeam())
 if V(fort)and D(ally:GetLocation(),fort:GetLocation())<2600 then return true end
 local real={};local seen={}
 for _,e in ipairs(enemies or{})do if V(e)and e:CanBeSeen()and not Fu.IsSuspiciousIllusion(e)then
  local id=e:GetPlayerID();if not seen[id]then seen[id]=true;real[#real+1]=e end
 end end
 if #real==0 then return true end
 local arrival=math.max(0,dist-700)/math.max(100,b:GetCurrentMovementSpeed())
 -- A ready, already reachable disable can immediately change the rescue.
 for _,e in ipairs(real)do
  for i=0,7 do local a=b:GetAbilityInSlot(i)
   if a and not a:IsHidden()and a:IsFullyCastable()and a:GetCastRange()>=GetUnitToUnitDistance(b,e)
    and a:GetCastPoint()<.7 and (e:IsChanneling()or e:GetHealth()<b:GetAttackDamage()*2)then return true end
  end
 end
 local helpers=0
 for _,a in ipairs(allies or{})do
  if a~=b and a~=ally and V(a)and a:GetHealth()/math.max(1,a:GetMaxHealth())>.4
   and not a:IsChanneling()and not a:IsStunned()and not a:IsHexed()
   and GetUnitToUnitDistance(a,ally)<1100 then helpers=helpers+1 end
 end
 local samples=b._rescueHealth or{};b._rescueHealth=samples
 local key=ally:GetPlayerID();local old=samples[key];local hp=ally:GetHealth()
 if not old or now-old.at>=.6 then
  local loss=old and now-old.at<=2 and math.max(0,(old.hp-hp)/math.max(.1,now-old.at))or 0
  samples[key]={at=now,hp=hp,loss=loss};old=samples[key]
 end
 if helpers>=#real then return true end
 local recent=0
 for _,loss in ipairs(losses)do if loss.loc and D(loss.loc,ally:GetLocation())<1400 then recent=recent+1 end end
 if recent>=2 and arrival>3 and helpers+1<#real then Log(b,'failed_fight_no_arrived_support');return false end
 if arrival>3 and old and old.loss>hp/math.max(1,arrival-.5)and hp/ally:GetMaxHealth()<.45 then
  Log(b,'rescue_arrives_too_late');return false end
 if arrival>4 and helpers+2<#real and ally:GetHealth()/ally:GetMaxHealth()<.55 then
  Log(b,'remote_rescue_without_support');return false end
 return true
end
local Raw=X.Allow
function X.Allow(b,...)
 local ok,result=pcall(Raw,b,...)
 if ok then return result end
 if b and DotaTime()>=(b._supportErrorNext or -1)then b._supportErrorNext=DotaTime()+10;print('[LOCAL_SUPPORT_ERROR] '..tostring(result))end
 return true
end
return X

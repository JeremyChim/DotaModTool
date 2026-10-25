-- A bounded exit from repeated visible wall-copy contact, never a team task.
local X={}
local function Valid(u)return u and not u:IsNull()and u:IsAlive()end
local function D(a,b)local x,y=a.x-b.x,a.y-b.y;return math.sqrt(x*x+y*y)end
function X.Goal(b,target,safe)
 local now=DotaTime();local here=b:GetLocation();local st=b._wallExit
 if st and now<(st.untilTime or -1)and st.goal and D(here,st.goal)>75 and safe(b,st.goal)then return st.goal end
 if not Valid(target)or not target:CanBeSeen()then return nil end
 if not st or now-st.seen>1.5 then st={started=now,anchor=here,hp=b:GetHealth()};b._wallExit=st end
 st.seen=now
 if now<(st.next or -1)then return nil end
 -- Give cheap defensive attacks a chance; an exit needs sustained contact.
 if now-st.started<1.8 or D(here,st.anchor)>480 then
  if D(here,st.anchor)>480 then st.started=now;st.anchor=here end
  return nil
 end
 if target:GetHealth()<b:GetAttackDamage()*1.2 and b:GetHealth()/math.max(1,b:GetMaxHealth())>.4 then return nil end
 local home=GetAncient(b:GetTeam());if not Valid(home)then return nil end
 local old=b._originalMove
 local axis=old and now-old.at<5 and old.loc or home:GetLocation()
 local dx,dy=axis.x-here.x,axis.y-here.y;local n=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/n,dy/n
 local enemy=target:GetLocation();local current=D(here,enemy);local best,score
 for _,angle in ipairs({0,45,-45,90,-90,135,-135,180})do
  local r=angle*math.pi/180;local x,y=dx*math.cos(r)-dy*math.sin(r),dx*math.sin(r)+dy*math.cos(r)
  local p=Vector(here.x+x*320,here.y+y*320,here.z)
  if safe(b,p)and D(p,enemy)>current+100 then
   local value=D(p,enemy)-D(p,axis)*.25
   if not score or value>score then best,score=p,value end
  end
 end
 if not best then st.next=now+.5;return nil end
 st.goal=best;st.untilTime=now+2.2;st.next=now+2.5;st.started=now;st.anchor=here
 print(string.format('[WALL_EXIT] t=%.2f pid=%d x=%.0f y=%.0f',now,b:GetPlayerID(),best.x,best.y))
 return best
end
function X.Active(b,safe)
 local s=b._wallExit
 if s and DotaTime()<(s.untilTime or -1)and s.goal and D(b:GetLocation(),s.goal)>75 and safe(b,s.goal)then return s.goal end
 return nil
end
return X

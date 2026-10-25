-- Bounded novelty inside the existing position/ban/weak-hero policy.
local X={};local ok,data=pcall(require,GetScriptDirectory()..'/FuncLib/data/draft_history')
if not ok or type(data)~='table'then data={counts={}}end
local counts=type(data.counts)=='table'and data.counts or{}
function X.Count(name)return math.max(0,tonumber(counts[name])or 0)end
function X.PoolWeight(name,weight)
 return weight+math.max(0,12-X.Count(name)*3)
end
function X.Select(scored)
 if not scored or #scored==0 then return nil end
 local best=scored[1].score;local margin=math.max(.8,math.abs(best)*.3)
 -- Never narrow the original top-five opportunity set.
 if scored[5]then margin=math.max(margin,best-scored[5].score)end
 local candidates={};local total=0
 for i,c in ipairs(scored)do
  if i>12 or c.score<best-margin then break end
  -- Preserve meaningful counter scores; no negative-score multiplication.
  local quality=math.exp(math.max(-4,(c.score-best)/math.max(.5,margin)))
  local novelty=1/math.sqrt(1+X.Count(c.name))
  local w=quality*novelty;candidates[#candidates+1]={name=c.name,w=w};total=total+w
 end
 local roll=RandomFloat(0,total)
 for _,c in ipairs(candidates)do roll=roll-c.w;if roll<=0 then return c.name end end
 return candidates[#candidates].name
end
function X.Explore(pool,canPick)
 local list,total={},0
 for _,name in ipairs(pool or{})do if canPick(name)then
  local w=1/math.sqrt(1+X.Count(name));list[#list+1]={name=name,w=w};total=total+w
 end end
 if total==0 then return nil end
 local roll=RandomFloat(0,total)
 for _,c in ipairs(list)do roll=roll-c.w;if roll<=0 then return c.name end end
 return list[#list].name
end
return X

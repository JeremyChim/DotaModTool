-- Bounded diagnostics for callbacks. Normal execution and return values are untouched.
local X={};local nextLog={}
local function Text(value)
 local ok,s=pcall(tostring,value);return ok and s or '<unprintable error>'
end
local function Trace(err)
 local message=Text(err)
 if debug and type(debug.traceback)=='function' then
  local ok,s=pcall(debug.traceback,message,2);if ok then return s end
 end
 return message
end
function X.Report(label,err)
 -- Reporting must not replace the original failure with an error in error handling.
 pcall(function()
  local now=DotaTime();if now<(nextLog[label] or -999) then return end
  nextLog[label]=now+10
  print('[OHA_RUNTIME] t='..Text(now)..' callback='..Text(label)..' error='..Text(err))
 end)
end
function X.Wrap(fn,label,fallback)
 return function(...)
  local args={...};local unpackArgs=table.unpack or unpack
  local ok,a,b,c=xpcall(function() return fn(unpackArgs(args)) end,Trace)
  if ok then return a,b,c end
  X.Report(label,a);return fallback
 end
end
return X

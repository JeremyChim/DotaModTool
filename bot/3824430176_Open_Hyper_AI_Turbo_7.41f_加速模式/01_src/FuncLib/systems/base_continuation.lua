local B=require(GetScriptDirectory()..'/FuncLib/systems/base_execution')
return {Observe=B.Observe,Try=function(b)B.Observe(b);return false end}

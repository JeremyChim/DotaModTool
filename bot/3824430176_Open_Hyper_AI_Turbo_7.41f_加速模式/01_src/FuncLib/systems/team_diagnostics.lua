-- Read-only roster snapshot. One line per team every ten seconds after 7:00.
local X={};local nextLog={}
function X.Update(bot)
    local now=DotaTime();local team=bot:GetTeam()
    if now<420 or now<(nextLog[team] or 0) then return end
    nextLog[team]=now+10
    local rows={}
    for i=1,5 do
        local b=GetTeamMember(i)
        if b and not b:IsNull() then
            local p=b:GetLocation();local target=b:GetAttackTarget()
            local tasks={}
            if b._earlyLotus and b._earlyLotus.active then tasks[#tasks+1]='lotus' end
            if b._wisdomOnce and b._wisdomOnce.active then tasks[#tasks+1]='wisdom' end
            if b._outpostTask and b._outpostTask.active then tasks[#tasks+1]='outpost:'..tostring(b._outpostTask.phase) end
            if b._hgGuardOrder and not b._hgGuardOrder.done then tasks[#tasks+1]='base_guard' end
            rows[#rows+1]=string.format('pid=%d:%s alive=%s pos=%.0f,%.0f mode=%s task=%s target=%s',
                b:GetPlayerID(),b:GetUnitName(),tostring(b:IsAlive()),p.x,p.y,tostring(b:GetActiveMode()),
                table.concat(tasks,','),target and not target:IsNull() and target:GetUnitName() or 'none')
        end
    end
    print(string.format('[TEAM_ROSTER] t=%.1f team=%d %s',now,team,table.concat(rows,' | ')))
end
return X

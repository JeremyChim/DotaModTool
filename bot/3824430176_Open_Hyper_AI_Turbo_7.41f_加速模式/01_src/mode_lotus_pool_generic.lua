-- Suppress the optional native lotus mode. Scheduled visits execute in TEAM_ROAM,
-- so behavior does not depend on whether the engine loads this newer filename.
function GetDesire() return 0 end
function Think() end

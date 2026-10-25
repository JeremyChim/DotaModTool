-- Curated route-side alternatives for the installed 7.41f map.
-- Guide-inspired areas, not claimed to be exact professional heatmap coordinates.
-- Paired alternatives avoid depending on one conspicuous cliff. No tree cutting.
local X={}
local data={
 {'river_top_entry',-2159,1987, 'river',0},
 {'river_top_flank',-1575,2015, 'river',360},
 {'river_bottom_entry',1067,-2810,'river',0},
 {'river_bottom_flank',2255,-1892,'river',360},
 {'radiant_mid_ramp',-2458,-1210,'defend',360,2},
 {'dire_mid_ramp',3006,-347,'defend',360,3},
 {'radiant_triangle_entry',-4245,357,'defend',360,2},
 {'dire_triangle_entry',4613,755,'defend',360,3},
 {'radiant_jungle_entry',361,-4027,'defend',360,2},
 {'dire_jungle_entry',1019,3568,'defend',360,3},
 {'top_lane_lotus_route',-6726,3244,'lane',0},
 {'top_lane_flank',-4014,2569,'lane',0},
 {'bottom_lane_approach',5940,-6109,'lane',0},
 {'bottom_lane_flank',3810,-4562,'lane',0},
 {'top_gate_route',-7490,4741,'gate',0},
 {'top_gate_inside',-6223,5977,'gate',0},
 {'bottom_gate_route',7512,-4630,'gate',0},
 {'bottom_gate_inside',6618,-3122,'gate',0},
 {'radiant_top_t2_approach',-4199,1328,'lane',480},
 {'dire_bottom_t2_approach',4330,-3323,'lane',480},
 {'radiant_bottom_t2_approach',2033,-4917,'lane',480},
 {'dire_top_t2_approach',-2108,4265,'lane',480},
 {'radiant_highground_approach',-3888,-1594,'defend',900,2},
 {'dire_highground_approach',3454,965,'defend',900,3},
}
local spots={}
for _,d in ipairs(data) do spots[#spots+1]={id=d[1],location=Vector(d[2],d[3],0),kind=d[4],start=d[5],team=d[6],plant_time_obs=0,plant_time_sentry=0} end
function X.All()return spots end
function X.Available(team,time)
 local out={};for _,s in ipairs(spots)do if time>=s.start and(not s.team or s.team==team)then out[#out+1]=s end end;return out
end
return X

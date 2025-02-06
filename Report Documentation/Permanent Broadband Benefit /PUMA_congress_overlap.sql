/*
This query comments out the GROUP BY congress_id118 line to get the overlaps between all PUMA's and congressional
districts. The ones where the PUMA-id's end in "-0009" represent the leftovers. 

I distribute those leftovers to congressional districts in a google sheet. 
*/

WITH df as (
	SELECT 
		--identifying info
		hh.state_id, hh.puma10_id, hh.serialno,
		-- eligibility
		MAX(
			CASE WHEN (pop.hins4::text = '1'::text OR 
									hh.fs::text = '1'::text OR
									pop.pap > 0::numeric OR
									pop.ssip > 0::numeric OR 
									pop.povpip <= 200::numeric) 
			THEN 1
			ELSE 0 END) as pbb_eligible,
		--unconnected
		MAX(
			CASE WHEN  hh.accessinet::text = '3'::text OR
						(hh.accessinet::text = '1'::text AND 
						 hh.hispeed::text = '2'::text AND 
						 hh.othsvcex::text = '2'::text AND 
						 (hh.dialup::text = '1'::text OR hh.dialup::text = '2'::text) AND 
						 hh.satellite::text = '2'::text) 
			THEN 1
			ELSE 0 END) AS unconnected,
		MAX(hh.wgtp) as hh_weight
		FROM dl.pums_households_2022 hh
		LEFT JOIN dl.pums_population_2022 pop ON hh.puma10_id::text = pop.puma10_id::text AND hh.serialno::text = pop.serialno::text
		GROUP BY hh.state_id, hh.serialno, hh.puma10_id, 
		hh.accessinet, hh.hispeed, hh.othsvcex, hh.dialup, hh.satellite
), by_puma as (
	SELECT state_id, puma10_id,
	SUM(CASE WHEN pbb_eligible = 1
		THEN hh_weight
		ELSE 0 END) AS hh_eligible, 
	SUM(CASE WHEN unconnected = 1
		THEN hh_weight
		ELSE 0 END) AS hh_unconnected,
	SUM(CASE WHEN pbb_eligible = 1 AND unconnected = 1
		THEN hh_weight
		ELSE 0 END) AS hh_eligible_unconnected
	FROM df
	GROUP BY state_id, puma10_id
)		
SELECT bp.puma10_id, cg.congress_id118,
cg.allocation_factor,
bp.hh_eligible, bp.hh_unconnected, bp.hh_eligible_unconnected

--SUM(bp.hh_eligible*cg.allocation_factor) as hh_criteria,
--SUM(bp.hh_unconnected*cg.allocation_factor) as hh_unconnected,
--SUM(bp.hh_eligible_unconnected*cg.allocation_factor) as hh_pbb_eligible

FROM by_puma bp
LEFT JOIN dl.crosswalk_puma_congress118_geocorr cg ON cg.puma_id = bp.puma10_id
--GROUP BY cg.congress_id118
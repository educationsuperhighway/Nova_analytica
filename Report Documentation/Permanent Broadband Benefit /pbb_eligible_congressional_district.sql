/*
This query gives PBB eligibility by congressional district. However, the totals are off due to some of the PUMA's 
not translating to any congressional district (this is an idiosyncracy of the 2018-2022 5 year average using two sets
of PUMA boundaries). So the final totals add on the "missing" households from the PUMA labelled XX-0009, distributed
proportional to their PBB eligible populations.
*/

WITH df as (
	SELECT 
		--identifying info
		--NOTE: using puma 2010 ID's to match crosswalk file
		hh.state_id, hh.puma10_id, hh.serialno, cg.congress_id118 as district,
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
		MAX(hh.wgtp)*MAX(cg.allocation_factor) as hh_weight
		FROM dl.pums_households_2022 hh
		LEFT JOIN dl.pums_population_2022 pop ON hh.puma10_id::text = pop.puma10_id::text AND hh.serialno::text = pop.serialno::text
		INNER JOIN dl.crosswalk_puma_congress118_geocorr cg ON cg.puma_id = hh.puma10_id
		GROUP BY hh.state_id, hh.serialno, hh.puma10_id, cg.congress_id118,
			hh.accessinet, hh.hispeed, hh.othsvcex, hh.dialup, hh.satellite
)		
SELECT state_id, district,
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
GROUP BY state_id, district
ORDER BY state_id, district
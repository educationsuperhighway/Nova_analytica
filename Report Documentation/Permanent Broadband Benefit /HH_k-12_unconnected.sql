WITH df as (
	SELECT 
		--identifying info
		hh.state_id, hh.puma20_id, hh.serialno,

		--unconnected
		MAX(
			CASE WHEN  hh.accessinet::text = '3'::text OR
						(hh.accessinet::text = '1'::text AND 
						 hh.hispeed::text = '2'::text AND 
						 hh.othsvcex::text = '2'::text AND 
						 (hh.dialup::text = '2'::text OR hh.dialup::text = '1'::text) AND 
						 hh.satellite::text = '2'::text) 
			THEN 1
			ELSE 0 END) AS unconnected,
		--K-12 present. EDIT: Removing '01' since that's pre-k. '02' thru '14' aligns with K-12
		MAX(CASE WHEN pop.schg IN ('02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '14') THEN 1 ELSE 0 END) AS k12_present,
		MAX(hh.wgtp) as hh_weight
		FROM dl.pums_households_2022 hh
		LEFT JOIN dl.pums_population_2022 pop ON hh.puma20_id::text = pop.puma20_id::text AND hh.serialno::text = pop.serialno::text
		GROUP BY hh.state_id, hh.serialno, hh.puma20_id, 
		hh.accessinet, hh.hispeed, hh.othsvcex, hh.dialup, hh.satellite
)		
SELECT
SUM(hh_weight) as households,
SUM(CASE WHEN unconnected = 1
	THEN hh_weight
	ELSE 0 END) AS hh_unconnected, 
SUM(CASE WHEN k12_present = 1
	THEN hh_weight
	ELSE 0 END) AS hh_k12_present, 
SUM(CASE WHEN unconnected = 1 AND  k12_present = 1
	THEN hh_weight
	ELSE 0 END) AS k12_present_no_internet,
SUM(CASE WHEN unconnected = 1 AND  k12_present = 1
	THEN hh_weight
	ELSE 0 END) / SUM(hh_weight) as pct_k12_no_internet	
FROM df
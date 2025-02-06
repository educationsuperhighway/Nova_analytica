--Query to estimate the number of households in various demographics that would no longer be eligible if 
--the FPL level were decreased to 135%

WITH df as (
	SELECT 
		--identifying info
		--NOTE: using puma 2010 ID's to match crosswalk file
		hh.state_id, hh.puma20_id, hh.serialno, 
		--poverty level as % of FPL
		MAX(pop.povpip) as pov,
		-- eligibility
		MAX(
			CASE WHEN (pop.hins4::text = '1'::text OR 
									hh.fs::text = '1'::text OR
									pop.pap > 0::numeric OR
									pop.ssip > 0::numeric OR 
									pop.povpip <= 200::numeric) 
			THEN 1
			ELSE 0 END) as pbb_eligible,
		-- Households who would be made ineligible by changing the eligibility criterion from 200 to 135
		-- so pov level is in that range (136 - 200) and they DO NOT meet any other eligibility criteria
		MAX(
			CASE WHEN (pop.hins4::text != '1'::text AND 
									hh.fs::text != '1'::text AND
									pop.pap = 0::numeric AND
									pop.ssip = 0::numeric AND
									pop.povpip BETWEEN 136::numeric AND 200::numeric) 
			THEN 1
			ELSE 0 END) as gap,
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
		--demographic info
		--veteran
		MAX(CASE WHEN pop.vps IN ('01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '14')
		   THEN 1
		   ELSE 0 END) as veteran,
		--senior
		MAX(CASE WHEN hh.r65 IN ('1','2')
			THEN 1
			ELSE 0 END) as senior,
		--black
		MAX(CASE WHEN pop.racblk = '1' 
		   THEN 1
		   ELSE 0 END) as black,
		--latinx
		MAX(CASE WHEN pop.hisp IN ('02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24'
		)THEN 1	
		   ELSE 0 END) as latinx,
		MAX(hh.wgtp) as hh_weight
		FROM dl.pums_households_2022 hh
		LEFT JOIN dl.pums_population_2022 pop ON hh.puma20_id::text = pop.puma20_id::text AND hh.serialno::text = pop.serialno::text
		--limiting to the households between 135% and 200% FPL to investigate demographics
		WHERE hh.wgtp > 0 
		GROUP BY hh.state_id, hh.serialno, hh.puma20_id,hh.accessinet, 
		hh.hispeed, hh.othsvcex, hh.dialup, hh.satellite
		)

SELECT 
--totals
SUM(hh_weight) AS hh_eligible, 
SUM(hh_weight) FILTER (WHERE gap = 1) as elligible_gap,
--veterans
SUM(hh_weight) FILTER (WHERE veteran = 1) as veterans,
SUM(hh_weight) FILTER (WHERE veteran = 1 AND gap = 1) as veteran_gap,
--seniors
SUM(hh_weight) FILTER (WHERE senior = 1) as senior,
SUM(hh_weight) FILTER (WHERE senior = 1 AND gap = 1) as senior_gap,
--black
SUM(hh_weight) FILTER (WHERE black = 1) as black,
SUM(hh_weight) FILTER (WHERE black = 1 AND gap = 1) as black_gap,
--latinx
SUM(hh_weight) FILTER (WHERE latinx = 1) as latinx,
SUM(hh_weight) FILTER (WHERE latinx = 1 AND gap=1) as latinx_gap

FROM df 
WHERE pbb_eligible = 1 and unconnected = 1

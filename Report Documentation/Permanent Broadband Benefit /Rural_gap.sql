--Query to estimate the number of Rural households that are eligible for PBB and the number of rural households 
--that would no longer be eligible for PBB if the FPL level were decreased to 135%
--NOTE: query took 33 minutes to run

--First temp table uses two crosswalk tables to get the % of each puma that is rural
WITH rural_pumas AS (
	SELECT  z.puma_id,  
    --AF from zip_urbanrural is the % of the zip code that is rural.
    --AF from puma_zip is the % of the puma that is in the zip code.
    --multiplying the two AF's and summing them by puma gives the % of each puma that is rural
		SUM(z.allocation_factor*ur.allocation_factor) as pct_rural
	FROM dl.crosswalk_puma_zip_geocorr z 
	JOIN dl.crosswalk_zip_urbanrural_geocorr ur ON z.zipcode = ur.zip AND ur.urban_rural_code = 'R'
	GROUP BY z.puma_id
	),

--Second temp table is get PBB and demographic info
df as (
	SELECT 
		--identifying info
		hh.state_id, hh.puma10_id, hh.serialno, 
		--poverty level category
		MAX(CASE WHEN pop.povpip < 135 
				THEN 1
				WHEN pop.povpip BETWEEN 135 AND 200 
				THEN 2
				WHEN pop.povpip > 200
				THEN 3
				ELSE 0 END) as pov_level,
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
		MAX(hh.wgtp) as hh_weight
	FROM dl.pums_households_2022 hh
	LEFT JOIN dl.pums_population_2022 pop ON hh.puma10_id::text = pop.puma10_id::text AND hh.serialno::text = pop.serialno::text
	--Bringing in zip code
	LEFT JOIN dl.crosswalk_puma_zip_geocorr z ON hh.puma10_id = z.puma_id

	WHERE hh.wgtp > 0 
	GROUP BY hh.state_id, hh.serialno, hh.puma10_id,
			hh.accessinet, hh.hispeed, hh.othsvcex, hh.dialup, hh.satellite
	)

SELECT 
--including overall numbers to make sure everything checks out. Got 16.3M PBB eligible unconnected (as expected)
SUM(df.hh_weight) FILTER (WHERE df.pbb_eligible = 1 AND df.unconnected = 1) as hh_eligible,
SUM(df.hh_weight) FILTER (WHERE df.gap = 1 AND unconnected = 1) as hh_gap,
--to get the number of rural households eligible, apply the percent rural by puma to the household weight
SUM(df.hh_weight*rp.pct_rural) FILTER (WHERE df.pbb_eligible = 1 AND df.unconnected = 1) as rural_eligible,
SUM(df.hh_weight*rp.pct_rural) FILTER (WHERE df.gap = 1 AND unconnected = 1) as rural_eligible_delta

FROM df 
LEFT JOIN rural_pumas rp ON df.puma10_id = rp.puma_id

/*
This query is meant to find the average number of poviders per PBB Eligible Household
The challenge is that we don't exactly know which households in the fabric are PBB Eligible, 
so my strategy is to find the average number of providers in each census tract, then take the 
weighted average with weights coming from the number of PBB eligible households are in that census tract.

the 'df' table finds the number of PBB eligible households by census tract. Since this analysis is about
people claiming PBB eligibility despite already being connected, I did not apply the unconnected variable
that we normally would have.

the 'locations' table takes the average number of wired connections available to a location, grouped by
census tract. 

I calculated the weighted average in a google sheet and got 1.45 providers. 

This query took 55 minutes to run.
*/
WITH df as (
		SELECT 
		--identifying info
		--NOTE: using puma 2020 ID's to match crosswalk file
		hh.state_id, hh.puma20_id, hh.serialno, cg.tract_id as tract,
		-- eligibility
		MAX(
			CASE WHEN (pop.hins4::text = '1'::text OR 
									hh.fs::text = '1'::text OR
									pop.pap > 0::numeric OR
									pop.ssip > 0::numeric OR 
									pop.povpip <= 200::numeric) 
			THEN 1
			ELSE 0 END) as pbb_eligible,
		--not limiting this to unconnected, so I took out that variable

		MAX(hh.wgtp)*MAX(cg.allocation_factor) as hh_weight
		FROM dl.pums_households_2022 hh
		LEFT JOIN dl.pums_population_2022 pop ON hh.puma20_id::text = pop.puma20_id::text AND hh.serialno::text = pop.serialno::text
		--joining in new crosswalk table puma to tract
		INNER JOIN dl.crosswalk_puma_tract_geocorr cg ON cg.puma22_id = hh.puma10_id
		--keeping all the same groupings we usually use because it threw things off when I only grouped by tract_id
		GROUP BY hh.state_id, hh.serialno, hh.puma20_id, cg.tract_id,
			hh.accessinet, hh.hispeed, hh.othsvcex, hh.dialup, hh.satellite
), 
locations as (
	SELECT LEFT(block_fips, 11) as tract_id,
	--number of wired plans available (copper, coax, or fiber) above 100/20 per location
	SUM(served_by_copper_100_20 + served_by_coaxcable_100_20 + served_by_fiber_100_20) / COUNT(location_id) as providers_per_location

	FROM ps.fcc_location_metrics_v4fabric

	GROUP BY LEFT(block_fips, 11)
)

SELECT df.tract, 
	SUM(df.hh_weight) as households, 
	MAX(l.providers_per_location) as ppl

FROM df
INNER JOIN locations l ON df.tract = l.tract_id

GROUP BY df.tract
ORDER BY df.tract
/*Popis projektu:
Pri tvoren� scriptu som vych�dzala z tabuliek: countries, economies, life_expectancy, religions, covid19_basic_differences, 
covid19_testing, weather, lookup_table.
Okrem po�adovan�ch premenn�ch som vytvorila premenn� Po�et pr�padov na milion obyvatelov (Cases_per_milion) a Pomer pozit�vnych
 pr�padov na celkov�m po�tu testov (Positivity_rate).
Pri napojovan� tabuliek som zistila, �e v tabu�ke Covid19_tests maj� niektor� krajiny (France, Japan, Poland, Singapore, USA) 
uveden� 2 Entity (napr. people_tested, tests_performed,..),
ponechala som s�ce obe kateg�rie, ale optim�lne by bolo zmeni� tabu�ku a vybra� len jednu entitu.
Pri ur�ovan� som rozli�ovala �tyri ro�n� obdobia, 0-zima, 1-jar, 2-l�to, 3-jese�, do �vahy som brala, o ktor� pologu�u 
sa jedn�. Krajin�m na rovn�ku som nechala len ro�n� obdobie leto. 
Pri napojov�n� tabu�ky Countries som zistila, �e Northern Ireland je bran� ako samostatn� krajina s rovnak�m iso3 ako United Kingdom, 
tak som ho vyl��ila.
Pri parametri GINI som nevych�dzala z �daju len z jedn�ho jedn�ho roku, ale po��tala som ho ako priemer z rokov 2010-2019. Je to z toho 
d�vodu, �e ka�d� krajina m� �daj z r�znych rokov a keby som vych�dzala len z jedn�ho roku, ve�a kraj�n by tento �daj nemalo. Ke�e sa GINI 
dramaticky nemen� za tieto roky,je mo�n� pou�i� priemer.
Pri ur�ovan� priemernej dennej teploty som vych�dzala zo vzorcu pou�ivan�ho v meteorol�gii, teda (t7+t14+2*t21)/4. Ke�e sme nemali 
�daje presne k t�mto �asov�m hodnot�m, pou�ila som �as o 6 a 15 hod. */




Create or replace table t_lucia_madlova_final_SQL as
SELECT cbd.date, cbd.country, cbd.confirmed , ct.tests_performed, 
		round(cbd.confirmed/c.population *1000000,1) as cases_per_milion, 
		round(cbd.confirmed/ct.tests_performed*100,1) as positivity_rate,
		CASE when weekday(cbd.date) in (5,6) then 1 else 0 end as Weekend,
		CASE when c.south>0  then CASE when DAYOFYEAR(cbd.date)<81 or DAYOFYEAR(cbd.date)>357 then 0
								when DAYOFYEAR(cbd.date)<173 then 1
								when DAYOFYEAR(cbd.date)<267 then 2
								else 3 end
			when c.north <0 then CASE when DAYOFYEAR(cbd.date)<81 or DAYOFYEAR(cbd.date)>357 then 2
								when DAYOFYEAR(cbd.date)<173 then 3
								when DAYOFYEAR(cbd.date)<267 then 0
								else 2 end
			else 1 end as season,
		round(c.population_density,1) as population_density,
		ROUND(e.GDP/e.population,1) as GDP_per_capita_2019,
		round(e2.gini,1) as GINI,
		c.median_age_2018,
		e.mortaliy_under5,
		tlmr.Buddhism, tlmr.Christianity, tlmr.Folk_Religions, tlmr.Hinduism, tlmr.Islam, tlmr.Judaism, tlmr.Other_Religions,
		tlmr.Unaffiliated_Religions,
		round(le2015.life_expectancy - le1965.life_expectancy, 1) as life_expect_diff,
		w_avg.avg_day_temp,
		w_nzr.no_rain_hrs,
		w_mw.max_gust
FROM covid19_basic_differences cbd
JOIN lookup_table lt 
	ON cbd.country = lt.country and lt.province is null
left JOIN covid19_tests ct 
	ON lt.iso3 = ct.iso
	and cbd.date=ct.date
left JOIN countries c
	ON lt.iso3 = c.iso3 and c.country!='Northern Ireland'
LEFT JOIN economies e 
	ON c.country = e.country 
	AND e.year=2019 
LEFT JOIN (SELECT country, avg(gini)as gini from economies e2 where year between 2010 and 2019 group by country) as e2
	ON c.country = e2.country
LEFT JOIN (SELECT country, life_expectancy from life_expectancy le where year=1965) as le1965
	ON c.country = le1965.country
LEFT JOIN (SELECT country, life_expectancy from life_expectancy le where year=2015) as le2015
	ON c.country = le2015.country
LEFT JOIN 
	(SELECT r.country, 
		round(r2.population/sum(r.population)*100,1) as Buddhism,
	 round(r3.population/sum(r.population)*100,1) as Christianity
	,round(r4.population/sum(r.population)*100,1) as Folk_Religions,
	round(r5.population/sum(r.population)*100,1) as Hinduism,
	round(r6.population/sum(r.population)*100,1) as Islam,
	round(r7.population/sum(r.population)*100,1) as Judaism,
	round(r8.population/sum(r.population)*100,1) as Other_Religions,
	round(r9.population/sum(r.population)*100,1) as Unaffiliated_Religions
	FROM religions r 
	JOIN (SELECT country, population from religions where religion='Buddhism'and year=2020) r2 ON r.country = r2.country
	JOIN (SELECT country, population from religions where religion='Christianity'and year=2020) r3 ON r.country = r3.country
	JOIN (SELECT population, country from religions where religion='Folk Religions'and year=2020) r4 ON r.country = r4.country
	JOIN (SELECT population, country from religions where religion='Hinduism'and year=2020) r5 ON r.country = r5.country
	JOIN (SELECT population, country from religions where religion='Islam'and year=2020) r6 ON r.country = r6.country
	JOIN (SELECT population, country from religions where religion='Judaism'and year=2020) r7 ON r.country = r7.country
	JOIN (SELECT population, country from religions where religion='Other Religions'and year=2020) r8 ON r.country = r8.country
	JOIN (SELECT population, country from religions where religion='Unaffiliated Religions'and year=2020) r9 ON r.country = r9.country
	WHERE r.year=2020
	and r.country != 'All Countries'
	Group by country
	HAVING sum(r.population )>0) as tlmr 
	ON c.country=tlmr.country
LEFT JOIN (SELECT city, date, COUNT(rain) * 3 AS no_rain_hrs FROM weather WHERE rain != 0 AND YEAR(DATE) >= 2020 GROUP BY date, city) w_nzr
  		 ON cbd.date = w_nzr.date and c.capital_city = w_nzr.city
LEFT JOIN (SELECT city, date, MAX(gust) AS max_gust FROM weather WHERE YEAR(DATE) >= 2020 GROUP BY city, DATE) w_mw 
	ON cbd.date = w_mw.date and c.capital_city = w_mw.city
LEFT JOIN (SELECT city, date, ROUND(SUM(temp) / 4, 1) as avg_day_temp FROM 
			(SELECT city, date, temp FROM weather w WHERE YEAR(date) >= 2020 AND w.hour = 6
            UNION ALL
            SELECT city, date, temp FROM weather w WHERE YEAR(date) >= 2020 AND w.hour = 15
            UNION ALL
            SELECT city, date, 2 * temp FROM weather w WHERE YEAR(date) >= 2020 AND w.hour = 21) w
      		GROUP BY w.city, w.date) w_avg
      ON  cbd.date = w_avg.date and c.capital_city = w_avg.city;
	
   

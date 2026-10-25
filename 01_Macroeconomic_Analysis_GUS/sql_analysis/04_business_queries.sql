-- Biznesowy problem: Inwestor chce wiedzieć, w których powiatach ludzie zarabiają najwięcej, a w których najmniej, ale interesują go tylko najświeższe dane (zakładam, że rok 2024, ale użyj najnowszego, dla jakiego masz dane o wynagrodzeniach).
-- Business problem: An investor wants to know in which counties people earn the most and the least, but only for the most recent data (2024 assumed, otherwise the latest year with salary data).

with latest_salaries as (
	select
    	du.name AS nazwa_powiatu,
        fei.salary_value as wynagrodzenia,
        fei.population_value as ludnosc
	from fact_economic_indicators as fei
	join dim_units as du on du.id = fei.id_units
	join dim_year as dy on dy.year = fei.year
	where dy.year = 2023
)

select  
    nazwa_powiatu as "Nazwa Powiatu",
    wynagrodzenia as "Średnie wynagrodzenie",
    ludnosc as "Liczba ludności"
from latest_salaries
order by wynagrodzenia desc
limit 10;


-- Biznesowy problem: Liczba bezrobotnych sama w sobie niewiele nam mówi (np. Kraków na pewno ma więcej bezrobotnych niż mała wieś, bo po prostu ma więcej mieszkańców). Aby to miarodajnie porównać, musimy obliczyć "Wskaźnik bezrobocia" (ile % całej ludności stanowią bezrobotni).
-- Business problem: The raw number of unemployed people says little on its own (e.g. Kraków will always have more unemployed than a small village simply because it has more residents). To compare fairly, we need an "unemployment rate" (what % of the total population is unemployed).

WITH unemployment_rate AS (
  SELECT
    du.name AS nazwa_powiatu,
    dy.year,
    fei.population_value as ludnosc,
    fei.unemployment_value as bezrobocie,
    ROUND((CAST(fei.unemployment_value AS numeric) / CAST(fei.population_value AS numeric)) * 100, 2) AS wskaznik_bezrobocia_procent
  FROM fact_economic_indicators AS fei
  JOIN dim_units AS du ON du.id = fei.id_units
  JOIN dim_year AS dy ON dy.year = fei.year
)

SELECT * 
FROM unemployment_rate
WHERE year = 2023
ORDER BY wskaznik_bezrobocia_procent DESC;

-- Biznesowy problem: Inwestor chce wiedzieć, jak szybko rosną pensje w powiatach. Sama kwota pensji to za mało – chce wiedzieć, ile wyniosła pensja w 2024 roku, a ile w 2023, i zobaczyć różnicę.
-- Business problem: An investor wants to know how fast salaries are growing in each county. The salary amount alone is not enough - they want to see the salary in the current year versus the previous year and the difference between them.

with salary_yoy as (

    select 
    du.name as nazwa_powiatu,
    dy.year as rok,
    fei.salary_value as pensja_obecna,
    lag(fei.salary_value) over (partition by fei.id_units order by dy.year) as pensja_rok_wczesniej
    from fact_economic_indicators as fei
    join dim_units as du on du.id = fei.id_units
    join dim_year as dy on dy.year = fei.year
    where fei.salary_value is not null
)

select *, pensja_obecna - pensja_rok_wczesniej as wzrost_kwotowy
from salary_yoy
where rok = 2023
;

-- Biznesowy problem: Inwestor nie lubi patrzeć na gołe kwoty wynagrodzeń. Chce mieć prosty dashboard, na którym powiaty są podzielone na 3 segmenty: "Wysokie zarobki", "Średnie zarobki" i "Niskie zarobki", aby łatwiej kierować kampanie marketingowe.
-- Business problem: An investor does not like looking at raw salary figures. They want a simple dashboard that splits counties into 3 segments: "High earnings", "Medium earnings" and "Low earnings" to better target marketing campaigns.

select 
		du.name AS nazwa_powiatu,
		case
			when fei.salary_value > 7000 then 'wysokie'
			when fei.salary_value >= 5000 and fei.salary_value <= 7000 then 'Średnie'
			when fei.salary_value < 5000 and fei.salary_value > 0 then 'Niskie'
		else 
			'Błędne dane'
		end as Zarobki_Gmin,
		round(cast(fei.salary_value as numeric),2) as wynagrodzenia
from fact_economic_indicators fei
join dim_units du on du.id = fei.id_units
;


-- Biznesowy problem: Które powiaty przyciągają najwięcej inwestycji? Biznes chce oficjalnego rankingu (np. 1. miejsce, 2. miejsce, 3. miejsce itd.) dla roku 2023.
-- Business problem: Which counties attract the most investment? The business wants an official ranking (1st place, 2nd place, 3rd place, etc.) for 2023.
with investment_ranking as (
select 
	du.name as nazwa_powiatu,
	dense_rank() over (partition by dy.year order by fei.investment_value desc) as Ranking,
	fei.investment_value as inwestycje,
	dy.year as rok
from fact_economic_indicators fei
join dim_units du on du.id = fei.id_units
join dim_year dy on dy.year = fei.year
)

select * from investment_ranking
where rok = 2023
order by Ranking
;


-- Problem biznesowy:Pandemia roku 2020 była zewnętrznym szokiem ekonomicznym, który dotknął wszystkie powiaty bez wyjątku. Jednak nie wszystkie wyszły z tego kryzysu z jednakową siłą. Z perspektywy funduszu kluczowe jest pytanie: które regiony wykazały się największą odpornością i zdolnością do odbudowy? Powiat, który w 3 lata odrobił straty i zanotował realny salary_growth wynagrodzeń, jest znacznie atrakcyjniejszym celem inwestycyjnym niż ten, który nadal stagnuje.
-- Business problem: The 2020 pandemic was an external economic shock that hit every county without exception, but not all of them recovered with equal strength. For the fund, the key question is: which regions showed the greatest resilience and ability to rebound? A county that recovered its losses within 3 years and achieved real salary growth is a far more attractive investment target than one that is still stagnating.

with salary_2023 as (

select gi.id_units as id_powiatu,
	   gi.salary_value as wynagrodzenia
FROM fact_economic_indicators gi
where gi.year = 2023 and gi.salary_value > 0

), salary_2020 as (

select gi.id_units as id_powiatu,
	   gi.salary_value as wynagrodzenia
from fact_economic_indicators gi
where gi.year = 2020 and gi.salary_value > 0

), salary_growth as (

select salary_2023.id_powiatu,
	dim_units.name as powiat,
	salary_2023.wynagrodzenia as Pensja_2023,
	salary_2020.wynagrodzenia as Pensja_2020,
	round((( cast(salary_2023.wynagrodzenia as numeric) - cast(salary_2020.wynagrodzenia as numeric)) / cast(salary_2020.wynagrodzenia as numeric)) * 100,2) as wzrost_procentowy
from  salary_2023
inner join salary_2020 on salary_2023.id_powiatu = salary_2020.id_powiatu
inner join dim_units on dim_units.id = salary_2023.id_powiatu
)

select 
  powiat,
    pensja_2023,
    pensja_2020,
	CASE
        WHEN wzrost_procentowy > 0 THEN '⬆ ' || wzrost_procentowy::TEXT || '%'
        WHEN wzrost_procentowy < 0 THEN '⬇ '  || wzrost_procentowy::TEXT || '%'
        ELSE '→ 0.00%'
    end AS kpi_trend
from salary_growth
order by wzrost_procentowy desc
;

-- Problem biznesowy: Intuicyjnie zakładamy, że napływ inwestycji do regionu redukuje bezrobocie. Analiza korelacji przeprowadzona na dostępnych danych wskazuje jednak współczynnik +0,37 pomiędzy poziomem inwestycji a liczbą bezrobotnych — czyli kierunek odwrotny do oczekiwanego. Przed podjęciem decyzji inwestycyjnych fundusz wymaga wyjaśnienia tego pozornego paradoksu.
-- Business problem: We intuitively assume that inflowing investment reduces unemployment in a region. However, a correlation analysis on the available data shows a coefficient of +0.37 between investment levels and the number of unemployed - the opposite of what we would expect. Before making investment decisions, the fund needs this apparent paradox explained.

with investment_quartiles as (
select 

	du.name as Powiat,
	fei.unemployment_value as bezrobocie,
	fei.population_value as ludnosc,
	fei.investment_value as inwestycje,
	ntile(4) over (order by fei.investment_value) as koszyk_inwestycyjny
		
from fact_economic_indicators fei
join dim_units du on du.id = fei.id_units
join dim_year dy on dy.year = fei.year

where dy.year = 2024

)

select 
	round((Sum(cast(bezrobocie as numeric)) / sum(cast(ludnosc as numeric))) * 100,2) || '%' as procent_bezrobocia,
	round(AVG(inwestycje::numeric),2) as srednie_inwestycje,
	round(AVG(bezrobocie::numeric),2) as srednie_bezrobocie,
	koszyk_inwestycyjny,
	COUNT(powiat) AS liczba_powiatow
	
from investment_quartiles

group by koszyk_inwestycyjny
order by koszyk_inwestycyjny desc
;


--Problem biznesowy: Inwestycja długoterminowa w region skazany na wyludnienie jest obarczona wysokim ryzykiem — za 10–15 lat może tam brakować zarówno konsumentów, jak i pracowników. Wskaźnik relacji liczby zgonów do liczby urodzeń jest jednym z najlepszych sygnałów wczesnego ostrzegania. Wartość powyżej 1,5 oznacza, że region traci populację w alarmującym tempie.
-- Business problem: A long-term investment in a region facing depopulation carries high risk - in 10-15 years it may lack both consumers and workers. The ratio of deaths to births is one of the best early-warning signals. A value above 1.5 means the region is losing population at an alarming rate.

with demographics as (

select 
	   du.id as id_powiatu,
	   du.name as powiat,
	   dy.year,
	   round(cast(fei.deaths_rate_value as numeric),0) as zgony,
	   ROUND(fei.births_rate_value::numeric, 0) AS urodzenia,
	   round(cast(fei.deaths_rate_value as numeric) / nullif(cast(fei.births_rate_value as numeric),0),2) as wskasnik_demograficzny
from fact_economic_indicators fei
join dim_units du on du.id = fei.id_units
join dim_year dy on dy.year = fei.year

)
select
		powiat,
		wskasnik_demograficzny,
		lag(wskasnik_demograficzny) over (partition by id_powiatu order by year),
		year,
		case 
			when wskasnik_demograficzny > 1.5 then 'Krytyczny'
			when wskasnik_demograficzny > 1.1 and wskasnik_demograficzny <= 1.5 then 'Ostrzegawczy'
		else 'Stabilny'
		end as Metryka
		
from demographics
;

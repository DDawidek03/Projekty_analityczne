-- Biznesowy problem: Inwestor chce wiedzieć, w których powiatach ludzie zarabiają najwięcej, a w których najmniej, ale interesują go tylko najświeższe dane (zakładam, że rok 2024, ale użyj najnowszego, dla jakiego masz dane o wynagrodzeniach).

with dane_2023 as (
	select  
    	gi.name AS nazwa_powiatu, 
        gi.wynagrodzenia, 
        gi.ludnosc
	from gus_indicators as gi
	where gi.year::int = 2023
)

select  
    nazwa_powiatu as "Nazwa Powiatu",
    wynagrodzenia as "Średnie wynagrodzenie",
    ludnosc as "Liczba ludności"
from dane_2023
order by wynagrodzenia desc
limit 10;


-- Biznesowy problem: Liczba bezrobotnych sama w sobie niewiele nam mówi (np. Kraków na pewno ma więcej bezrobotnych niż mała wieś, bo po prostu ma więcej mieszkańców). Aby to miarodajnie porównać, musimy obliczyć "Wskaźnik bezrobocia" (ile % całej ludności stanowią bezrobotni).

WITH stopa_bezrobocia AS (
  SELECT
    gi.name AS nazwa_powiatu,
    gi.year,
    gi.ludnosc,
    gi.bezrobocie,
    ROUND((CAST(gi.bezrobocie AS numeric) / CAST(gi.ludnosc AS numeric)) * 100, 2) AS wskaznik_bezrobocia_procent
  FROM gus_indicators AS gi
)

SELECT * 
FROM stopa_bezrobocia
WHERE year::int = 2023
ORDER BY wskaznik_bezrobocia_procent DESC;

-- Biznesowy problem: Inwestor chce wiedzieć, jak szybko rosną pensje w powiatach. Sama kwota pensji to za mało – chce wiedzieć, ile wyniosła pensja w 2024 roku, a ile w 2023, i zobaczyć różnicę.

with pensje_rok_do_roku as (

    select 
    gi.name as nazwa_powiatu,
    gi.year as rok,
    gi.wynagrodzenia as pensja_obecna,
    lag(gi.wynagrodzenia ) over (partition by gi.name order by gi.year ) as pensja_rok_wczesniej
    from gus_indicators as gi 
    where gi.wynagrodzenia is not null
)

select *, pensja_obecna - pensja_rok_wczesniej as wzrost_kwotowy
from pensje_rok_do_roku
where rok::int = 2023

-- Biznesowy problem: Inwestor nie lubi patrzeć na gołe kwoty wynagrodzeń. Chce mieć prosty dashboard, na którym powiaty są podzielone na 3 segmenty: "Wysokie zarobki", "Średnie zarobki" i "Niskie zarobki", aby łatwiej kierować kampanie marketingowe.

select 
		gi.name AS nazwa_powiatu, 
		case
			when gi.wynagrodzenia > 7000 then 'wysokie'
			when gi.wynagrodzenia >= 5000 and gi.wynagrodzenia <= 7000 then 'Średnie'
			when gi.wynagrodzenia < 5000 and gi.wynagrodzenia > 0 then 'Niskie'
		else 
			'Błędne dane'
		end as Zarobki_Gmin,
		round(cast(gi.wynagrodzenia as numeric),2) as wynagrodzenia
from gus_indicators gi 


-- Biznesowy problem: Które powiaty przyciągają najwięcej inwestycji? Biznes chce oficjalnego rankingu (np. 1. miejsce, 2. miejsce, 3. miejsce itd.) dla roku 2023.
with ranking_inwestycji as (
select 
	gi.name as nazwa_powiatu,
	dense_rank() over (partition by gi."year" order by gi.inwestycje desc ) as Ranking,
	gi.inwestycje  as inwestycje,
	gi."year" as rok
from gus_indicators gi
)

select * from ranking_inwestycji
where rok::int = 2023
order by Ranking


-- Problem biznesowy:Pandemia roku 2020 była zewnętrznym szokiem ekonomicznym, który dotknął wszystkie powiaty bez wyjątku. Jednak nie wszystkie wyszły z tego kryzysu z jednakową siłą. Z perspektywy funduszu kluczowe jest pytanie: które regiony wykazały się największą odpornością i zdolnością do odbudowy? Powiat, który w 3 lata odrobił straty i zanotował realny wzrost wynagrodzeń, jest znacznie atrakcyjniejszym celem inwestycyjnym niż ten, który nadal stagnuje.

with dane_rok_2023 as (

select gi."name" as powiat,
	   gi.wynagrodzenia 
FROM gus_indicators gi 
where gi.year::int = 2023 and gi.wynagrodzenia > 0

), dane_rok_2020 as (

select gi."name" as powiat,
	   gi.wynagrodzenia 
from gus_indicators gi 
where gi.year::int = 2020 and gi.wynagrodzenia > 0

), wzrost as (

select dane_rok_2023.powiat,
	dane_rok_2023.wynagrodzenia as Pensja_2023,
	dane_rok_2020.wynagrodzenia as Pensja_2020,
	round((( cast(dane_rok_2023.wynagrodzenia as numeric) - cast(dane_rok_2020.wynagrodzenia as numeric)) / cast(dane_rok_2020.wynagrodzenia as numeric)) * 100,2) as wzrost_procentowy
from  dane_rok_2023
inner join dane_rok_2020 on dane_rok_2023.powiat = dane_rok_2020.powiat
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
from wzrost
order by wzrost_procentowy desc

-- Problem biznesowy: Intuicyjnie zakładamy, że napływ inwestycji do regionu redukuje bezrobocie. Analiza korelacji przeprowadzona na dostępnych danych wskazuje jednak współczynnik +0,37 pomiędzy poziomem inwestycji a liczbą bezrobotnych — czyli kierunek odwrotny do oczekiwanego. Przed podjęciem decyzji inwestycyjnych fundusz wymaga wyjaśnienia tego pozornego paradoksu.

with kwartalne as (
select 

	gi."name" as Powiat,
	gi.bezrobocie,
	gi.ludnosc,
	gi.inwestycje,
	ntile(4) over (order by gi.inwestycje ) as koszyk_inwestycyjny
		
from gus_indicators gi

where gi."year"::int = 2024

)

select 
	round((Sum(cast(bezrobocie as numeric)) / sum(cast(ludnosc as numeric))) * 100,2) || '%' as procent_bezrobocia,
	round(AVG(inwestycje::numeric),2) as srednie_inwestycje,
	round(AVG(bezrobocie::numeric),2) as srednie_bezrobocie,
	koszyk_inwestycyjny,
	COUNT(powiat) AS liczba_powiatow
	
from kwartalne

group by koszyk_inwestycyjny
order by koszyk_inwestycyjny desc




-- powinno wyjść 380 / 7 / 2660
select
    (select count(*) from dim_units) as powiaty,
    (select count(*) from dim_year) as lata,
    (select count(*) from fact_economic_indicators) as wiersze_faktow;


-- powinny być same zera
select
    count(*) filter (where unemployment_value is null) as brak_bezrobocia,
    count(*) filter (where salary_value is null) as brak_wynagrodzen,
    count(*) filter (where investment_value is null) as brak_inwestycji,
    count(*) filter (where population_value is null) as brak_ludnosci,
    count(*) filter (where new_firms_value is null) as brak_firm,
    count(*) filter (where crime_detection_value is null) as brak_przestepstw,
    count(*) filter (where births_rate_value is null) as brak_urodzen,
    count(*) filter (where deaths_rate_value is null) as brak_zgonow
from fact_economic_indicators;


-- 16 województw, razem 380 powiatów
select voivodeship_name, count(*) as powiaty
from dim_units
group by voivodeship_name
order by voivodeship_name;

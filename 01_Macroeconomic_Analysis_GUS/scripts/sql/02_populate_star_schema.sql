insert into dim_units (id, name, unit_type, voivodeship_code, voivodeship_name)
select distinct on (s.unit_id)
    s.unit_id,
    s.unit_name,
    case
        when s.unit_name like 'Powiat m.%' then 'miasto na prawach powiatu'
        else 'powiat ziemski'
    end,
    substring(s.unit_id from 3 for 2),
    w.voivodeship_name
from stg_gus_values s
join (values
    ('02', 'dolnośląskie'),
    ('04', 'kujawsko-pomorskie'),
    ('06', 'lubelskie'),
    ('08', 'lubuskie'),
    ('10', 'łódzkie'),
    ('12', 'małopolskie'),
    ('14', 'mazowieckie'),
    ('16', 'opolskie'),
    ('18', 'podkarpackie'),
    ('20', 'podlaskie'),
    ('22', 'pomorskie'),
    ('24', 'śląskie'),
    ('26', 'świętokrzyskie'),
    ('28', 'warmińsko-mazurskie'),
    ('30', 'wielkopolskie'),
    ('32', 'zachodniopomorskie')
) as w (voivodeship_code, voivodeship_name)
    on w.voivodeship_code = substring(s.unit_id from 3 for 2)
order by s.unit_id
on conflict (id) do update
set name = excluded.name,
    unit_type = excluded.unit_type,
    voivodeship_code = excluded.voivodeship_code,
    voivodeship_name = excluded.voivodeship_name;


insert into dim_year (year, year_date)
select distinct year, make_date(year, 12, 31)
from stg_gus_values
order by year
on conflict (year) do nothing;


insert into fact_economic_indicators (
    id_units, year,
    unemployment_value, salary_value, investment_value, population_value,
    new_firms_value, crime_detection_value, births_rate_value, deaths_rate_value
)
select
    unit_id,
    year,
    max(value) filter (where indicator_code = 'bezrobocie'),
    max(value) filter (where indicator_code = 'wynagrodzenia'),
    max(value) filter (where indicator_code = 'inwestycje'),
    max(value) filter (where indicator_code = 'ludnosc'),
    max(value) filter (where indicator_code = 'nowe_firmy'),
    max(value) filter (where indicator_code = 'przestepstwa'),
    max(value) filter (where indicator_code = 'urodzenia'),
    max(value) filter (where indicator_code = 'zgony')
from stg_gus_values
group by unit_id, year
-- coalesce, żeby brak wskaźnika w nowym ładowaniu nie nadpisał starej wartości nullem
on conflict (id_units, year) do update
set unemployment_value = coalesce(excluded.unemployment_value, fact_economic_indicators.unemployment_value),
    salary_value = coalesce(excluded.salary_value, fact_economic_indicators.salary_value),
    investment_value = coalesce(excluded.investment_value, fact_economic_indicators.investment_value),
    population_value = coalesce(excluded.population_value, fact_economic_indicators.population_value),
    new_firms_value = coalesce(excluded.new_firms_value, fact_economic_indicators.new_firms_value),
    crime_detection_value = coalesce(excluded.crime_detection_value, fact_economic_indicators.crime_detection_value),
    births_rate_value = coalesce(excluded.births_rate_value, fact_economic_indicators.births_rate_value),
    deaths_rate_value = coalesce(excluded.deaths_rate_value, fact_economic_indicators.deaths_rate_value),
    loaded_at = now();


create or replace view gus_indicators as
select
    u.id,
    u.name,
    f.year,
    f.unemployment_value as bezrobocie,
    f.investment_value as inwestycje,
    f.population_value as ludnosc,
    f.new_firms_value as nowe_firmy,
    f.crime_detection_value as przestepstwa,
    f.births_rate_value as urodzenia,
    f.salary_value as wynagrodzenia,
    f.deaths_rate_value as zgony
from fact_economic_indicators f
join dim_units u on u.id = f.id_units;

-- starsza wersja 03b tworzyła gus_indicators jako tabelę, teraz to widok
do $$
begin
    if exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'gus_indicators') then
        drop table public.gus_indicators;
    end if;
end $$;

create table if not exists stg_gus_values(
    indicator_code varchar(30) not null,
    unit_id varchar(12) not null,
    unit_name varchar(255) not null,
    year int not null,
    value double precision,
    primary key (indicator_code, unit_id, year)
);

truncate stg_gus_values;

create table if not exists dim_units(
    id varchar(12) primary key,
    name varchar(255) not null,
    unit_type varchar(30) not null,
    voivodeship_code char(2) not null,
    voivodeship_name varchar(50) not null
);

create table if not exists dim_year(
    year int primary key,
    year_date date not null
);

create table if not exists fact_economic_indicators(
    id_units varchar(12) not null references dim_units(id),
    year int not null references dim_year(year),
    unemployment_value int,
    salary_value numeric(12,2), -- zł
    investment_value bigint, -- tys. zł
    population_value int,
    new_firms_value int, -- na 10 tys. ludności w wieku produkcyjnym
    crime_detection_value numeric(5,2), -- %
    births_rate_value numeric(6,2), -- na 1000 ludności
    deaths_rate_value numeric(6,2), -- na 1000 ludności
    loaded_at timestamp not null default now(),
    primary key (id_units, year)
);

create index if not exists ix_fact_year on fact_economic_indicators(year);

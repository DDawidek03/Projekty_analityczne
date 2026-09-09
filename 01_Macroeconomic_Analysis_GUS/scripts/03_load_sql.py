from sqlalchemy import create_engine, text
import json

USER = "damiandawidek"
PASSWORD = ""
HOST = "localhost"
PORT = "5432"
DN_NAME = "Projekt_1"

ENGINE = create_engine(f"postgresql://{USER}:{PASSWORD}@{HOST}:{PORT}/{DN_NAME}")

try:
    with ENGINE.connect() as conn:

        sql_code = text("""
            --Usuwanie tabel
            drop table if exists fact_economic_indicators;
            drop table if exists dim_units;

            create table dim_units(
                id varchar(20) primary key,
                name varchar(255)
            );

            create table fact_economic_indicators(
                id_units VARCHAR(15) REFERENCES dim_units(id),
                year int,
                unemployment_value int,
                salary_value NUMERIC,
                primary key (id_units,year)
            );
        """)

        conn.execute(sql_code);
        conn.commit();
        print("Stworzono baze danych");

        with open("dane/dane_bezrobocia.json","r",encoding="utf-8") as plik_bezrobocia:
            dane_bezrobocia = plik_bezrobocia.read();

            insert_dim_units = text("""
                INSERT INTO dim_units (id, name)
                SELECT id, name
                FROM json_to_recordset(CAST(:moj_json AS json)) AS x(id VARCHAR, name VARCHAR)
                ON CONFLICT (id) DO NOTHING;
            """)


            conn.execute(insert_dim_units, {"moj_json": dane_bezrobocia})
            conn.commit()
            print("Załadowano Wymiar")

            insert_fakty_bezrobocie = text("""
                INSERT INTO fact_economic_indicators (id_units, year, unemployment_value)
                SELECT 
                    powiat.id, 
                    CAST(dane_roczne.year AS INT), 
                    CAST(dane_roczne.val AS INT)
                FROM json_to_recordset(CAST(:moj_json AS json)) AS powiat(id VARCHAR, "values" JSON)
                CROSS JOIN json_to_recordset(powiat."values") AS dane_roczne(year VARCHAR, val INT)
                ON CONFLICT (id_units, year) DO UPDATE 
                SET unemployment_value = EXCLUDED.unemployment_value;
            """)

            conn.execute(insert_fakty_bezrobocie, {"moj_json": dane_bezrobocia})
            conn.commit()
            print("Załadowano Fakty")




        with open("dane/dane_wynagrodzenia.json","r",encoding="utf-8") as plik_wynagrodzenia:
            dane_wynagrodzenia = plik_wynagrodzenia.read();

            insert_fakty_wynagrodzenie = text("""
                INSERT INTO fact_economic_indicators (id_units, year, salary_value)
                SELECT 
                    powiat.id, 
                    CAST(dane_roczne.year AS INT), 
                    CAST(dane_roczne.val AS NUMERIC)
                FROM json_to_recordset(CAST(:moj_json AS json)) AS powiat(id VARCHAR, "values" JSON)
                CROSS JOIN json_to_recordset(powiat."values") AS dane_roczne(year VARCHAR, val NUMERIC)
                ON CONFLICT (id_units, year) DO UPDATE 
                SET salary_value = EXCLUDED.salary_value;
            """)
            conn.execute(insert_fakty_wynagrodzenie, {"moj_json": dane_wynagrodzenia})
            conn.commit()
            print("Załadowano Fakty (Wynagrodzenie)")

                

except Exception as e:
    print(f"Ups, błąd połączenia: {e}")
from sqlalchemy import text

from config import DATA_DIR, WSKAZNIKI, get_engine, run_sql_file

insert_staging = text("""
    INSERT INTO stg_gus_values (indicator_code, unit_id, unit_name, year, value)
    SELECT
        :kod_wskaznika,
        powiat.id,
        powiat.name,
        CAST(dane_roczne.year AS INT),
        dane_roczne.val
    FROM json_to_recordset(CAST(:moj_json AS json)) AS powiat(id VARCHAR, name VARCHAR, "values" JSON)
    CROSS JOIN json_to_recordset(powiat."values") AS dane_roczne(year VARCHAR, val DOUBLE PRECISION);
""")

ENGINE = get_engine()

try:
    with ENGINE.begin() as conn:
        run_sql_file(conn, "01_create_star_schema.sql")

        for id_wskaznika, kod in WSKAZNIKI.items():
            dane_json = (DATA_DIR / f"dane_{id_wskaznika}.json").read_text(encoding="utf-8")
            wynik = conn.execute(insert_staging, {"kod_wskaznika": kod, "moj_json": dane_json})
            print(f"Załadowano staging: {kod} ({wynik.rowcount} wierszy)")

        run_sql_file(conn, "02_populate_star_schema.sql")

    print("Gotowe: star schema zbudowana")

except Exception as e:
    print(f"Błąd: {e}")

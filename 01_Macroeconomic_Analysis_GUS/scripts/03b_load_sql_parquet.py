import pandas as pd

from config import PARQUET_PATH, get_engine, run_sql_file

ENGINE = get_engine()

try:
    df = pd.read_parquet(PARQUET_PATH)

    df_staging = (
        df.melt(id_vars=["id", "name", "year"], var_name="indicator_code", value_name="value")
          .rename(columns={"id": "unit_id", "name": "unit_name"})
          .astype({"year": int})
    )

    with ENGINE.begin() as conn:
        run_sql_file(conn, "01_create_star_schema.sql")

        df_staging.to_sql(name="stg_gus_values", con=conn, if_exists="append", index=False)
        print(f"Załadowano staging ({len(df_staging)} wierszy)")

        run_sql_file(conn, "02_populate_star_schema.sql")

    print("Gotowe: star schema zbudowana")

except Exception as e:
    print(f"Błąd: {e}")

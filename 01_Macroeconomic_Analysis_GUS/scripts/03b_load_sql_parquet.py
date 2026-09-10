from sqlalchemy import create_engine
import pandas as pd

USER = "damiandawidek"
PASSWORD = ""
HOST = "localhost"
PORT = "5432"
DN_NAME = "Projekt_1"

ENGINE = create_engine(f"postgresql://{USER}:{PASSWORD}@{HOST}:{PORT}/{DN_NAME}")

sciezka_do_pliku_parquet = "../dane/merged_data.parquet"

try:
    df = pd.read_parquet(sciezka_do_pliku_parquet)

    df.to_sql(name="gus_indicators", con=ENGINE, if_exists="replace", index=False)
    

except Exception as e:
    print(f"Błąd połączenia: {e}")

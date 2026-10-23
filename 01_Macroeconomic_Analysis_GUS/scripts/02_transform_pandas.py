import pandas as pd
import json

from config import DATA_DIR, PARQUET_PATH, WSKAZNIKI



pliki = [f"dane_{id_wskaznika}.json" for id_wskaznika in WSKAZNIKI]
tlumacz_wskaznikow = {f"dane_{id_wskaznika}.json": kod for id_wskaznika, kod in WSKAZNIKI.items()}

przetworzone_dane = []

for plik in pliki:
    plik_path = DATA_DIR / plik
    with open(plik_path, 'r', encoding="UTF-8") as file:
        dane = json.load(file)
    df = pd.json_normalize(dane, record_path='values', meta=['id','name'])
    df['wskaznik'] = tlumacz_wskaznikow[plik]
    przetworzone_dane.append(df)

df_master = pd.concat(przetworzone_dane, ignore_index=True)

df_tabela = df_master.pivot_table(
    index=["id","name","year"],
    columns ="wskaznik",
    values = "val"
).reset_index()

print(df_tabela.head(15))

df_tabela.to_parquet(PARQUET_PATH, index=False)
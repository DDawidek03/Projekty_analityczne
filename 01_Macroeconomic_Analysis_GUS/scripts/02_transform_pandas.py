import pandas as pd
import json

plik_path = "../dane/dane_459121.json"

with open(plik_path, 'r', encoding="UTF-8") as plik:
    dane = json.load(plik)

df = pd.json_normalize(dane, record_path='values', meta=['id','name'])

print(df.head(10))
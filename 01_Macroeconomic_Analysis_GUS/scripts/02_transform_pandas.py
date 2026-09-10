from operator import index
import pandas as pd
import json



pliki = ["dane_459121.json",
        "dane_3149.json","dane_58565.json","dane_64428.json",
        "dane_72305.json","dane_155064.json","dane_395374.json","dane_6.json"]

tlumacz_wskaznikow = {
    "dane_459121.json": "bezrobocie",
    "dane_64428.json": "wynagrodzenia",
    "dane_155064.json": "inwestycje",      
    "dane_58565.json": "przestepstwa",     
    "dane_395374.json": "nowe_firmy",      
    "dane_72305.json": "ludnosc",          
    "dane_3149.json": "urodzenia",         
    "dane_6.json": "zgony"
}

przetworzone_dane = []

for plik in pliki:
    plik_path = "../dane/" + plik 
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

df_tabela.to_parquet("../dane/merged_data.parquet",index=False)


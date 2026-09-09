import requests as req
import json

base_url = "https://bdl.stat.gov.pl/api/v1"
lata = [2018, 2019, 2020, 2021, 2022, 2023, 2024]
lista_wskaznikow = [459121, 64428, 155064, 58565, 395374, 72305, 128470]

for wskasnik in lista_wskaznikow:
    url = f"{base_url}/data/by-variable/{wskasnik}?format=json&unit-level=5"
    for rok in lata:
        url += f"&year={rok}"
    print(f"Fetching {url}")
    resp = req.get(url).json()
    if "results" not in resp:
        print("ERROR on first page:", resp)
        break
        
    while "next" in resp.get("links", {}):
        next_url = resp["links"]["next"]
        print(f"Fetching next: {next_url}")
        next_resp = req.get(next_url).json()
        if "results" not in next_resp:
            print("ERROR on next page:", next_resp)
            break
        resp = next_resp
        

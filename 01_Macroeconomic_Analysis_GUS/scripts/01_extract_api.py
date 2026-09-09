import requests as req
import json
import time

BASE_URL = "https://bdl.stat.gov.pl/api/v1"

'''      
      "id": 155064,
      "subjectId": "P2862",
      "n1": "nakłady inwestycyjne w przedsiębiorstwach",
      "n2": "ogółem",
      "n3": "ogółem",
      "level": 5,
      "measureUnitId": 5,
      "measureUnitName": "tys. zł"


       "id": 58565,
      "subjectId": "P2290",
      "n1": "wskaźnik wykrywalności sprawców przestępstw stwierdzonych przez Policję - ogółem",
      "level": 5,
      "measureUnitId": 50,
      "measureUnitName": "%"

      "id": 395374,
      "subjectId": "P2419",
      "n1": "podmioty nowo zarejestrowane na 10 tys. ludności w wieku produkcyjnym",
      "level": 6,
      "measureUnitId": 1,
      "measureUnitName": "-"

      "id": 72305,
      "subjectId": "P2137",
      "n1": "ogółem",
      "n2": "ogółem",
      "level": 6,
      "measureUnitId": 26,
      "measureUnitName": "osoba",


      "id": 3149,
      "subjectId": "P3149",
      "n1": "w kraju - liczba urodzeń",
      "level": 5,
      "measureUnitId": 26,
      "measureUnitName": "osoba",
'''


def pobierz_dane_gus(id_wskaznika, lata):
    base_url = "https://bdl.stat.gov.pl/api/v1"
    url = f"{base_url}/data/by-variable/{id_wskaznika}?format=json&unit-level=5&page-size=100"
    for rok in lata:
        url += f"&year={rok}"

    wszystkie_dane = []

    while True:
        odpowiedz = req.get(url, timeout=30)

        if odpowiedz.status_code == 429:
            print(f"Przekroczono limit API dla {id_wskaznika}")
            time.sleep(60)
            continue

        try:
            dane = odpowiedz.json()
        except ValueError:
            print(f"Brak poprawnego JSON dla wskaźnika {id_wskaznika}: {odpowiedz.text[:200]}")
            return []

        if "results" not in dane:
            komunikat = dane.get("errorResult") or dane.get("errors") or dane
            print(f"Brak danych dla wskaźnika {id_wskaznika}: {komunikat}")
            return []

        wszystkie_dane.extend(dane["results"])

        links = dane.get("links", {})
        if "next" not in links:
            break

        url = links["next"]

    return wszystkie_dane

lata = [2018, 2019, 2020, 2021, 2022, 2023, 2024]
lista_wskaznikow = [459121, 64428, 155064, 58565, 395374, 72305, 3149]

for i in lista_wskaznikow:
    print(f"Pobieram wskaźnik {i}...")
    dane = pobierz_dane_gus(i, lata)
    if dane:
        with open(f"dane/dane_{i}.json", "w", encoding="utf-8") as plik:
            json.dump(dane, plik, ensure_ascii=False, indent=4)
    else:
        print(f"Pomijam wskaźnik {i}, bo API nie zwróciło danych.")

    time.sleep(1)


    

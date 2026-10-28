# Serwer MCP do mojej bazy GUS (schemat gwiazdy w PostgreSQL)

import os
from pathlib import Path

from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# folder projektu (o jeden wyzej niz mcp_server) - tam lezy plik .env
PROJECT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_DIR / ".env")

# Lista wskaznikow ktore mozna pytac
# klucz = nazwa ktora podaje model, a w srodku nazwa kolumny w tabeli faktow, jednostka i opis
# WAZNE: nazwa kolumny do SQL bierze sie tylko z tego slownika, nigdy z tego co wpisze uzytkownik
# dzieki temu nie da sie zrobic SQL injection
WSKAZNIKI = {
    "unemployment": {"kolumna": "unemployment_value", "jednostka": "persons", "opis": "Registered unemployed"},
    "salary": {"kolumna": "salary_value", "jednostka": "PLN", "opis": "Average gross monthly salary"},
    "investment": {"kolumna": "investment_value", "jednostka": "thousand PLN", "opis": "Capital investment in enterprises"},
    "population": {"kolumna": "population_value", "jednostka": "persons", "opis": "Total population"},
    "new_firms": {"kolumna": "new_firms_value", "jednostka": "per 10k working-age pop.", "opis": "New REGON entities"},
    "crime_detection": {"kolumna": "crime_detection_value", "jednostka": "%", "opis": "Crime detection rate"},
    "births": {"kolumna": "births_rate_value", "jednostka": "per 1,000 pop.", "opis": "Live births"},
    "deaths": {"kolumna": "deaths_rate_value", "jednostka": "per 1,000 pop.", "opis": "Deaths"},
}

LATA = [2018, 2019, 2020, 2021, 2022, 2023, 2024]

# maksymalnie tyle wierszy zwracam, zeby nie wyslac do modelu calej bazy
MAX_WIERSZY = 50


def get_engine():
    # najpierw sprawdzam czy w .env jest caly adres bazy (DB_URL)
    database_url = os.getenv("DB_URL")

    if not database_url:
        # jak nie ma to skladam adres z kawalkow
        # MCP_DB_USER to osobny uzytkownik tylko do odczytu (opis w README)
        # jak go nie ma to biore zwyklego DB_USER
        user = os.getenv("MCP_DB_USER") or os.getenv("DB_USER", "")
        password = os.getenv("MCP_DB_PASSWORD") or os.getenv("DB_PASSWORD", "")
        host = os.getenv("DB_HOST", "localhost")
        port = int(os.getenv("DB_PORT", "5432"))
        db_name = os.getenv("DB_NAME", "Projekt_1")
        database_url = URL.create(
            "postgresql",
            username=user,
            password=password,
            host=host,
            port=port,
            database=db_name,
        )

    # pool_pre_ping sprawdza czy polaczenie dalej dziala zanim go uzyje
    return create_engine(database_url, pool_pre_ping=True)


engine = get_engine()

# tworze serwer MCP, "gus-counties" to jego nazwa ktora widzi klient
mcp = FastMCP("gus-counties")


def sprawdz_wskaznik(wskaznik):
    # zamienia nazwe wskaznika (np. "salary") na nazwe kolumny w bazie
    # jak ktos poda zla nazwe to wyrzucam blad z lista dozwolonych
    klucz = wskaznik.strip().lower()
    if klucz not in WSKAZNIKI:
        dozwolone = ", ".join(WSKAZNIKI.keys())
        raise ValueError(f"Unknown indicator '{wskaznik}'. Allowed: {dozwolone}")
    return WSKAZNIKI[klucz]["kolumna"]


def sprawdz_rok(rok):
    # mam dane tylko z lat 2018-2024
    if rok not in LATA:
        raise ValueError(f"Year must be between {LATA[0]} and {LATA[-1]}")


def zapytanie(sql, **parametry):
    # wykonuje SELECT i zwraca liste slownikow (jeden slownik = jeden wiersz)
    # parametry ida osobno jako :nazwa, nie wklejam ich do tekstu SQL
    wynik = []
    with engine.connect() as conn:
        for wiersz in conn.execute(text(sql), parametry):
            wynik.append(dict(wiersz._mapping))
    return wynik


# ---------------- NARZEDZIA (TOOLS) ----------------
# @mcp.tool() sprawia ze funkcja staje sie narzedziem dla modelu
# docstring (tekst w """ """) model czyta jako opis narzedzia, dlatego jest po angielsku
# typy argumentow (str, int) tez ida do modelu, wiec musza byc wpisane


@mcp.tool()
def list_indicators() -> list[dict]:
    """List available indicators (names to use in other tools), units and years covered."""
    lista = []
    for nazwa, info in WSKAZNIKI.items():
        lista.append({
            "indicator": nazwa,
            "unit": info["jednostka"],
            "description": info["opis"],
            "years": f"{LATA[0]}-{LATA[-1]}",
        })
    return lista


@mcp.tool()
def list_voivodeships() -> list[str]:
    """List the 16 voivodeship names (lowercase, e.g. 'lubelskie')."""
    wiersze = zapytanie("SELECT DISTINCT voivodeship_name FROM dim_units ORDER BY voivodeship_name")
    wojewodztwa = []
    for w in wiersze:
        wojewodztwa.append(w["voivodeship_name"])
    return wojewodztwa


@mcp.tool()
def search_county(name: str, voivodeship: str | None = None) -> list[dict]:
    """Find counties (powiaty) by part of the name. County names are NOT unique
    (e.g. 'powiat grodziski' exists twice), so use `id` and `voivodeship_name` to tell them apart.
    Optional `voivodeship` narrows the search (e.g. 'mazowieckie')."""
    # % na poczatku i koncu = szukam fragmentu nazwy (LIKE)
    wzorzec = "%" + name.strip().lower() + "%"
    # (:woj IS NULL OR ...) - jak wojewodztwo nie jest podane to ten warunek nic nie filtruje
    sql = f"""
        SELECT id, name, unit_type, voivodeship_name
        FROM dim_units
        WHERE LOWER(name) LIKE :wzorzec
          AND (:woj IS NULL OR LOWER(voivodeship_name) = LOWER(:woj))
        ORDER BY name, voivodeship_name
        LIMIT {MAX_WIERSZY}
    """
    return zapytanie(sql, wzorzec=wzorzec, woj=voivodeship)


@mcp.tool()
def get_indicator(county_id: str, indicator: str, year: int | None = None) -> list[dict]:
    """Value of an indicator for one county (use `id` from search_county).
    Without `year` returns all years 2018-2024 (a time series)."""
    kolumna = sprawdz_wskaznik(indicator)
    if year is not None:
        sprawdz_rok(year)

    # kolumne wklejam przez f-string, ale jest bezpieczna bo pochodzi z WSKAZNIKI
    sql = f"""
        SELECT u.name, u.voivodeship_name, f.year, f.{kolumna} AS value
        FROM fact_economic_indicators f
        JOIN dim_units u ON u.id = f.id_units
        WHERE u.id = :id_powiatu
          AND (:rok IS NULL OR f.year = :rok)
        ORDER BY f.year
    """
    return zapytanie(sql, id_powiatu=county_id, rok=year)


@mcp.tool()
def compare_to_national(county_id: str, indicator: str, year: int) -> dict:
    """Compare a county with the national average (mean over all 380 counties) for one
    indicator and year: value, national average, difference and ratio (national = 1.0)."""
    kolumna = sprawdz_wskaznik(indicator)
    sprawdz_rok(year)

    # dwa podzapytania: wartosc dla powiatu i srednia ze wszystkich powiatow w danym roku
    sql = f"""
        SELECT u.name, u.voivodeship_name,
               (SELECT f.{kolumna} FROM fact_economic_indicators f
                WHERE f.id_units = u.id AND f.year = :rok) AS value,
               (SELECT AVG(f.{kolumna}) FROM fact_economic_indicators f
                WHERE f.year = :rok) AS national_avg
        FROM dim_units u
        WHERE u.id = :id_powiatu
    """
    wiersze = zapytanie(sql, id_powiatu=county_id, rok=year)

    if len(wiersze) == 0 or wiersze[0]["value"] is None:
        return {"error": "No data for this county/year"}

    w = wiersze[0]
    # z bazy przychodzi Decimal, zamieniam na float zeby moc liczyc i zaokraglac
    wartosc = float(w["value"])
    srednia = float(w["national_avg"])

    # zabezpieczenie przed dzieleniem przez 0
    if srednia != 0:
        stosunek = round(wartosc / srednia, 3)
    else:
        stosunek = None

    return {
        "county": w["name"],
        "voivodeship": w["voivodeship_name"],
        "indicator": indicator,
        "year": year,
        "value": round(wartosc, 2),
        "national_avg": round(srednia, 2),
        "difference": round(wartosc - srednia, 2),
        "ratio_to_national": stosunek,
    }


@mcp.tool()
def top_counties(
    indicator: str, year: int, n: int = 10, ascending: bool = False, voivodeship: str | None = None
) -> list[dict]:
    """Ranking of counties by an indicator for a year. `n` is capped at 50.
    `ascending=True` returns the lowest values; `voivodeship` restricts the ranking."""
    kolumna = sprawdz_wskaznik(indicator)
    sprawdz_rok(year)

    # n musi byc miedzy 1 a 50
    n = int(n)
    if n < 1:
        n = 1
    if n > MAX_WIERSZY:
        n = MAX_WIERSZY

    # kierunek sortowania to tylko jedno z dwoch slow, nie biore go od uzytkownika
    if ascending:
        kierunek = "ASC"
    else:
        kierunek = "DESC"

    sql = f"""
        SELECT u.id, u.name, u.voivodeship_name, f.{kolumna} AS value
        FROM fact_economic_indicators f
        JOIN dim_units u ON u.id = f.id_units
        WHERE f.year = :rok
          AND f.{kolumna} IS NOT NULL
          AND (:woj IS NULL OR LOWER(u.voivodeship_name) = LOWER(:woj))
        ORDER BY f.{kolumna} {kierunek}
        LIMIT {n}
    """
    return zapytanie(sql, rok=year, woj=voivodeship)


@mcp.tool()
def voivodeship_summary(indicator: str, year: int) -> list[dict]:
    """Average of an indicator per voivodeship (mean over its counties) for one year,
    sorted from highest to lowest."""
    kolumna = sprawdz_wskaznik(indicator)
    sprawdz_rok(year)

    sql = f"""
        SELECT u.voivodeship_name, ROUND(AVG(f.{kolumna}), 2) AS avg_value
        FROM fact_economic_indicators f
        JOIN dim_units u ON u.id = f.id_units
        WHERE f.year = :rok
        GROUP BY u.voivodeship_name
        ORDER BY avg_value DESC
    """
    return zapytanie(sql, rok=year)


if __name__ == "__main__":
    # uruchamiam serwer w trybie stdio - klient (np. gemini_client.py) gada z nim przez wejscie/wyjscie
    mcp.run()

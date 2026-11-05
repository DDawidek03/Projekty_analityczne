# Miary DAX — Macroeconomic Analysis GUS

Dokumentacja miar z modelu Power BI (projekt `01_Macroeconomic_Analysis_GUS`).

## Model danych (star schema)

```
dim_year (year) 1 ──< * fact_economic_indicators * >── 1 dim_units (id)
```

- **Ziarno faktów:** 1 wiersz = 1 powiat × 1 rok (380 × 7 = 2660 wierszy, lata 2018–2024).
- **dim_units:** `id`, `name`, `unit_type`, `voivodeship_code`, `voivodeship_name`.
- **dim_year:** `year`, `year_date`.
- **fact_economic_indicators:** `id_units`, `year`, `unemployment_value`, `salary_value`, `investment_value`, `population_value`, `new_firms_value`, `crime_detection_value`, `births_rate_value`, `deaths_rate_value`.
- Relacje 1:N, kierunek filtra z wymiarów do faktów. Wszystkie miary w tabeli `_Miary`.

> Uwagi o danych: `births_rate_value` i `deaths_rate_value` to wskaźniki (nie liczby osób); nazwy powiatów nie są unikalne (np. „Powiat brzeski”), więc zliczamy po kluczu `id`; dane są roczne, bez kalendarza dziennego.

---

## Poziom 1: agregacje i DIVIDE

```dax
Liczba powiatów =
DISTINCTCOUNT('public fact_economic_indicators'[id_units])
```
Liczy po kluczu z faktów (nie po nazwie), więc reaguje na slicer roku i województwa.

```dax
Suma inwestycji = SUM('public fact_economic_indicators'[investment_value])
Suma łączna ludność = SUM('public fact_economic_indicators'[population_value])
suma bezrobotnych = SUM('public fact_economic_indicators'[unemployment_value])
```
Uwaga: ludność i bezrobotni to wielkości typu „stan”; sumowanie po latach nie ma sensu (patrz `ludność bez sumowania po latach`). Inwestycje to przepływ i wolno je sumować.

```dax
Stopa bezrobocia % =
DIVIDE([suma bezrobotnych], [Suma łączna ludność])

Inwestycje na mieszkańca =
DIVIDE([Suma inwestycji], [Suma łączna ludność])

Średnie wynagrodzenie =
AVERAGE('public fact_economic_indicators'[salary_value])

Wskaźnik zgony / urodzenia =
DIVIDE(
    AVERAGE('public fact_economic_indicators'[deaths_rate_value]),
    AVERAGE('public fact_economic_indicators'[births_rate_value])
)
```
Iloraz dwóch sum z tego samego okresu jest sensowny nawet wtedy, gdy każda z sum osobno nie jest.

---

## Poziom 2: CALCULATE i kontekst filtrów

```dax
Średnie_wynagrodzenie_2024 =
CALCULATE([Średnie wynagrodzenie], 'public dim_year'[year] = 2024)

Średnia krajowa wynagrodzeń =
CALCULATE([Średnie wynagrodzenie], ALL('public dim_units'))
```
`ALL(tabela)` zdejmuje filtry ze wszystkich kolumn wymiaru, więc slicery województwa i powiatu nie wpływają na wynik. `ALL(kolumna)` zdjąłby tylko jedną kolumnę.

```dax
Różnica =
[Średnie wynagrodzenie] - [Średnia krajowa wynagrodzeń]

Indeks =
DIVIDE([Średnie wynagrodzenie], [Średnia krajowa wynagrodzeń]) * 100
```
Indeks: średnia krajowa = 100, wartość powyżej 100 oznacza wynagrodzenie wyższe od średniej.

```dax
Udział w ludności kraju =
DIVIDE(
    [Suma łączna ludność],
    CALCULATE([Suma łączna ludność], ALL('public dim_units'))
)

Udział w bieżącym wyborze =
DIVIDE(
    [Suma łączna ludność],
    CALCULATE([Suma łączna ludność], ALLSELECTED('public dim_units'))
)
```
`ALL` daje stały punkt odniesienia (cały kraj), `ALLSELECTED` zachowuje slicery i pokazuje udział w tym, co widzi użytkownik (suma udziałów w wyborze = 100%).

```dax
średnia ważona ludnością =
DIVIDE(
    SUMX(
        'public fact_economic_indicators',
        'public fact_economic_indicators'[salary_value]
            * 'public fact_economic_indicators'[population_value]
    ),
    [Suma łączna ludność]
)
```
Dzielenie przez sumę ludności musi być poza iteratorem, inaczej przejście kontekstu zamieni wynik w sumę wynagrodzeń.

---

## Poziom 3: rok do roku

```dax
Wynagrodzenie z poprzedniego roku =
VAR rok = SELECTEDVALUE('public dim_year'[year])
RETURN
    CALCULATE([Średnie wynagrodzenie], 'public dim_year'[year] = rok - 1)
```
Brak tabeli dat dziennych, więc poprzedni rok liczymy z samej kolumny `year`. Dla 2018 wynik jest pusty.

```dax
dynamika r/r % wynagrodzeń =
DIVIDE(
    [Średnie wynagrodzenie] - [Wynagrodzenie z poprzedniego roku],
    [Wynagrodzenie z poprzedniego roku]
)
```

```dax
Wzrost 2020→2023 % =
VAR poczatek = CALCULATE([Średnie wynagrodzenie], 'public dim_year'[year] = 2020)
VAR koniec   = CALCULATE([Średnie wynagrodzenie], 'public dim_year'[year] = 2023)
RETURN
    DIVIDE(koniec - poczatek, poczatek)

CAGR 2018–2024 =
VAR poczatek = CALCULATE([Średnie wynagrodzenie], 'public dim_year'[year] = 2018)
VAR koniec   = CALCULATE([Średnie wynagrodzenie], 'public dim_year'[year] = 2024)
RETURN
    DIVIDE(koniec, poczatek) ^ (1 / 6) - 1
```
CAGR: stała roczna stopa wzrostu między 2018 a 2024; wykładnik to 1/liczba okresów (6), nie liczba lat.

```dax
średnia krocząca z 3 lat wynagrodzeń =
VAR rok = SELECTEDVALUE('public dim_year'[year])
RETURN
    CALCULATE(
        [Średnie wynagrodzenie],
        'public dim_year'[year] >= rok - 2 && 'public dim_year'[year] <= rok
    )

ludność bez sumowania po latach =
VAR ostatni_rok = MAX('public dim_year'[year])
RETURN
    CALCULATE([Suma łączna ludność], 'public dim_year'[year] = ostatni_rok)
```
Druga miara to wzorzec dla wielkości typu „stan”: wartość z ostatniego roku z wybranego zakresu.

---

## Poziom 4: rankingi i iteratory

```dax
Ranking powiatu wg średniego wynagrodzenia =
VAR powiaty_w_wyborze = ALLSELECTED('public dim_units')
RETURN
    RANKX(powiaty_w_wyborze, [Średnie wynagrodzenie], , DESC, Skip)

Top 3 powiaty wg wynagrodzeń =
CONCATENATEX(
    TOPN(3, ALLSELECTED('public dim_units'), [Średnie wynagrodzenie]),
    'public dim_units'[name],
    ", ",
    [Średnie wynagrodzenie],
    DESC
)

liczba powiatów z wynagrodzeniem powyżej średniej krajowej =
COUNTROWS(
    FILTER(
        ALLSELECTED('public dim_units'),
        [Średnie wynagrodzenie] > [Średnia krajowa wynagrodzeń]
    )
)

Kwartyl inwestycji =
VAR ranking = RANKX(ALLSELECTED('public dim_units'), [Suma inwestycji], , DESC, Skip)
VAR liczba_powiatow = COUNTROWS(ALLSELECTED('public dim_units'))
RETURN
    ROUNDUP(DIVIDE(ranking, liczba_powiatow / 4), 0)
```
Kwartyl 1 = 25% powiatów z najwyższymi inwestycjami.

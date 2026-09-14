# Brief Analityczny — Makroekonomiczna Analiza Regionalna Polski

> **Klient:** Fundusz inwestycyjny Private Equity  
> **Analityk:** Damian Dawidek  
> **Źródło danych:** GUS Bank Danych Lokalnych (BDL API), dane za lata 2018–2024  
> **Zakres:** 370 powiatów | 9 wskaźników makroekonomicznych  
> **Cel:** Identyfikacja regionów o najwyższym potencjale inwestycyjnym

---

## Kontekst biznesowy

Fundusz rozważa alokację kapitału w polskich regionach i potrzebuje rzetelnej,
opartej na danych odpowiedzi na pytanie: **gdzie w Polsce warto inwestować?**

Samo przeglądanie tabel z danymi GUS nie wystarczy. Potrzebna jest analiza
łącząca kilka wymiarów jednocześnie: dynamikę wynagrodzeń, poziom bezrobocia,
aktywność inwestycyjną i trendy demograficzne. Wyniki tej analizy posłużą
zarządowi funduszu jako podstawa do podjęcia decyzji o wartości kilkudziesięciu
milionów złotych.

---

## Pytania badawcze

### Pytanie 1 — Odporność ekonomiczna regionów po pandemii COVID-19

**Problem biznesowy:**  
Pandemia roku 2020 była zewnętrznym szokiem ekonomicznym, który dotknął
wszystkie powiaty bez wyjątku. Jednak nie wszystkie wyszły z tego kryzysu
z jednakową siłą. Z perspektywy funduszu kluczowe jest pytanie: które regiony
wykazały się największą odpornością i zdolnością do odbudowy? Powiat, który
w 3 lata odrobił straty i zanotował realny wzrost wynagrodzeń, jest znacznie
atrakcyjniejszym celem inwestycyjnym niż ten, który nadal stagnuje.

**Cel analizy:**  
Zidentyfikować TOP 20 powiatów o najwyższej dynamice wzrostu wynagrodzeń
w okresie 2020–2023, wyrażonej jako zmiana procentowa.

**Techniki SQL:** Common Table Expressions (CTE), JOIN między zbiorami z różnych lat,
obliczenie procentowej zmiany wartości.

---

### Pytanie 2 — Paradoks inwestycji a bezrobocie

**Problem biznesowy:**  
Intuicyjnie zakładamy, że napływ inwestycji do regionu redukuje bezrobocie.
Analiza korelacji przeprowadzona na dostępnych danych wskazuje jednak
współczynnik +0,37 pomiędzy poziomem inwestycji a liczbą bezrobotnych — czyli
kierunek odwrotny do oczekiwanego. Przed podjęciem decyzji inwestycyjnych
fundusz wymaga wyjaśnienia tego pozornego paradoksu.

Hipoteza: zjawisko wynika z efektu skali — największe polskie metropolie
skupiają zarówno największe inwestycje, jak i największe liczby bezrobotnych
w wartościach bezwzględnych, podczas gdy ich stopa bezrobocia wyrażona
procentowo jest niska. Analiza powinna to potwierdzić lub obalić.

**Cel analizy:**  
Podzielić powiaty na cztery kwartyle według poziomu inwestycji i porównać
w każdym kwartyle średnią wartość bezrobocia absolutnego oraz bezrobocia
wyrażonego jako odsetek populacji.

**Techniki SQL:** Funkcja okienkowa `NTILE()`, grupowanie, agregacje, obliczenia
procentowe na poziomie populacji.

---

### Pytanie 3 — Identyfikacja obszarów zagrożonych kryzysem demograficznym

**Problem biznesowy:**  
Inwestycja długoterminowa w region skazany na wyludnienie jest obarczona
wysokim ryzykiem — za 10–15 lat może tam brakować zarówno konsumentów,
jak i pracowników. Wskaźnik relacji liczby zgonów do liczby urodzeń jest
jednym z najlepszych sygnałów wczesnego ostrzegania. Wartość powyżej 1,5
oznacza, że region traci populację w alarmującym tempie.

Fundusz potrzebuje listy powiatów, w których wskaźnik ten nie tylko przekracza
próg alarmowy, ale systematycznie pogarsza się rok do roku.

**Cel analizy:**  
Wyliczyć wskaźnik demograficzny `zgony / urodzenia` dla każdego powiatu
i każdego roku. Oznaczyć regiony o rosnącym trendzie pogorszenia oraz
zastosować klasyfikację: stan krytyczny, stan ostrzegawczy, stan stabilny.

**Techniki SQL:** Funkcja okienkowa `LAG()`, obsługa dzielenia przez zero
(`NULLIF`), klasyfikacja warunkowa `CASE WHEN`.

---

## Wymagania dotyczące wizualizacji (Power BI)

### Strona 1 — Mapa Inwestycyjna Polski

Celem tej strony jest odpowiedź na jedno pytanie zarządu: *"Gdzie dziś
warto ulokować kapitał?"* Strona powinna być czytelna dla osoby bez
wykształcenia technicznego i dawać odpowiedź w ciągu 30 sekund.

**Elementy obowiązkowe:**

| Element | Opis |
|---|---|
| Karty KPI (górny rząd) | Średnie wynagrodzenie w Polsce 2023, łączna wartość inwestycji, powiat o najwyższej dynamice wzrostu płac |
| Wykres liniowy | Trend wynagrodzeń dla 5 największych miast w latach 2018–2024 |
| Wykres słupkowy | Ranking TOP 10 powiatów według wartości inwestycji w 2023 roku |
| Tabela z formatowaniem warunkowym | Powiaty posegregowane na segmenty zarobkowe z kolorowym oznaczeniem kategorii |

---

### Strona 2 — Analiza Demograficzna i Rynek Pracy

Celem tej strony jest pokazanie dwóch wymiarów ryzyka: ryzyka demograficznego
(wyludnienie) oraz ryzyka rynku pracy (nierównowaga między zarobkami
a bezrobociem). Strona jest skierowana do analityków ryzyka w funduszu.

**Elementy obowiązkowe:**

| Element | Opis |
|---|---|
| Wykres punktowy (Scatter Plot) | Oś X: bezrobocie, Oś Y: wynagrodzenia, rozmiar bańki: populacja — każda bańka to jeden powiat. Powiaty w lewym górnym rogu to "złoto inwestycyjne" |
| Tabela klasyfikacji demograficznej | Ranking powiatów według wskaźnika zgony/urodzenia z oznaczeniami: krytyczny / ostrzegawczy / stabilny |
| Wykres słupkowy | TOP 15 powiatów z najgorszym wskaźnikiem demograficznym |

---

## Plan realizacji

| Etap | Zadanie | Status |
|---|---|---|
| 1 | Analiza SQL — odporność post-COVID | `[ ]` Do wykonania |
| 2 | Analiza SQL — paradoks inwestycji i bezrobocia | `[ ]` Do wykonania |
| 3 | Analiza SQL — alarm demograficzny | `[ ]` Do wykonania |
| 4 | Power BI — Strona 1: Mapa Inwestycyjna | `[ ]` Do wykonania |
| 5 | Power BI — Strona 2: Analiza Demograficzna | `[ ]` Do wykonania |
| 6 | Aktualizacja dokumentacji (README) o wnioski | `[ ]` Do wykonania |

---

*Dokument wewnętrzny projektu analitycznego. Dane źródłowe: GUS BDL API.*

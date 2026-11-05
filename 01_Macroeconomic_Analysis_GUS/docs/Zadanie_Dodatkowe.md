# Rozbudowa Projektu 2.0: Zaawansowana Analiza Makroekonomiczna i Dashboarding

*   **Kategoria:** Data Engineering, Python Scripting, Business Intelligence (Advanced)
*   **Główna technologia:** Python (Pandas), JSON, Odkrywanie API, CSV, Power BI
*   **Opis biznesowy:** Zarząd jest pod wrażeniem Twojego tempa pracy! W związku z tym podjął decyzję o znacznej rozbudowie zakresu analitycznego. Pierwotnie chcieliśmy zbadać tylko podstawowe różnice (bezrobocie, wynagrodzenia, inwestycje), ale aby podjąć strategiczne decyzje biznesowe, potrzebujemy pełnego obrazu gospodarczo-społecznego polskich powiatów. 
Zadaniem jest zbudowanie "kombajnu", który pobierze bogaty zbiór danych i przetworzy go do postaci spłaszczonej, analitycznej tabeli. To pozwoli na stworzenie niezwykle zaawansowanego i atrakcyjnego wizualnie dashboardu.

*   **Rozszerzony zakres danych (Do znalezienia w API):**
    Jako analityk musisz zidentyfikować odpowiednie `ID zmiennych` (korzystając z endpointu `/api/v1/variables` z odpowiednimi filtrami lub wyszukiwarką na stronie GUS) dla poniższych obszarów:
    1.  **Rynek Pracy:** Bezrobocie (już masz: `459121`), Wynagrodzenia (już masz: `64428`)
    2.  **Inwestycje:** Nakłady inwestycyjne w przedsiębiorstwach
    3.  **Demografia:** Liczba ludności ogółem (bardzo ważne do wyliczania wskaźników per capita w PowerBI!)
    4.  **Przedsiębiorczość:** Podmioty nowo zarejestrowane w rejestrze REGON (pokazuje rozwój biznesu)
    5.  **Bezpieczeństwo/Społeczeństwo:** Wskaźnik wykrywalności sprawców przestępstw LUB Wychowanie przedszkolne (wybierz to, co wyda Ci się ciekawsze na dashboard).

*   **Zadania (Level: Mid/Advanced Analyst):**
    1. **Przeszukiwanie API:** Znajdź i zanotuj ID dla nowych wskaźników (Demografia, Przedsiębiorczość, Inwestycje itp.).
    2. **Refaktoryzacja `skrypt_api.py`:** Zamiast wywoływać funkcję `pobierz_dane_gus` dla każdego wskaźnika osobno i pisać `with open...` wiele razy, zrób z tego **listę słowników LUB listę ID** i przetwórz je w jednej, dynamicznej pętli. Skrypt ma sam zapisać 5-6 osobnych plików JSON (np. w pętli generując nazwy typu `dane_wskaznik_XXXXXX.json`).
    3. **Zaawansowany `skrypt_pandas.py`:** 
        * Użyj biblioteki `os` lub `glob`, aby dynamicznie wczytać *wszystkie* pliki `.json` z wybranego folderu (nie hardkoduj nazw plików!).
        * Dla każdego wczytanego pliku zrób "flattening" (rozpakowanie zagnieżdżeń np. przez `pd.json_normalize`).
        * **Wyzwanie Pandas:** Połącz wszystkie wczytane i rozpakowane ramki danych (DataFrames) w jedną potężną tabelę faktów (łącząc po `ID Powiatu` i `Roku`). Zrób to sprytnie, np. używając metody `reduce` LUB łącząc je po kolei w pętli `for`.
    4. **Eksport do Power BI:** Zapisz gotową, szeroką tabelę jako `dane_master_powerbi.csv`.

**Wymagany rezultat końcowy:** Kod w Pythonie, który jest skalowalny (dodanie kolejnego wskaźnika to tylko dopisanie jednego ID do listy w skrypcie API) oraz imponujący i bogaty plik CSV, który na dashboardzie w Power BI pozwoli na tworzenie wielowymiarowych analiz, wykresów rozrzutu (Scatter plot np. Wynagrodzenia vs Nowe Firmy) i pięknych map powiatów!

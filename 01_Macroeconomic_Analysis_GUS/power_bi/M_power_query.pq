let
    Url = "https://bdl.stat.gov.pl/api/v1/data/by-variable/64428?format=json&unit-level=5&page-size=100&year=2018&year=2019&year=2020&year=2021&year=2022&year=2023&year=2024&page=",

    Strony = {0, 1, 2, 3},

    Odpowiedzi = List.Transform(Strony, each Json.Document(Web.Contents(Url & Text.From(_)))),

    Wyniki = List.Transform(Odpowiedzi, each _[results]),

    Wszystko = List.Combine(Wyniki),

    Tabela = Table.FromList(Wszystko, Splitter.SplitByNothing(), {"powiat"}),

    Rozwiniety = Table.ExpandRecordColumn(Tabela, "powiat", {"id", "name", "values"}),

    Lata = Table.ExpandListColumn(Rozwiniety, "values"),

    Wartosci = Table.ExpandRecordColumn(Lata, "values", {"year", "val"}),

    Typy = Table.TransformColumnTypes(Wartosci, {{"year", Int64.Type}, {"val", type number}}),

    Wskaznik = Table.AddColumn(Typy, "wskaznik", each "wynagrodzenia")
in
    Wskaznik
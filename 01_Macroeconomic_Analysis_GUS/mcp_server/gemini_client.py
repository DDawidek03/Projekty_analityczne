# Klient do testowania serwera MCP z modelem Gemini
import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

# folder w ktorym jest ten plik (mcp_server)
FOLDER = Path(__file__).resolve().parent
load_dotenv(FOLDER.parent / ".env")

# model mozna zmienic w .env, domyslnie flash bo jest szybki i tani
MODEL = os.getenv("GEMINI_MODEL", "gemini-3.5-flash")

# instrukcja dla modelu - ma odpowiadac tylko na podstawie danych z narzedzi
SYSTEM_PROMPT = (
    "You are an analyst of Polish county-level macroeconomic data (GUS, 2018-2024). "
    "Answer ONLY from the tools; if data is missing, say so. County names are not unique, "
    "so use search_county and pass the county id. Reply in the language of the question."
)


# funkcja jest async bo biblioteka mcp dziala asynchronicznie
async def zadaj_pytanie(pytanie):
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("Brak GEMINI_API_KEY w pliku .env")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    # mowie jak uruchomic serwer: tym samym pythonem co ten skrypt + sciezka do server.py
    serwer = StdioServerParameters(
        command=sys.executable,
        args=[str(FOLDER / "server.py")],
        env=dict(os.environ),
    )

    # stdio_client odpala server.py w tle i daje kanaly do czytania i pisania
    async with stdio_client(serwer) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # tools=[session] - biblioteka Gemini sama pobiera liste narzedzi z serwera
            # i sama je wywoluje kiedy model o to poprosi
            # config daje jako zwykly slownik a nie types.GenerateContentConfig, bo w google-genai 2.x
            # obiekt jest kopiowany (deepcopy) razem z sesja i wywala blad "cannot pickle '_asyncio.Future'"
            odpowiedz = await client.aio.models.generate_content(
                model=MODEL,
                contents=pytanie,
                config={
                    "system_instruction": SYSTEM_PROMPT,
                    "temperature": 0,  # 0 = mniej losowe odpowiedzi
                    "tools": [session],
                },
            )
            return odpowiedz.text


if __name__ == "__main__":
    # pytanie biore z argumentow w terminalu, jak nic nie podam to jest przykladowe
    if len(sys.argv) > 1:
        pytanie = " ".join(sys.argv[1:])
    else:
        pytanie = "Compare the unemployment of powiat lubelski with the national average in 2024."

    print(asyncio.run(zadaj_pytanie(pytanie)))

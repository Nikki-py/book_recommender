"""Book recommender backend.

A small FastAPI server the Flutter app talks to. It keeps the API keys off the
phone and does the recommendation work (it grew out of bookrecomm.py and
booksrecomm.py).

Run locally:
    pip install -r requirements.txt
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

import math
import os
import re
import time
from functools import lru_cache

import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

load_dotenv()

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
BIGBOOK_API_KEY = os.getenv("BIGBOOK_API_KEY", "")
# Two-letter country code for Google Books (e.g. IN, US). Usually not needed,
# but servers without a known location get a 403 unless it's set.
COUNTRY = os.getenv("COUNTRY", "")

GOOGLE_BOOKS_URL = "https://www.googleapis.com/books/v1/volumes"
BIGBOOK_BASE_URL = "https://api.bigbookapi.com"

# Words each mood adds to the search and to the similarity profile.
MOODS = {
    "cozy": "cozy heartwarming comforting small town friendship gentle",
    "dark": "dark disturbing gothic sinister twisted haunting",
    "fast-paced": "fast-paced thriller gripping suspense action page-turner",
    "emotional": "emotional heartbreaking moving grief love tearjerker",
    "funny": "funny humor witty hilarious comedy",
    "romantic": "romance love relationship swoon",
    "adventurous": "adventure quest journey epic",
    "mysterious": "mystery secrets puzzle whodunit",
}

LENGTHS = {
    "short": (0, 250),
    "medium": (250, 450),
    "long": (450, 100000),
}

SERIES_PATTERN = re.compile(
    r"(\bbook\s+\d+\b|#\s*\d+|\bvol(ume)?\.?\s*\d+\b|\bpart\s+\d+\b|\(.*\bseries\b.*\))",
    re.IGNORECASE,
)

app = FastAPI(title="Book Recommender API")
# Lets the app talk to this server when it runs in a browser (flutter run -d chrome).
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ---------- helpers ----------

def normalize(text):
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", "", text)
    return text.strip()


def title_key(title):
    """Same book, different edition: drop '(Deluxe Edition)', subtitles, etc."""
    title = re.sub(r"\(.*?\)|\[.*?\]", "", title)
    title = title.split(":")[0]
    return normalize(title)


def key_params():
    params = {}
    if GOOGLE_API_KEY:
        params["key"] = GOOGLE_API_KEY
    if COUNTRY:
        params["country"] = COUNTRY
    return params


def google_get(url, params):
    """GET from Google Books, retrying its frequent brief 503s."""
    for attempt in range(4):
        try:
            response = requests.get(url, params=params, timeout=10)
        except requests.RequestException:
            response = None
        if response is not None and response.status_code == 200:
            return response.json()
        if response is not None and response.status_code not in (429, 500, 502, 503):
            return None
        time.sleep(0.4 * (attempt + 1))
    return None


@lru_cache(maxsize=512)
def google_books_cached(query, max_results, order_by):
    params = {
        "q": query,
        "maxResults": max_results,
        "orderBy": order_by,
        "printType": "books",
        "langRestrict": "en",
    }
    params.update(key_params())
    data = google_get(GOOGLE_BOOKS_URL, params)
    if data is None:
        raise LookupError(query)  # not cached, so the next call retries
    return tuple(data.get("items", []))


def google_books(query, max_results=20, order_by="relevance"):
    try:
        return list(google_books_cached(query, max_results, order_by))
    except LookupError:
        return []


def to_book(item):
    """Turn a Google Books volume into the shape the app uses."""
    info = item.get("volumeInfo", {})
    images = info.get("imageLinks", {})
    cover = images.get("thumbnail") or images.get("smallThumbnail") or ""
    cover = cover.replace("http://", "https://")
    isbns = {i.get("type"): i.get("identifier") for i in info.get("industryIdentifiers", [])}
    title = info.get("title", "")
    subtitle = info.get("subtitle", "")
    return {
        "id": item.get("id", ""),
        "title": title,
        "subtitle": subtitle,
        "authors": info.get("authors", []),
        "description": info.get("description", ""),
        "categories": info.get("categories", []),
        "pageCount": info.get("pageCount", 0),
        "publishedDate": info.get("publishedDate", ""),
        "language": info.get("language", ""),
        "averageRating": info.get("averageRating"),
        "ratingsCount": info.get("ratingsCount", 0),
        "coverUrl": cover,
        "buyLink": item.get("saleInfo", {}).get("buyLink", ""),
        "isbn": isbns.get("ISBN_13") or isbns.get("ISBN_10") or "",
        "isSeries": bool(info.get("seriesInfo")) or bool(SERIES_PATTERN.search(f"{title} {subtitle}")),
    }


@lru_cache(maxsize=512)
def fetch_book_cached(book_id):
    data = google_get(f"{GOOGLE_BOOKS_URL}/{book_id}", key_params())
    if data is None:
        raise LookupError(book_id)
    return to_book(data)


def fetch_book(book_id):
    try:
        return fetch_book_cached(book_id)
    except LookupError:
        return None


def genre_words(categories):
    """Most specific genre in each category.

    Google categories look like 'Fiction / Romance / Contemporary', so the
    last part ('Contemporary') says the most.
    """
    words = []
    for category in categories:
        parts = [p.strip() for p in category.split("/") if p.strip().lower() not in ("", "general")]
        if parts and parts[-1] not in words:
            words.append(parts[-1])
    return words


def is_fiction(book):
    return any("fiction" in c.lower() for c in book["categories"])


def bigbook_titles(genre):
    """Extra candidates from Big Book's genre search (as in bookrecomm.py)."""
    if not BIGBOOK_API_KEY:
        return []
    params = {"api-key": BIGBOOK_API_KEY, "genres": genre.lower().replace(" ", "_")}
    try:
        response = requests.get(f"{BIGBOOK_BASE_URL}/search-books", params=params, timeout=10)
        data = response.json()
    except (requests.RequestException, ValueError):
        return []
    return [group[0]["title"] for group in data.get("books", []) if group]


def book_text(book):
    return " ".join(
        [book["title"], " ".join(book["authors"]), " ".join(book["categories"]), book["description"]]
    )


def passes_filters(book, genre, length, series):
    if genre:
        joined = " ".join(book["categories"]).lower()
        if genre.lower() not in joined:
            return False
    if length:
        low, high = LENGTHS[length]
        pages = book["pageCount"] or 0
        if not pages or not (low <= pages < high):
            return False
    if series == "standalone" and book["isSeries"]:
        return False
    if series == "series" and not book["isSeries"]:
        return False
    return True


# ---------- endpoints ----------

@app.get("/health")
def health():
    return {"ok": True}


@app.get("/search")
def search(q: str):
    """Autocomplete: books matching what the user has typed so far."""
    if len(q.strip()) < 2:
        return []
    query = normalize(q)
    results, seen = [], set()
    for b in (to_book(item) for item in google_books(q, max_results=20)):
        key = (title_key(b["title"]), tuple(b["authors"][:1]))
        if b["title"] and key not in seen and b["language"] in ("en", ""):
            seen.add(key)
            results.append(b)

    def rank(b):
        title = normalize(b["title"])
        full = f"{title} {normalize(' '.join(b['authors']))}"
        return (
            title.startswith(query) or query in title,  # typed text is in the title
            all(word in full for word in query.split()),  # every word matches title/author
            bool(b["coverUrl"]),
            b["ratingsCount"] or 0,
        )

    results.sort(key=rank, reverse=True)
    return results[:8]


@app.get("/book/{book_id}")
def book(book_id: str):
    found = fetch_book(book_id)
    if found is None:
        raise HTTPException(status_code=404, detail="Book not found")
    return found


@app.get("/author")
def author_books(name: str, exclude: str = ""):
    """More by this author, including other books in the same series."""
    books = [to_book(item) for item in google_books(name, max_results=40)]
    books = [b for b in books if any(name.lower() == a.lower() for a in b["authors"])]
    seen = {title_key(exclude)} if exclude else set()
    results = []
    for b in books:
        key = title_key(b["title"])
        if not b["title"] or key in seen:
            continue
        seen.add(key)
        results.append(b)
    return results


@app.get("/popular")
def popular(genre: str, limit: int = 20):
    """Well-loved books in a genre: for Explore and the "pick books you've loved" page."""
    books, seen = [], set()
    for b in (to_book(item) for item in google_books(f"{genre} novel", max_results=40)):
        key = title_key(b["title"])
        if b["title"] and b["coverUrl"] and key not in seen and b["language"] in ("en", ""):
            seen.add(key)
            books.append(b)
    books.sort(key=lambda b: b["ratingsCount"] or 0, reverse=True)
    return books[:limit]


class RecommendRequest(BaseModel):
    book_ids: list[str]
    mood: str | None = None
    genre: str | None = None
    length: str | None = None  # short | medium | long
    series: str | None = None  # standalone | series
    exclude_ids: list[str] = []  # books already on the user's shelf
    limit: int = 10


@app.post("/recommend")
def recommend(req: RecommendRequest):
    if not req.book_ids:
        raise HTTPException(status_code=400, detail="Pick at least one book")
    if req.length and req.length not in LENGTHS:
        raise HTTPException(status_code=400, detail="length must be short, medium or long")

    seeds = [b for b in (fetch_book(i) for i in req.book_ids) if b]
    if not seeds:
        raise HTTPException(status_code=404, detail="Couldn't find those books")

    mood_words = MOODS.get(req.mood or "", "")

    # 1. Gather candidates: same genres, same authors, mood, Big Book genre search.
    mood_term = mood_words.split()[0] if mood_words else ""
    # Plain-text queries: Google's subject:/inauthor: operators return nothing
    # from some regions, while plain words work everywhere.
    kind = "novel" if all(is_fiction(s) for s in seeds) else "book"
    queries = []
    for seed in seeds:
        for word in genre_words(seed["categories"])[:4]:
            if word.lower() != "fiction":
                queries.append(f"{word} {kind} {mood_term}".strip())
        for author in seed["authors"][:1]:
            queries.append(author)
    if req.genre:
        queries.append(f"{req.genre} {kind} {mood_term}".strip())
    if mood_words:
        queries.append(f"{' '.join(mood_words.split()[:2])} {kind}")
    if not queries:
        queries.append(seeds[0]["title"])

    candidates = {}
    for query in dict.fromkeys(queries):
        for item in google_books(query, max_results=30):
            b = to_book(item)
            if b["id"] and b["title"]:
                candidates.setdefault(b["id"], b)

    for seed in seeds[:2]:
        for word in genre_words(seed["categories"])[:1]:
            for title in bigbook_titles(word)[:5]:
                for item in google_books(title, max_results=1):
                    b = to_book(item)
                    candidates.setdefault(b["id"], b)

    # 2. Drop the seeds, books on the shelf, duplicates, and anything that fails the filters.
    skip_ids = set(req.book_ids) | set(req.exclude_ids)
    seed_titles = {title_key(s["title"]) for s in seeds}
    want_fiction = all(is_fiction(s) for s in seeds)
    pool, seen_titles = [], set()
    for b in candidates.values():
        key = title_key(b["title"])
        if b["id"] in skip_ids or key in seed_titles or key in seen_titles:
            continue
        if not b["description"] or b["language"] not in ("en", ""):
            continue
        if 0 < b["pageCount"] < 100:  # pamphlets, colouring books, samples
            continue
        if want_fiction and not is_fiction(b):
            continue
        if not passes_filters(b, req.genre, req.length, req.series):
            continue
        seen_titles.add(key)
        pool.append(b)

    if not pool:
        return []

    # 3. Rank by how similar each description is to the seeds (plus the mood).
    profile = " ".join(book_text(s) for s in seeds) + " " + mood_words
    vectorizer = TfidfVectorizer(stop_words="english")
    matrix = vectorizer.fit_transform([profile] + [book_text(b) for b in pool])
    scores = cosine_similarity(matrix[0:1], matrix[1:]).flatten()

    seed_authors = {a.lower() for s in seeds for a in s["authors"]}
    seed_genres = {w.lower() for s in seeds for w in genre_words(s["categories"])}
    ranked = []
    for b, score in zip(pool, scores):
        reasons = []
        if seed_authors & {a.lower() for a in b["authors"]}:
            reasons.append("Same author")
        shared = (seed_genres & {w.lower() for w in genre_words(b["categories"])}) - {"fiction"}
        if shared:
            reasons.append(f"Also {sorted(shared)[0]}")
        if score > 0.15:
            reasons.append(f"Similar to {seeds[0]['title']}")
        # Small nudges for the same author and for books lots of people have rated.
        score += 0.05 if "Same author" in reasons else 0
        score += 0.02 * math.log10(1 + (b["ratingsCount"] or 0))
        ranked.append({**b, "score": round(float(score), 3), "reasons": reasons})

    ranked.sort(key=lambda b: b["score"], reverse=True)
    return ranked[: req.limit]

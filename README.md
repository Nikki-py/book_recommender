# TBR

A Flutter phone app that recommends books from ones you liked, and keeps two shelves: books you've read and your TBR.
The design is in `app-planning/design-spec.md` in the project.

```
book_recommender/
  backend/            Python server: book search + recommendations (keeps API keys off the phone)
  lib/
    main.dart         decides what to show: welcome (signed out), personalise (new account), or the app
    app_scope.dart    hands the signed-in user's services and profile to every screen
    theme/            colours (nikki's palette), fonts, light + dark themes
    screens/          welcome, sign up/log in, personalise slides, pick books, home, explore, shelves, profile
    widgets/          book pop-up, fairy lights + wood, book parade (onboarding), covers, pills
    data/options.dart genres, vibes, book kinds and the quotes (edit these freely)
    models/           Book, ShelfBook, UserProfile
    services/         BookApi (talks to backend), AuthService (sign-in), ShelfService (shelves), ProfileService
    utils/series.dart spots the series in titles like "Heir of Fire (Throne of Glass, #3)"
    config.dart       where the backend is running
  firestore.rules     who can read/write what in the database
```

## One-time setup

### 1. Generate the Android and iOS folders
```bash
cd ~/flutter_projects/book_recommender
flutter upgrade                      # the Firebase packages need a recent Flutter
flutter create --platforms=android,ios --org com.nikki .
flutter pub get
```
`flutter create .` only adds missing files; it won't touch the code that's already here.

### 2. Run the book server
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env                 # then open .env and paste your API keys
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Check it at http://localhost:8000/docs, where you can try every endpoint in the browser.

Your old scripts had the keys written in the code. If that code was ever shared or pushed, make new keys (Google Cloud console → APIs & Services → Credentials, and your Big Book dashboard) and put the new ones in `.env`.

### 3. Connect Firebase
1. Go to https://console.firebase.google.com, create a project (Analytics can be off).
2. **Authentication** → Get started → enable **Email/Password**.
3. **Firestore Database** → Create database → pick a region near you → start in **production mode**.
   Then open the **Rules** tab, paste in the contents of `firestore.rules`, and Publish.
4. On your Mac:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure              # pick your project, choose android + ios
   ```
   This creates `lib/firebase_options.dart`. It's in `.gitignore`, so it won't end up on GitHub.

Everything above is on Firebase's free plan.

### 4. Run the app
```bash
flutter pub get                                                # once, after new code arrives
flutter run                                                    # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000   # iOS simulator
```
On a real phone, use your Mac's Wi-Fi IP address instead (System Settings → Wi-Fi → Details), for example `--dart-define=API_BASE_URL=http://192.168.1.20:8000`.

You should see the TBR welcome screen. Tap **Let's go**, sign up, and you'll go through the personalise slides and "Pick books you've loved". If the covers don't load, the book server isn't reachable: check step 2 and the `API_BASE_URL`.

## Backend endpoints

| Endpoint | What it does |
|---|---|
| `GET /search?q=...` | Autocomplete: up to 8 books matching what's typed |
| `GET /book/{id}` | One book's details |
| `GET /author?name=...&exclude=...` | More by this author |
| `GET /popular?genre=...&limit=20` | Well-loved books in a genre (Explore and "Pick books you've loved") |
| `POST /recommend` | Recommendations. Body: `book_ids` (1 or more), optional `mood`, `genre`, `length` (short/medium/long), `series` (standalone/series), `exclude_ids` (books already on the shelf) |

How recommendations work: the server gathers candidates from Google Books (same genres, same authors, mood words, plus Big Book's genre search), drops books already on your shelf and anything that fails your filters, then ranks the rest by how similar their descriptions are to your books (TF-IDF + cosine similarity, like your original script). Each pick comes back with a short reason like "Same author".

## Database layout (Firestore)

```
users/{uid}                 displayName, email, createdAt, onboarded, genres, vibes, kinds,
                            lovedBookIds, yearlyGoal, themeMode, twinkle
users/{uid}/shelf/{bookId}  title, authors, coverUrl, pageCount, categories, shelf (read | tbr),
                            reading, seriesName, seriesNumber, rating (1-5 or null),
                            note (null unless written), position, addedAt, finishedAt
```

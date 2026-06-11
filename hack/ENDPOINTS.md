# Flibusta API — Complete Endpoint Reference

> Auto-generated from live site exploration. Base URL from `.env`.

## 1. BOOKS (`/b/`)

| Endpoint           | Method | Auth | Description                 |
| ------------------ | ------ | ---- | --------------------------- |
| `/b`               | GET    | No   | Book index (alphabetical)   |
| `/b/{id}`          | GET    | No   | Book details page           |
| `/b/{id}/read`     | GET    | No   | Read online (HTML viewer)   |
| `/b/{id}/download` | GET    | No   | Download page (all formats) |
| `/b/{id}/fb2`      | GET    | No   | Direct FB2 download         |
| `/b/{id}/epub`     | GET    | No   | Direct EPUB download        |
| `/b/{id}/mail`     | POST   | Yes  | Send book to email          |
| `/b/{id}/complain` | GET    | Yes  | Complain about file quality |

### Book details page (`/b/{id}`) — parsed fields:

- `title` — from second `<h1>` (first is site name "Флибуста")
- `description` — after `<h2>Аннотация</h2>` siblings
- `cover_url` — `<img>` with "cover" in src
- `authors` — `/a/{id}` links BEFORE download links
- `genres` — `/g/{id}` links BEFORE download links
- `formats` — `/b/{id}/{format}` links (fb2, epub, mobi, etc.)
- `series` — `/s/{id}` or `/sequence/{id}` links
- `download_urls` — all `/b/{id}/{format}` hrefs

### Book mail form (`/b/{id}/mail`):

```
POST /b/{id}/mail
  select: to = [user_email]
  select: format = [fb2, html, txt, rtf, epub, mobi]
  submit: bookmailFormParams = Отправить
```

### Book polka form (`/polka/add/{id}`):

```
POST /polka/add/{id}
  checkbox: flag = on
  submit: = Сохранить отзыв
```

---

## 2. AUTHORS (`/a/`)

| Endpoint         | Method | Auth | Description                           |
| ---------------- | ------ | ---- | ------------------------------------- |
| `/a`             | GET    | No   | Authors index (alphabetical)          |
| `/a/all`         | GET    | No   | All authors list                      |
| `/a/{id}`        | GET    | No   | Author page with books                |
| `/a/{id}/all`    | GET    | No   | Author all books (same as `/a/{id}`)  |
| `/a/{id}/series` | GET    | No   | Author series                         |
| `/{Letter}`      | GET    | No   | Authors by letter (e.g. `/Aa`, `/Bb`) |

### Author page (`/a/{id}`) — forms:

```
GET /a/{id}
  hidden: hg1 = 1
  checkbox: hg = 1          # Include ghosts
  hidden: sa1 = 1
  checkbox: sa = 1           # Include translations
  hidden: hr1 = 1
  select: lang = [__:Все языки, ...]
  select: order = [a:алфавиту, b:сериям, t:дате поступления]

POST /a/{id}
  checkbox: bchk{id} =       # Select books
  submit: readedall = Отметить выбранное как прочитанное
  submit: bookscomp = Сравнить две выбранные книги
```

---

## 3. SERIES (`/s/`, `/sequence/`)

| Endpoint             | Method | Auth | Description               |
| -------------------- | ------ | ---- | ------------------------- |
| `/s`                 | GET    | No   | Series index with filters |
| `/s/{id}`            | GET    | No   | Series page with books    |
| `/sequence/{id}`     | GET    | No   | Series page (alias)       |
| `/sequence/{id}/all` | GET    | No   | All books in series       |

### Series index (`/s`) — filters:

```
GET /s/
  radio: order = [a:алфавиту, b:количеству книг]
  checkbox: type1 =           # Тип 1
  checkbox: type2 =           # Тип 2
  checkbox: type3 =           # Тип 3
```

### Series page (`/s/{id}`) — sort:

```
GET /s/{id}
  hidden: sa1 = 1
  checkbox: sa = 1
  select: order = [o:порядку, a:алфавиту, t:дате поступления]
```

---

## 4. GENRES (`/g/`)

| Endpoint      | Method | Auth | Description             |
| ------------- | ------ | ---- | ----------------------- |
| `/g`          | GET    | No   | Genre list (all genres) |
| `/g/{id}`     | GET    | No   | Genre page with books   |
| `/g/{id}/all` | GET    | No   | All books in genre      |

### Genre page (`/g/{id}`) — sort:

```
GET /g/{id}
  radio: order = [a:алфавиту, b:автору, t:дате, p:популярности]
```

---

## 5. SEARCH

| Endpoint                              | Method | Auth | Description            |
| ------------------------------------- | ------ | ---- | ---------------------- |
| `/booksearch?ask={q}&chb=on`          | GET    | No   | Search books by name   |
| `/booksearch?ask={q}&cha=on`          | GET    | No   | Search authors by name |
| `/booksearch?ask={q}&chs=on`          | GET    | No   | Search series by name  |
| `/booksearch?ask={q}&chg=on`          | GET    | No   | Search genres by name  |
| `/booksearch?ask={q}&page={n}&chb=on` | GET    | No   | Search books paginated |
| `/comp`                               | GET    | No   | Compare two books      |

### Compare form (`/comp`):

```
GET /comp
  text: b1 =                 # Book ID 1
  text: b2 =                 # Book ID 2
```

---

## 6. OPDS

| Endpoint                                                            | Method | Auth | Description              |
| ------------------------------------------------------------------- | ------ | ---- | ------------------------ |
| `/opds/`                                                            | GET    | No   | OPDS root catalog        |
| `/opds/popular`                                                     | GET    | No   | Popular books            |
| `/opds/recent`                                                      | GET    | No   | Recent additions         |
| `/opds/genres`                                                      | GET    | No   | Genre list               |
| `/opds/authors`                                                     | GET    | No   | Author list              |
| `/opds/opensearch?searchTerm={q}&searchType=books&pageNumber={n}`   | GET    | No   | Search books (XML)       |
| `/opds/opensearch?searchType=authors&searchTerm={q}&pageNumber={n}` | GET    | No   | Search authors (XML)     |
| `/opds/author/{id}/alphabet/{page}`                                 | GET    | No   | Author books by alphabet |
| `/opds/genre/{id}/{page}`                                           | GET    | No   | Genre books              |

---

## 7. RECENT / TRACKER

| Endpoint   | Method | Auth | Description      |
| ---------- | ------ | ---- | ---------------- |
| `/new`     | GET    | No   | Recent additions |
| `/tracker` | GET    | No   | Recent comments  |

### Recent additions (`/new`) — filters:

```
GET /new
  checkbox: sa =             # Show all
  select: lang = [__:Все языки, be:белорусский, kk:казахский]
  select: type = [fb2, pdf, djvu, doc, html, epub, mobi, lrf, ...]
  select: sr = [1:Новые и исправленные, 2:Только новые]
```

---

## 8. STATISTICS

| Endpoint   | Method | Auth | Description     |
| ---------- | ------ | ---- | --------------- |
| `/stat`    | GET    | No   | Site statistics |
| `/stat/b`  | GET    | No   | Popular books   |
| `/stat/my` | GET    | Yes  | My statistics   |

---

## 9. USER (authenticated)

| Endpoint           | Method   | Auth | Description         |
| ------------------ | -------- | ---- | ------------------- |
| `/user`            | GET      | Yes  | User accounts       |
| `/user/me`         | GET      | Yes  | My profile          |
| `/user/me/edit`    | POST     | Yes  | Edit profile        |
| `/user/me/watcher` | GET      | Yes  | Watched posts       |
| `/user/me/track`   | GET      | Yes  | Tracking            |
| `/user/me/openid`  | POST     | Yes  | OpenID settings     |
| `/user/{id}`       | GET      | No   | User public profile |
| `/user/login`      | GET/POST | No   | Login page          |
| `/user/register`   | GET      | No   | Registration        |
| `/user/password`   | GET      | No   | Password reset      |
| `/logout`          | GET      | Yes  | Logout              |

### Edit profile form:

```
POST /user/me/edit
  text: mail =               # Email
  password: pass[pass1] =    # New password
  password: pass[pass2] =    # Confirm password
  hidden: form_build_id
  hidden: form_token
```

---

## 10. MESSAGES

| Endpoint                  | Method | Auth | Description              |
| ------------------------- | ------ | ---- | ------------------------ |
| `/messages`               | GET    | Yes  | Inbox                    |
| `/messages/new`           | GET    | Yes  | Compose message          |
| `/messages/new/{user_id}` | GET    | Yes  | Message to specific user |

### New message form:

```
POST /messages/new
  text: recipient =          # Username
  text: subject =            # Subject
  textarea: body =           # Message body
  submit: op = Отправить сообщение
```

---

## 11. BOOKSHELF / POLKA

| Endpoint                     | Method | Auth | Description        |
| ---------------------------- | ------ | ---- | ------------------ |
| `/polka`                     | GET    | No   | Bookshelf root     |
| `/polka/show/{user_id}`      | GET    | No   | User's rated books |
| `/polka/show/all`            | GET    | No   | All reviews        |
| `/polka/add/{book_id}`       | POST   | Yes  | Add review/rating  |
| `/polka/watch/add/{book_id}` | POST   | Yes  | Track book         |

### Polka add form:

```
POST /polka/add/{book_id}
  checkbox: flag = on
  textarea: body =           # Review text
  select: score = [1-5]     # Rating
  submit: = Сохранить отзыв
```

---

## 12. BLACK/WHITE LIST

| Endpoint                 | Method | Auth | Description    |
| ------------------------ | ------ | ---- | -------------- |
| `/bwlist`                | GET    | Yes  | BW list root   |
| `/bwlist/show/{user_id}` | GET    | No   | User's BW list |

---

## 13. RECOMMENDATIONS

| Endpoint                   | Method | Auth | Description               |
| -------------------------- | ------ | ---- | ------------------------- |
| `/rec`                     | GET    | No   | Community recommendations |
| `/rec?view=recs&user={id}` | GET    | No   | User's recommendations    |

### Recommendations form:

```
GET /rec
  hidden/view: view = [recs, new, popular]
  text: author =             # Filter by author
```

---

## 14. FORUM / BLOG

| Endpoint      | Method | Auth | Description |
| ------------- | ------ | ---- | ----------- |
| `/forum`      | GET    | No   | Forum index |
| `/forum/{id}` | GET    | No   | Forum topic |
| `/blog`       | GET    | No   | Blog index  |
| `/blog/{id}`  | GET    | No   | User blog   |
| `/blog/me`    | GET    | Yes  | My blog     |

---

## 15. UPLOAD / CREATE

| Endpoint           | Method | Auth | Description        |
| ------------------ | ------ | ---- | ------------------ |
| `/upload`          | GET    | Yes  | Upload book/author |
| `/node/add`        | GET    | Yes  | Create content     |
| `/node/add/book`   | GET    | Yes  | Add new book       |
| `/node/add/author` | GET    | Yes  | Add new author     |

---

## 16. MISC

| Endpoint               | Method | Auth | Description                    |
| ---------------------- | ------ | ---- | ------------------------------ |
| `/`                    | GET    | No   | Main page                      |
| `/node/{id}`           | GET    | No   | Static page (FAQ, rules, etc.) |
| `/comment/{id}`        | GET    | No   | Comment permalink              |
| `/dostup`              | POST   | Yes  | Access through block           |
| `/catalog/catalog.zip` | GET    | No   | Download full catalog          |
| `/sql/`                | GET    | No   | Database files                 |
| `/daily/`              | GET    | No   | Update files                   |
| `/book`                | GET    | No   | Advanced search                |
| `/{Letter}`            | GET    | No   | Authors by letter              |

---

## 17. NEWLY DISCOVERED

| Endpoint                      | Method | Auth | Description                           |
| ----------------------------- | ------ | ---- | ------------------------------------- |
| `/a/{id}/rss`                 | GET    | No   | Author RSS feed (application/rss+xml) |
| `/a/{id}/forum`               | GET    | No   | Author's forum posts                  |
| `/blog/{id}/feed`             | GET    | No   | Blog RSS feed (application/rss+xml)   |
| `/b/{id}/delalias/{alias_id}` | GET    | Yes  | Delete book alias                     |
| `/bwlist/black/{user_id}`     | GET    | Yes  | User's black list (filtered)          |
| `/bwlist/white/{user_id}`     | GET    | Yes  | User's white list (filtered)          |
| `/bwlist/use/black/{token}`   | POST   | Yes  | Import black list via token           |
| `/bwlist/use/white/{token}`   | POST   | Yes  | Import white list via token           |
| `/book`                       | GET    | No   | Advanced search form                  |

---

## PARSING NOTES

### HTML Search Results

- Results are in `<ul>` inside `#main` that contains `<a href="/b/...">` links
- Each `<li>` has: book link, author links, series info
- Pagination in `div.item-list .pager`

### OPDS XML

- Namespace: `http://www.w3.org/2005/Atom`
- Entries in `<entry>` elements
- Downloads filtered by MIME type set
- Cover from `<link type="image/jpeg">` or `<link type="image/png">`

### Book Details Page

- Title: second `<h1>` (first is "Флибуста")
- Description: after `<h2>Аннотация</h2>`
- Authors/genres: links BEFORE `/b/{id}/download` or `/b/{id}/read`
- Sidebar content comes AFTER download links

### Author Page Filters

- `hg` = include ghost authorships
- `sa` = include translations
- `lang` = filter by language
- `order` = sort order (a=alpha, b=series, t=date)

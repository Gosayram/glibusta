#!/usr/bin/env python3
"""
Flibusta API Explorer
Для исследования возможностей ресурса
"""

import os
import json
import re
import sys
from pathlib import Path
from typing import Any

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# Конфигурация
OUTPUT_DIR = Path("/tmp/flibusta_pars")
OUTPUT_DIR.mkdir(exist_ok=True)

# Загрузка URL из .env
def load_base_url() -> str:
    env_path = Path(__file__).parent.parent / ".env"
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                if line.startswith("BASE_URL="):
                    return line.split("=", 1)[1].strip()
    return "http://flibusta.is"

BASE_URL = load_base_url()

# Сессия для куки
session = requests.Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
})

def save_result(name: str, data: Any) -> None:
    """Сохранить результат в JSON"""
    filepath = OUTPUT_DIR / f"{name}.json"
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"[+] Saved: {filepath}")

def save_html(name: str, html: str) -> None:
    """Сохранить HTML"""
    filepath = OUTPUT_DIR / f"{name}.html"
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"[+] Saved: {filepath}")

def test_endpoint(path: str, name: str) -> dict:
    """Тестировать эндпоинт"""
    url = urljoin(BASE_URL, path)
    print(f"\n[*] Testing: {url}")
    
    try:
        resp = session.get(url, timeout=15, verify=False)
        print(f"    Status: {resp.status_code}")
        print(f"    Content-Type: {resp.headers.get('Content-Type', 'N/A')}")
        
        result = {
            "url": url,
            "status": resp.status_code,
            "content_type": resp.headers.get("Content-Type"),
            "length": len(resp.text),
            "headers": dict(resp.headers),
        }
        
        # Сохраняем HTML
        save_html(name, resp.text)
        
        return result
    except Exception as e:
        print(f"    Error: {e}")
        return {"url": url, "error": str(e)}

def explore_main_page() -> None:
    """Исследовать главную страницу"""
    print("\n" + "="*60)
    print("1. ГЛАВНАЯ СТРАНИЦА")
    print("="*60)
    
    result = test_endpoint("/", "main_page")
    
    # Ищем ссылки на регистрацию/логин
    soup = BeautifulSoup(open(OUTPUT_DIR / "main_page.html"), "html.parser")
    
    auth_links = []
    for link in soup.find_all("a", href=True):
        href = link["href"].lower()
        text = link.get_text(strip=True).lower()
        if any(w in href + text for w in ["login", "signin", "auth", "register", "signup", "войти", "регистр", "вход"]):
            auth_links.append({"href": link["href"], "text": link.get_text(strip=True)})
    
    if auth_links:
        print("\n[+] Найдены ссылки на авторизацию:")
        for link in auth_links:
            print(f"    {link['text']}: {link['href']}")
        result["auth_links"] = auth_links
    else:
        print("\n[-] Ссылки на авторизацию не найдены")
    
    save_result("main_page_analysis", result)

def explore_opds() -> None:
    """Исследовать OPDS каталог"""
    print("\n" + "="*60)
    print("2. OPDS КАТАЛОГ")
    print("="*60)
    
    endpoints = [
        "/opds/",
        "/opds/opensearch?searchTerm=test&searchType=books&pageNumber=0",
        "/opds/popular",
        "/opds/recent",
        "/opds/authors",
        "/opds/genres",
    ]
    
    results = []
    for endpoint in endpoints:
        name = endpoint.replace("/", "_").replace("?", "_").replace("&", "_")[:50]
        result = test_endpoint(endpoint, f"opds_{name}")
        results.append(result)
    
    save_result("opds_endpoints", results)

def explore_search() -> None:
    """Исследовать поиск"""
    print("\n" + "="*60)
    print("3. ПОИСК")
    print("="*60)
    
    search_queries = [
        "/booksearch?ask=тест&chb=on",
        "/authorsearch?ask=тест",
        "/series?search=тест",
        "/genres?search=тест",
    ]
    
    results = []
    for query in search_queries:
        name = query.split("?")[0].replace("/", "_")
        result = test_endpoint(query, f"search_{name}")
        
        # Парсим результаты
        if "error" not in result:
            soup = BeautifulSoup(open(OUTPUT_DIR / f"search_{name}.html"), "html.parser")
            items = soup.find_all("li")
            result["items_count"] = len(items)
        
        results.append(result)
    
    save_result("search_endpoints", results)

def explore_book_details() -> None:
    """Исследовать детали книги"""
    print("\n" + "="*60)
    print("4. ДЕТАЛИ КНИГИ")
    print("="*60)
    
    # Пробуем найти книгу из предыдущих результатов
    book_ids = ["12345", "1", "100", "1000"]
    
    results = []
    for book_id in book_ids:
        result = test_endpoint(f"/b/{book_id}", f"book_{book_id}")
        
        if "error" not in result:
            soup = BeautifulSoup(open(OUTPUT_DIR / f"book_{book_id}.html"), "html.parser")
            
            # Ищем форму логина
            login_forms = soup.find_all("form", action=re.compile(r"login|auth|signin", re.I))
            if login_forms:
                print(f"    [+] Найдена форма логина на странице книги!")
                result["login_forms"] = [
                    {"action": form.get("action"), "method": form.get("method")}
                    for form in login_forms
                ]
        
        results.append(result)
    
    save_result("book_details", results)

def explore_registration() -> None:
    """Исследовать регистрацию"""
    print("\n" + "="*60)
    print("5. РЕГИСТРАЦИЯ/АВТОРИЗАЦИЯ")
    print("="*60)
    
    auth_endpoints = [
        "/user/register",
        "/register",
        "/signup",
        "/auth/register",
        "/user/login",
        "/login",
        "/signin",
        "/auth/login",
        "/node/login",
    ]
    
    results = []
    for endpoint in auth_endpoints:
        name = endpoint.replace("/", "_")
        result = test_endpoint(endpoint, f"auth_{name}")
        results.append(result)
    
    save_result("auth_endpoints", results)

def explore_api_endpoints() -> None:
    """Исследовать API эндпоинты"""
    print("\n" + "="*60)
    print("6. API ЭНДПОИНТЫ")
    print("="*60)
    
    api_endpoints = [
        "/api/v1/books",
        "/api/v1/authors",
        "/api/books",
        "/api/authors",
        "/api/search",
        "/json",
        "/xml",
        "/rss",
        "/feed",
    ]
    
    results = []
    for endpoint in api_endpoints:
        name = endpoint.replace("/", "_")
        result = test_endpoint(endpoint, f"api_{name}")
        results.append(result)
    
    save_result("api_endpoints", results)

def explore_user_features() -> None:
    """Исследовать пользовательские функции"""
    print("\n" + "="*60)
    print("7. ПОЛЬЗОВАТЕЛЬСКИЕ ФУНКЦИИ")
    print("="*60)
    
    user_endpoints = [
        "/user/profile",
        "/profile",
        "/user/settings",
        "/user/library",
        "/user/collections",
        "/user/history",
        "/user/downloads",
        "/user/favorites",
        "/user/wishlist",
        "/user/messages",
        "/user/notifications",
    ]
    
    results = []
    for endpoint in user_endpoints:
        name = endpoint.replace("/", "_")
        result = test_endpoint(endpoint, f"user_{name}")
        results.append(result)
    
    save_result("user_endpoints", results)

def check_opds_structure() -> None:
    """Проверить структуру OPDS каталога"""
    print("\n" + "="*60)
    print("8. СТРУКТУРА OPDS КАТАЛОГА")
    print("="*60)
    
    try:
        resp = session.get(urljoin(BASE_URL, "/opds/"), timeout=15, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # Ищем все ссылки
            links = soup.find_all("a", href=True)
            opds_links = []
            for link in links:
                href = link["href"]
                if "opds" in href or href.startswith("/"):
                    opds_links.append({
                        "href": href,
                        "text": link.get_text(strip=True),
                    })
            
            print(f"[+] Найдено {len(opds_links)} ссылок в OPDS каталоге")
            
            # Сохраняем структуру
            save_result("opds_structure", {
                "total_links": len(opds_links),
                "links": opds_links[:50],  # Первые 50
            })
    except Exception as e:
        print(f"[-] Error: {e}")

def main() -> None:
    """Основная функция"""
    print("="*60)
    print("FLIBUSTA API EXPLORER")
    print("="*60)
    print(f"Base URL: {BASE_URL}")
    print(f"Output: {OUTPUT_DIR}")
    print("="*60)
    
    # Отключаем предупреждения SSL
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    # Запускаем исследования
    explore_main_page()
    explore_opds()
    explore_search()
    explore_book_details()
    explore_registration()
    explore_api_endpoints()
    explore_user_features()
    check_opds_structure()
    
    print("\n" + "="*60)
    print("ИССЛЕДОВАНИЕ ЗАВЕРШЕНО")
    print("="*60)
    print(f"Результаты сохранены в: {OUTPUT_DIR}")
    print("="*60)

if __name__ == "__main__":
    main()

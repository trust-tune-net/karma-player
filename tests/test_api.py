#!/usr/bin/env python3
"""
Test FastAPI search endpoint
"""
import requests
import json

# Test search
print("Testing /api/search endpoint...")
print()

response = requests.post(
    "http://127.0.0.1:3000/api/search",
    json={
        "query": "pink floyd",
        "limit": 5
    }
)

print(f"Status: {response.status_code}")
print()

if response.status_code == 200:
    data = response.json()
    print(f"Query: {data['query']}")
    print(f"SQL: {data['sql_query']}")
    print(f"Total found: {data['total_found']}")
    print(f"Search time: {data['search_time_ms']}ms")
    print()

    if data['results']:
        print("Top results:")
        for r in data['results'][:3]:
            print(f"\n{r['rank']}. {r['torrent']['title'][:70]}")
            print(f"   {r['explanation']}")
            if r['tags']:
                print(f"   Tags: {', '.join(r['tags'])}")
    else:
        print("⚠️  No results found")
else:
    print(f"Error: {response.text}")

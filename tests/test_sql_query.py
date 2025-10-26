#!/usr/bin/env python3
"""
Demo of SQL-like music search interface
"""
from karma_player.models.query import MusicQuery, QueryIntent
from karma_player.services.ai.query_parser import SQLLikeParser, NaturalLanguageToSQL
from datetime import datetime


def demo_sql_like_queries():
    """Demonstrate SQL-like query syntax"""

    print("🎵 SQL-Like Music Search Interface Demo\n")
    print("=" * 70)
    print()

    # Example 1: Basic album search
    print("Example 1: Album search with format filter")
    print("-" * 70)
    sql1 = 'SELECT album WHERE artist="Radiohead" AND year=1997 AND format="FLAC"'
    print(f"Query: {sql1}")
    query1 = SQLLikeParser.parse(sql1)
    print(f"Parsed: {query1}")
    print(f"Natural language: {query1.to_natural_language()}")
    print()

    # Example 2: Track search with quality sorting
    print("Example 2: Track search sorted by seeders")
    print("-" * 70)
    sql2 = 'SELECT track WHERE title="Paranoid Android" AND format="FLAC" ORDER BY seeders DESC LIMIT 10'
    print(f"Query: {sql2}")
    query2 = SQLLikeParser.parse(sql2)
    print(f"Parsed: {query2}")
    print(f"Natural language: {query2.to_natural_language()}")
    print()

    # Example 3: Year range search
    print("Example 3: Artist discography in year range")
    print("-" * 70)
    sql3 = 'SELECT album WHERE artist="Miles Davis" AND year BETWEEN 1955 AND 1965'
    print(f"Query: {sql3}")
    query3 = SQLLikeParser.parse(sql3)
    print(f"Parsed: {query3}")
    print(f"Natural language: {query3.to_natural_language()}")
    print()

    # Example 4: Advanced filters
    print("Example 4: Advanced filters (seeders, source)")
    print("-" * 70)
    sql4 = 'SELECT album WHERE artist="Pink Floyd" AND source="CD" AND seeders>=10 AND format="FLAC"'
    print(f"Query: {sql4}")
    query4 = SQLLikeParser.parse(sql4)
    print(f"Parsed: {query4}")
    print(f"Natural language: {query4.to_natural_language()}")
    print()

    # Example 5: Natural language to SQL conversion
    print("Example 5: Natural language → SQL conversion")
    print("-" * 70)
    natural = "radiohead ok computer flac"
    print(f"Natural language: '{natural}'")
    sql5 = NaturalLanguageToSQL.convert(natural)
    print(f"SQL-like: {sql5}")
    query5 = SQLLikeParser.parse(sql5)
    print(f"Parsed: {query5}")
    print()

    # Example 6: QueryIntent to MusicQuery conversion
    print("Example 6: AI-parsed intent → Executable query")
    print("-" * 70)
    intent = QueryIntent(
        raw_query="find me the best quality radiohead ok computer",
        parsed_at=datetime.now(),
        artist="Radiohead",
        album="OK Computer",
        quality_preference="lossless",
        speed_preference="fast",
        confidence=0.95
    )
    print(f"Raw query: '{intent.raw_query}'")
    print(f"AI parsed: artist='{intent.artist}', album='{intent.album}'")
    print(f"Preferences: quality={intent.quality_preference}, speed={intent.speed_preference}")
    music_query = intent.to_music_query()
    print(f"Executable query: {music_query.to_sql_like()}")
    print()

    print("=" * 70)
    print("✨ All examples demonstrate the SQL-like interface!")
    print()
    print("Benefits:")
    print("  • Expressive: Complex queries in readable syntax")
    print("  • Composable: Natural language → SQL → MusicQuery")
    print("  • Type-safe: Strongly typed with dataclasses")
    print("  • Flexible: Supports WHERE, ORDER BY, LIMIT, etc.")


if __name__ == "__main__":
    demo_sql_like_queries()

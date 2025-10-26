#!/usr/bin/env python3
"""
Test WebSocket endpoint with real-time progress updates
"""
import asyncio
import json
import websockets


async def test_websocket_search():
    """Test WebSocket search with progress updates"""

    print("=" * 80)
    print("🌐 Testing WebSocket Search with Real-Time Progress")
    print("=" * 80)
    print()

    uri = "ws://127.0.0.1:3000/ws/search"

    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to WebSocket server")
            print()

            # Send search request
            request = {
                "query": "pink floyd",
                "format_filter": "FLAC",
                "limit": 5
            }

            print(f"📤 Sending request: {request['query']}")
            if request.get("format_filter"):
                print(f"   Format filter: {request['format_filter']}")
            print()

            await websocket.send(json.dumps(request))

            # Receive messages
            print("📥 Receiving messages:")
            print()

            result_data = None

            async for message in websocket:
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "progress":
                    percent = data.get("percent", 0)
                    message_text = data.get("message", "")
                    bar_length = 30
                    filled = int(bar_length * percent / 100)
                    bar = "█" * filled + "░" * (bar_length - filled)
                    print(f"\r[{bar}] {percent}% - {message_text}", end="", flush=True)

                elif msg_type == "result":
                    print()  # New line after progress bar
                    print()
                    result_data = data.get("data")
                    print("✅ Search completed!")
                    print()
                    break

                elif msg_type == "error":
                    print()
                    print(f"❌ Error: {data.get('message')}")
                    return

            # Display results
            if result_data:
                print(f"Query: {result_data['query']}")
                print(f"SQL: {result_data['sql_query']}")
                print(f"Total found: {result_data['total_found']}")
                print(f"Search time: {result_data['search_time_ms']}ms")
                print()

                if result_data['results']:
                    print("Top results:")
                    print()
                    for r in result_data['results'][:3]:
                        torrent = r['torrent']
                        print(f"{r['rank']}. {torrent['title'][:70]}")
                        print(f"   {r['explanation']}")
                        if r['tags']:
                            print(f"   Tags: {', '.join(r['tags'])}")
                        print()

            print("=" * 80)
            print("✨ WebSocket Test Complete!")
            print("=" * 80)

    except websockets.exceptions.WebSocketException as e:
        print(f"❌ WebSocket error: {e}")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(test_websocket_search())

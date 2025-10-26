#!/usr/bin/env python3
import requests
import json

url = 'http://localhost:9091/transmission/rpc'

# First request to get session ID
response1 = requests.post(url, json={
    'method': 'torrent-get',
    'arguments': {
        'fields': ['id', 'name', 'percentDone', 'status', 'rateDownload', 'rateUpload']
    }
})

# Get session ID from 409 response
session_id = response1.headers.get('X-Transmission-Session-Id')
print(f"Session ID: {session_id}")

# Retry with session ID
response2 = requests.post(url,
    headers={'X-Transmission-Session-Id': session_id},
    json={
        'method': 'torrent-get',
        'arguments': {
            'fields': ['id', 'name', 'percentDone', 'status', 'rateDownload', 'rateUpload']
        }
    }
)

print(f"\nStatus: {response2.status_code}")
data = response2.json()
print(f"\nResponse: {json.dumps(data, indent=2)}")

torrents = data.get('arguments', {}).get('torrents', [])
print(f"\n{len(torrents)} torrents found:")
for t in torrents:
    print(f"  - [{t['id']}] {t['name']} ({t['percentDone']*100:.1f}%)")

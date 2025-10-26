# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for TrustTune Download Daemon
Builds standalone executable bundled with Flutter app
"""

import sys
from pathlib import Path

block_cipher = None

# Get the project root
project_root = Path('.').absolute()

a = Analysis(
    ['karma_player/api/download_daemon.py'],
    pathex=[str(project_root)],
    binaries=[],
    datas=[
        # Include config module
        ('karma_player/config.py', 'karma_player'),
    ],
    hiddenimports=[
        'karma_player',
        'karma_player.config',
        'karma_player.api.download_daemon',
        'karma_player.services',
        'karma_player.services.torrent',
        'karma_player.services.torrent.download_manager',
        'karma_player.models',
        'karma_player.models.torrent',
        'fastapi',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'pydantic',
        'pydantic_core',
        'transmission_rpc',
        'dotenv',
        'python_dotenv',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude unnecessary packages
        'matplotlib',
        'numpy',
        'pandas',
        'pytest',
        'PIL',
        'tkinter',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='trusttune-daemon',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # No console window for end users
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

# Platform-specific settings
if sys.platform == 'darwin':
    # macOS app bundle
    app = BUNDLE(
        exe,
        name='TrustTuneDaemon.app',
        icon=None,
        bundle_identifier='com.trusttune.daemon',
        info_plist={
            'NSHighResolutionCapable': 'True',
            'LSBackgroundOnly': '1',  # Background only app
        },
    )

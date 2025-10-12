# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all, collect_data_files

datas = []
binaries = []
hiddenimports = ['karma_player']

# Collect karma_player files
tmp_ret = collect_all('karma_player')
datas += tmp_ret[0]; binaries += tmp_ret[1]; hiddenimports += tmp_ret[2]

# Collect tiktoken data files (for AI encoding)
datas += collect_data_files('tiktoken')
datas += collect_data_files('tiktoken_ext')
hiddenimports += ['tiktoken_ext.openai_public', 'tiktoken_ext']

# Collect litellm data files (tokenizers, etc)
datas += collect_data_files('litellm')

# Collect certifi CA bundle for HTTPS requests
datas += collect_data_files('certifi')


a = Analysis(
    ['karma_player/cli.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Heavy ML/Data Science libs (not used)
        'matplotlib', 'scipy', 'IPython', 'notebook', 'PIL', 'pandas', 'tkinter',
        'torch', 'tensorflow', 'transformers', 'sklearn', 'scikit-learn',
        'numpy', 'cv2', 'opencv',

        # Testing/Dev tools (not needed in production)
        'pytest', 'unittest', 'doctest', 'pdb', '_pytest',

        # Jupyter/Notebook ecosystem
        'jupyter', 'jupyter_client', 'jupyter_core', 'jupyterlab', 'nbformat',
        'ipykernel', 'ipython_genutils', 'nbconvert', 'notebook',

        # Heavy crypto libs (may break if actually needed)
        'cryptography', 'cffi', 'nacl', 'paramiko', 'pycparser',

        # Database drivers (except sqlite which we use)
        'psycopg2', 'pymysql', 'MySQLdb', 'cx_Oracle', 'pymongo',

        # Web frameworks (not used)
        'flask', 'django', 'fastapi.applications', 'starlette.applications',

        # AWS/Cloud SDKs (not used)
        'boto3', 'botocore', 'google.cloud', 'azure',

        # Misc heavy deps
        'sqlalchemy.dialects.postgresql', 'sqlalchemy.dialects.mysql',
        'xmlrpc', 'ftplib', 'telnetlib', 'imaplib', 'smtplib'
    ],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='karma-player',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

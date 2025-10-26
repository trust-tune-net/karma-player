#!/bin/bash

# TrustTune Startup Script - Split Screen Version
# Shows backend and frontend logs in split screen using tmux

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Emoji support
ROCKET="🚀"
CHECK="✅"
CROSS="❌"
GEAR="⚙️"
MUSIC="🎵"
SEARCH="🔍"
SERVER="🖥️"
WAIT="⏳"

# Session name
SESSION="trusttune"

# Clear screen
clear

echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║         ${MUSIC}  TRUSTTUNE SPLIT-SCREEN LAUNCHER ${MUSIC}           ║"
echo "║                                                            ║"
echo "║          AI-Powered Music Torrent Search Platform         ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}\n"

# Step 1: Kill existing processes
echo -e "${YELLOW}${BOLD}${GEAR} STEP 1: Cleaning up existing processes...${RESET}"
pkill -f "python -m karma_player.api.server" 2>/dev/null
pkill -f "python -m karma_player.api.search_api" 2>/dev/null
pkill -f "python -m karma_player.api.download_daemon" 2>/dev/null
pkill -f "flutter run" 2>/dev/null
tmux kill-session -t $SESSION 2>/dev/null
sleep 1
echo -e "${GREEN}${CHECK} Cleanup complete${RESET}\n"

# Step 2: Install Python dependencies
echo -e "${BLUE}${BOLD}${GEAR} STEP 2: Installing Python dependencies...${RESET}"
poetry install --no-interaction --quiet
echo -e "${GREEN}${CHECK} Dependencies ready${RESET}\n"

# Step 3: Start Search API (Remote)
echo -e "${BLUE}${BOLD}${SEARCH} STEP 3: Starting Search API (Remote)...${RESET}"
echo -e "${CYAN}   Location: /Users/fcavalcanti/dev/karma-player${RESET}"
echo -e "${CYAN}   Port: 3000${RESET}"
echo -e "${CYAN}   Backend: FastAPI + SimpleSearch + Jackett${RESET}\n"

# Clear old logs
> /tmp/trusttune-search-api.log

# Start Search API in background using Poetry
PORT=3000 \
JACKETT_REMOTE_URL="https://trust-tune-trust-tune-jack.62ickh.easypanel.host" \
JACKETT_REMOTE_API_KEY="ugokmbv2cfeghwcsm27mtnjva5ch7948" \
poetry run python -m karma_player.api.search_api > /tmp/trusttune-search-api.log 2>&1 &

SEARCH_API_PID=$!

# Wait for Search API to start
echo -e "${YELLOW}${WAIT} Waiting for Search API to initialize...${RESET}"
sleep 3

# Health check
MAX_ATTEMPTS=10
ATTEMPT=0
SEARCH_API_READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        SEARCH_API_READY=true
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "${YELLOW}   Attempt $ATTEMPT/$MAX_ATTEMPTS...${RESET}"
    sleep 1
done

if [ "$SEARCH_API_READY" = true ]; then
    echo -e "${GREEN}${BOLD}${CHECK} Search API is READY!${RESET}"
    echo -e "${GREEN}   PID: $SEARCH_API_PID${RESET}"
    echo -e "${GREEN}   Endpoint: http://localhost:3000${RESET}\n"
else
    echo -e "${RED}${BOLD}${CROSS} Search API failed to start!${RESET}"
    echo -e "${RED}   Check logs: tail -f /tmp/trusttune-search-api.log${RESET}\n"
    tail -20 /tmp/trusttune-search-api.log
    exit 1
fi

# Step 3b: Start Download Daemon (Local)
echo -e "${BLUE}${BOLD}${GEAR} STEP 3b: Starting Download Daemon (Local)...${RESET}"
echo -e "${CYAN}   Location: /Users/fcavalcanti/dev/karma-player${RESET}"
echo -e "${CYAN}   Port: 3001${RESET}"
echo -e "${CYAN}   Backend: FastAPI + libtorrent${RESET}\n"

# Clear old logs
> /tmp/trusttune-download-daemon.log

# Start Download Daemon in background using Poetry
PORT=3001 \
poetry run python -m karma_player.api.download_daemon > /tmp/trusttune-download-daemon.log 2>&1 &

DOWNLOAD_DAEMON_PID=$!

# Wait for Download Daemon to start
echo -e "${YELLOW}${WAIT} Waiting for Download Daemon to initialize...${RESET}"
sleep 3

# Health check
MAX_ATTEMPTS=10
ATTEMPT=0
DOWNLOAD_DAEMON_READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        DOWNLOAD_DAEMON_READY=true
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "${YELLOW}   Attempt $ATTEMPT/$MAX_ATTEMPTS...${RESET}"
    sleep 1
done

if [ "$DOWNLOAD_DAEMON_READY" = true ]; then
    echo -e "${GREEN}${BOLD}${CHECK} Download Daemon is READY!${RESET}"
    echo -e "${GREEN}   PID: $DOWNLOAD_DAEMON_PID${RESET}"
    echo -e "${GREEN}   Endpoint: http://localhost:3001${RESET}\n"
else
    echo -e "${RED}${BOLD}${CROSS} Download Daemon failed to start!${RESET}"
    echo -e "${RED}   Check logs: tail -f /tmp/trusttune-download-daemon.log${RESET}\n"
    tail -20 /tmp/trusttune-download-daemon.log
    kill $SEARCH_API_PID 2>/dev/null
    exit 1
fi

# Step 4: Launch Split Screen
echo -e "${MAGENTA}${BOLD}${ROCKET} STEP 4: Launching Split-Screen Interface...${RESET}"
echo -e "${CYAN}   Top Pane: Backend API Logs (real-time)${RESET}"
echo -e "${CYAN}   Bottom Pane: Flutter Desktop App${RESET}\n"

echo -e "${YELLOW}${BOLD}   Layout:${RESET}"
echo -e "${WHITE}   ┌─────────────────────────────────────────┐"
echo -e "   │  ${BLUE}BACKEND API LOGS${WHITE} (port 3000)      │"
echo -e "   │─────────────────────────────────────────│"
echo -e "   │  ${MAGENTA}FLUTTER DESKTOP APP${WHITE}              │"
echo -e "   └─────────────────────────────────────────┘${RESET}\n"

echo -e "${YELLOW}${WAIT} Starting tmux session...${RESET}\n"

# Create helper script for colored API logs
cat > /tmp/trusttune-show-api.sh << 'EOFAPI'
#!/bin/bash
echo -e "\033[1;34m╔════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;34m║               BACKEND SERVICES LOGS                        ║\033[0m"
echo -e "\033[1;34m║     Search API (:3000) | Download Daemon (:3001)           ║\033[0m"
echo -e "\033[1;34m╚════════════════════════════════════════════════════════════╝\033[0m"
echo ""
tail -f /tmp/trusttune-search-api.log /tmp/trusttune-download-daemon.log | while IFS= read -r line; do
    if echo "$line" | grep -q "INFO"; then
        echo -e "\033[0;36m$line\033[0m"
    elif echo "$line" | grep -q "WARNING\|warning"; then
        echo -e "\033[1;33m$line\033[0m"
    elif echo "$line" | grep -q "ERROR\|error"; then
        echo -e "\033[0;31m$line\033[0m"
    elif echo "$line" | grep -q "WebSocket\|download\|Download"; then
        echo -e "\033[0;35m$line\033[0m"
    else
        echo "$line"
    fi
done
EOFAPI
chmod +x /tmp/trusttune-show-api.sh

# Create helper script for Flutter
cat > /tmp/trusttune-run-flutter.sh << 'EOFFLUTTER'
#!/bin/bash
cd /Users/fcavalcanti/dev/karma-player/gui
echo -e "\033[1;35m╔════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;35m║                FLUTTER DESKTOP APPLICATION                 ║\033[0m"
echo -e "\033[1;35m║              TrustTune Music Search GUI                    ║\033[0m"
echo -e "\033[1;35m╚════════════════════════════════════════════════════════════╝\033[0m"
echo ""
echo -e "\033[1;33m⏳ Building and launching app...\033[0m"
echo ""
# Clean Flutter build artifacts to avoid symlink issues
flutter clean > /dev/null 2>&1
flutter run -d macos 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -q "Observatory\|Dart VM"; then
        echo -e "\033[0;34m$line\033[0m"
    elif echo "$line" | grep -q "Flutter run\|Built build"; then
        echo -e "\033[0;32m$line\033[0m"
    elif echo "$line" | grep -q "ERROR\|error\|Error\|Exception"; then
        echo -e "\033[0;31m$line\033[0m"
    elif echo "$line" | grep -q "WARNING\|warning\|Warning"; then
        echo -e "\033[1;33m$line\033[0m"
    else
        echo "$line"
    fi
done
EOFFLUTTER
chmod +x /tmp/trusttune-run-flutter.sh

# Start tmux session
tmux new-session -d -s $SESSION

# Split window horizontally (top 40%, bottom 60%)
tmux split-window -v -p 60 -t $SESSION

# Top pane: API logs
tmux select-pane -t $SESSION:0.0
tmux send-keys -t $SESSION:0.0 "/tmp/trusttune-show-api.sh" C-m

# Bottom pane: Flutter app
tmux select-pane -t $SESSION:0.1
tmux send-keys -t $SESSION:0.1 "/tmp/trusttune-run-flutter.sh" C-m

# Set pane titles
tmux select-pane -t $SESSION:0.0 -T "Backend API"
tmux select-pane -t $SESSION:0.1 -T "Flutter App"

# Attach to session
echo -e "${GREEN}${BOLD}${CHECK} Entering split-screen mode...${RESET}\n"
echo -e "${CYAN}${BOLD}   Controls:${RESET}"
echo -e "${WHITE}   • Ctrl+B then ↑/↓  : Switch between panes${RESET}"
echo -e "${WHITE}   • Ctrl+B then [    : Scroll mode (q to exit)${RESET}"
echo -e "${WHITE}   • Ctrl+B then d    : Detach (keeps running)${RESET}"
echo -e "${WHITE}   • 'q' in Flutter   : Quit app and exit${RESET}\n"

sleep 2

# Attach to tmux session
tmux attach-session -t $SESSION

# Cleanup on exit
echo -e "\n${YELLOW}${GEAR} Shutting down...${RESET}"
kill $SEARCH_API_PID 2>/dev/null
kill $DOWNLOAD_DAEMON_PID 2>/dev/null
echo -e "${GREEN}${CHECK} Search API stopped (PID: $SEARCH_API_PID)${RESET}"
echo -e "${GREEN}${CHECK} Download Daemon stopped (PID: $DOWNLOAD_DAEMON_PID)${RESET}"

echo -e "\n${CYAN}${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}${BOLD}  Thanks for using TrustTune! ${MUSIC}${RESET}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${RESET}\n"

#!/bin/bash

# TrustTune Startup Script
# Colorful, instructive launcher for the full stack

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

# Clear screen for fresh start
clear

echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║              ${MUSIC}  TRUSTTUNE LAUNCHER ${MUSIC}                     ║"
echo "║                                                            ║"
echo "║          AI-Powered Music Torrent Search Platform         ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}\n"

# Step 1: Kill existing processes
echo -e "${YELLOW}${BOLD}${GEAR} STEP 1: Cleaning up existing processes...${RESET}"
pkill -f "python -m karma_player.api.server" 2>/dev/null
pkill -f "flutter run" 2>/dev/null
sleep 1
echo -e "${GREEN}${CHECK} Cleanup complete${RESET}\n"

# Step 2: Install Python dependencies
echo -e "${BLUE}${BOLD}${GEAR} STEP 2: Installing Python dependencies...${RESET}"
poetry install --no-interaction --quiet
echo -e "${GREEN}${CHECK} Dependencies ready${RESET}\n"

# Step 3: Start API Server
echo -e "${BLUE}${BOLD}${SERVER} STEP 3: Starting Python API Server...${RESET}"
echo -e "${CYAN}   Location: /Users/fcavalcanti/dev/karma-player${RESET}"
echo -e "${CYAN}   Port: 3000${RESET}"
echo -e "${CYAN}   Backend: FastAPI + SimpleSearch${RESET}\n"

# Start API in background using Poetry (has WebSocket support)
JACKETT_REMOTE_URL="https://trust-tune-trust-tune-jack.62ickh.easypanel.host" \
JACKETT_REMOTE_API_KEY="ugokmbv2cfeghwcsm27mtnjva5ch7948" \
poetry run python -m karma_player.api.server > /tmp/trusttune-api.log 2>&1 &

API_PID=$!

# Wait for API to start
echo -e "${YELLOW}${WAIT} Waiting for API server to initialize...${RESET}"
sleep 3

# Health check
MAX_ATTEMPTS=10
ATTEMPT=0
API_READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        API_READY=true
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "${YELLOW}   Attempt $ATTEMPT/$MAX_ATTEMPTS...${RESET}"
    sleep 1
done

if [ "$API_READY" = true ]; then
    echo -e "${GREEN}${BOLD}${CHECK} API Server is READY!${RESET}"
    echo -e "${GREEN}   PID: $API_PID${RESET}"
    echo -e "${GREEN}   Endpoint: http://localhost:3000${RESET}"
    echo -e "${GREEN}   Logs: /tmp/trusttune-api.log${RESET}\n"

    # Show last few API log lines
    echo -e "${CYAN}${BOLD}   Recent API Logs:${RESET}"
    tail -5 /tmp/trusttune-api.log | while IFS= read -r line; do
        echo -e "${CYAN}   │ ${RESET}$line"
    done
    echo -e "${CYAN}   └─${RESET} (monitor: ${WHITE}tail -f /tmp/trusttune-api.log${RESET})\n"
else
    echo -e "${RED}${BOLD}${CROSS} API Server failed to start!${RESET}"
    echo -e "${RED}   Check logs: tail -f /tmp/trusttune-api.log${RESET}\n"
    tail -20 /tmp/trusttune-api.log
    exit 1
fi

# Step 4: Start Flutter App
echo -e "${MAGENTA}${BOLD}${ROCKET} STEP 4: Launching Flutter Desktop App...${RESET}"
echo -e "${CYAN}   Location: karma-player/gui${RESET}"
echo -e "${CYAN}   Platform: macOS Desktop${RESET}"
echo -e "${CYAN}   Features: Real-time WebSocket updates${RESET}\n"

echo -e "${YELLOW}${BOLD}   TIP:${RESET} ${WHITE}To monitor API logs in real-time, open a new terminal and run:${RESET}"
echo -e "${WHITE}   ${BOLD}tail -f /tmp/trusttune-api.log${RESET}\n"

cd gui

echo -e "${YELLOW}${WAIT} Building and launching app...${RESET}\n"

# Clean Flutter build artifacts to avoid symlink issues
flutter clean > /dev/null 2>&1

# Run Flutter (this will block until app closes)
flutter run -d macos 2>&1 | while IFS= read -r line; do
    # Color specific Flutter output lines
    if echo "$line" | grep -q "An Observatory"; then
        echo -e "${BLUE}$line${RESET}"
    elif echo "$line" | grep -q "Flutter run"; then
        echo -e "${GREEN}$line${RESET}"
    elif echo "$line" | grep -q "ERROR\|error\|Error"; then
        echo -e "${RED}$line${RESET}"
    elif echo "$line" | grep -q "WARNING\|warning\|Warning"; then
        echo -e "${YELLOW}$line${RESET}"
    else
        echo "$line"
    fi
done

FLUTTER_EXIT=$?

# Cleanup on exit
echo -e "\n${YELLOW}${GEAR} Shutting down...${RESET}"
kill $API_PID 2>/dev/null
echo -e "${GREEN}${CHECK} API Server stopped (PID: $API_PID)${RESET}"

echo -e "\n${CYAN}${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}${BOLD}  Thanks for using TrustTune! ${MUSIC}${RESET}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${RESET}\n"

exit $FLUTTER_EXIT

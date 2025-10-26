#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'

# Emojis
ROCKET="🚀"
CHECK="✅"
CROSS="❌"
INFO="ℹ️"
WARNING="⚠️"
PACKAGE="📦"
TAG="🏷️"
PUSH="⬆️"
BUILD="🔨"

# Header
echo -e "${CYAN}${BOLD}"
echo "═══════════════════════════════════════════════════"
echo "   ${ROCKET} TrustTune Release Script ${ROCKET}"
echo "═══════════════════════════════════════════════════"
echo -e "${RESET}"

# Check if on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${RED}${CROSS} Error: Not on main branch (currently on: $CURRENT_BRANCH)${RESET}"
    exit 1
fi
echo -e "${GREEN}${CHECK} On main branch${RESET}"

# Check if working directory is clean
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}${CROSS} Error: Working directory has uncommitted changes${RESET}"
    echo -e "${YELLOW}${INFO} Please commit or stash your changes first${RESET}"
    exit 1
fi
echo -e "${GREEN}${CHECK} Working directory clean${RESET}"

# Get current version
CURRENT_VERSION=$(git tag -l "v*" | sort -V | tail -n 1)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="v0.0.0"
fi
echo -e "${BLUE}${INFO} Current version: ${WHITE}${CURRENT_VERSION}${RESET}"

# Parse version
VERSION_NUM=${CURRENT_VERSION#v}
IFS='.' read -r MAJOR MINOR PATCH <<< "${VERSION_NUM%-*}"
SUFFIX=""
if [[ "$VERSION_NUM" == *"-"* ]]; then
    SUFFIX="-${VERSION_NUM##*-}"
fi

# Calculate next versions
NEXT_PATCH="v${MAJOR}.${MINOR}.$((PATCH + 1))${SUFFIX}"
NEXT_MINOR="v${MAJOR}.$((MINOR + 1)).0${SUFFIX}"
NEXT_MAJOR="v$((MAJOR + 1)).0.0${SUFFIX}"

# Version selection
echo ""
echo -e "${YELLOW}${BOLD}Select version to release:${RESET}"
echo -e "${WHITE}1)${RESET} ${NEXT_PATCH}  ${CYAN}(patch - bug fixes)${RESET}"
echo -e "${WHITE}2)${RESET} ${NEXT_MINOR}  ${CYAN}(minor - new features)${RESET}"
echo -e "${WHITE}3)${RESET} ${NEXT_MAJOR}  ${CYAN}(major - breaking changes)${RESET}"
echo -e "${WHITE}4)${RESET} Custom version"
echo ""
read -p "$(echo -e ${WHITE}Enter choice [1-4]:${RESET} )" VERSION_CHOICE

case $VERSION_CHOICE in
    1) NEW_VERSION=$NEXT_PATCH ;;
    2) NEW_VERSION=$NEXT_MINOR ;;
    3) NEW_VERSION=$NEXT_MAJOR ;;
    4)
        read -p "$(echo -e ${WHITE}Enter custom version \(e.g., v0.2.0-beta\):${RESET} )" CUSTOM_VERSION
        NEW_VERSION=$CUSTOM_VERSION
        ;;
    *)
        echo -e "${RED}${CROSS} Invalid choice${RESET}"
        exit 1
        ;;
esac

# Validate version format
if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${RED}${CROSS} Invalid version format: $NEW_VERSION${RESET}"
    echo -e "${YELLOW}${INFO} Format should be: v1.2.3 or v1.2.3-beta${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}${TAG} Selected version: ${WHITE}${BOLD}${NEW_VERSION}${RESET}"

# Get release notes
echo ""
echo -e "${YELLOW}${BOLD}Enter release description (press Ctrl+D when done):${RESET}"
RELEASE_NOTES=$(cat)

# Summary
echo ""
echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════${RESET}"
echo -e "${MAGENTA}${BOLD}                Release Summary${RESET}"
echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════${RESET}"
echo -e "${WHITE}Version:${RESET}      ${GREEN}${BOLD}${NEW_VERSION}${RESET}"
echo -e "${WHITE}Previous:${RESET}     ${CYAN}${CURRENT_VERSION}${RESET}"
echo -e "${WHITE}Branch:${RESET}       ${BLUE}main${RESET}"
echo -e "${WHITE}Description:${RESET}  ${YELLOW}${RELEASE_NOTES}${RESET}"
echo ""
echo -e "${YELLOW}${BUILD} This will trigger GitHub Actions to:${RESET}"
echo -e "  ${CHECK} Build macOS binary"
echo -e "  ${CHECK} Build Windows binary"
echo -e "  ${CHECK} Build Linux binary"
echo -e "  ${CHECK} Create GitHub Release with all downloads"
echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════${RESET}"
echo ""

# Confirmation
read -p "$(echo -e ${WHITE}${BOLD}Proceed with release? [y/N]:${RESET} )" CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}${CROSS} Release cancelled${RESET}"
    exit 0
fi

# Create and push tag
echo ""
echo -e "${BLUE}${BOLD}${PUSH} Creating and pushing release...${RESET}"
echo ""

# Pull latest to be safe
echo -e "${CYAN}${INFO} Pulling latest changes...${RESET}"
git pull origin main

# Create tag
echo -e "${CYAN}${INFO} Creating tag ${NEW_VERSION}...${RESET}"
git tag -a "${NEW_VERSION}" -m "${RELEASE_NOTES}"

# Push tag
echo -e "${CYAN}${INFO} Pushing tag to origin...${RESET}"
git push origin "${NEW_VERSION}"

# Success
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}   ${ROCKET} Release ${NEW_VERSION} created successfully! ${ROCKET}${RESET}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${YELLOW}${INFO} GitHub Actions is now building your release...${RESET}"
echo -e "${BLUE}${INFO} Track progress at:${RESET}"
echo -e "${WHITE}   https://github.com/trust-tune-net/karma-player/actions${RESET}"
echo ""
echo -e "${BLUE}${INFO} Release will be available at:${RESET}"
echo -e "${WHITE}   https://github.com/trust-tune-net/karma-player/releases/tag/${NEW_VERSION}${RESET}"
echo ""
echo -e "${GREEN}${PACKAGE} Downloads will automatically be available via:${RESET}"
echo -e "${WHITE}   • macOS:   releases/latest/download/TrustTune-macOS.zip${RESET}"
echo -e "${WHITE}   • Windows: releases/latest/download/TrustTune-Windows.zip${RESET}"
echo -e "${WHITE}   • Linux:   releases/latest/download/TrustTune-Linux.tar.gz${RESET}"
echo ""
echo -e "${CYAN}${CHECK} All done! ${ROCKET}${RESET}"

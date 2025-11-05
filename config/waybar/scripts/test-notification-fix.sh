#!/bin/bash

# Test script to verify notification fix prevents duplicates

echo "Testing notification script duplicate prevention..."
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Clean up any existing instances
echo -e "${YELLOW}1. Cleaning up existing processes...${NC}"
pkill -f getnotification.sh
pkill -f "dbus-monitor.*Notifications"
sleep 1

# Remove PID file if it exists
rm -f ~/.config/waybar/store/getnotification.pid

# Check they're gone (allow for no processes to exist)
sleep 1
if pgrep -f getnotification.sh > /dev/null 2>&1; then
    echo -e "${RED}✗ Failed to kill existing getnotification.sh processes${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All getnotification.sh processes killed${NC}"
fi

echo ""
echo -e "${YELLOW}2. Starting notification.sh multiple times...${NC}"

# Start notification.sh 5 times rapidly
for i in {1..5}; do
    ~/.config/waybar/scripts/notification.sh > /dev/null 2>&1 &
    echo "  Started notification.sh instance $i (PID: $!)"
    sleep 0.1
done

sleep 2

echo ""
echo -e "${YELLOW}3. Checking for duplicate getnotification.sh processes...${NC}"

# Count getnotification.sh processes (parent processes only, exclude pipe subshells)
# The pipe in getnotification.sh creates a subshell which appears as a second process
# We only count processes that have notification.sh as parent, not other getnotification.sh
count=0
for pid in $(pgrep -f "getnotification.sh$"); do
    ppid=$(ps -o ppid= -p $pid | tr -d ' ')
    parent_name=$(ps -o comm= -p $ppid 2>/dev/null)
    if [[ "$parent_name" != "getnotification" ]]; then
        count=$((count + 1))
    fi
done

echo "  Found $count parent getnotification.sh process(es) (excluding pipe subshells)"

if [ "$count" -eq 1 ]; then
    echo -e "${GREEN}✓ SUCCESS: Only one getnotification.sh is running!${NC}"
    result=0
elif [ "$count" -eq 0 ]; then
    echo -e "${RED}✗ FAIL: No getnotification.sh process found${NC}"
    result=1
else
    echo -e "${RED}✗ FAIL: Multiple getnotification.sh parent processes detected!${NC}"
    echo ""
    echo "Process list (parent processes only):"
    for pid in $(pgrep -f "getnotification.sh$" 2>/dev/null); do
        ppid=$(ps -o ppid= -p $pid 2>/dev/null | tr -d ' ')
        parent_name=$(ps -o comm= -p $ppid 2>/dev/null)
        if [[ "$parent_name" != "getnotification" ]]; then
            ps -f -p $pid 2>/dev/null
        fi
    done
    result=1
fi

echo ""
echo -e "${YELLOW}4. Checking lock directory...${NC}"

if [ -d ~/.config/waybar/store/getnotification.lock ]; then
    echo -e "${GREEN}✓ Lock directory exists${NC}"
else
    echo -e "${RED}✗ Lock directory not found${NC}"
    result=1
fi

echo ""
echo -e "${YELLOW}5. Cleaning up test processes...${NC}"

# Kill all notification.sh processes we started
pkill -f "notification.sh$"
sleep 1

# getnotification.sh should exit when notification.sh dies or after a moment
pkill -f getnotification.sh
sleep 1

echo -e "${GREEN}✓ Cleanup complete${NC}"

echo ""
echo "================================================"
if [ $result -eq 0 ]; then
    echo -e "${GREEN}TEST PASSED: No duplicates detected!${NC}"
else
    echo -e "${RED}TEST FAILED: Duplicates found or other issues${NC}"
fi
echo "================================================"

exit $result

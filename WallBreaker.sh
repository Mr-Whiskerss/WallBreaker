#!/bin/bash

# WallBreaker - Network Segmentation Testing Tool
# Usage: ./wallbreaker.sh <target_network> [port_range]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo "================================================"
echo "    🧱 WallBreaker v1.0 🧱"
echo "    Network Segmentation Testing Tool"
echo "================================================"
echo ""

# Check if running as root (needed for some scan types)
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}[!] Running without root privileges. Some scan types may be limited.${NC}"
    echo ""
fi

# Check for required tools
command -v nmap >/dev/null 2>&1 || { echo -e "${RED}[!] nmap is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Parse arguments
TARGET_NETWORK=$1
PORT_RANGE=${2:-"1-1000,3389,5985,5986,8080,8443"}

if [ -z "$TARGET_NETWORK" ]; then
    echo "Usage: $0 <target_network> [port_range]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.0/24"
    echo "  $0 10.0.0.0/24 1-65535"
    echo "  $0 172.16.0.0/24 22,80,443,445,3389"
    echo ""
    exit 1
fi

# Get current network info
CURRENT_IP=$(ip route get 1 | awk '{print $7;exit}')
CURRENT_NETWORK=$(ip route | grep "src $CURRENT_IP" | awk '{print $1}')

echo -e "${BLUE}[*] Current IP: $CURRENT_IP${NC}"
echo -e "${BLUE}[*] Current Network: $CURRENT_NETWORK${NC}"
echo -e "${YELLOW}[*] Target Network: $TARGET_NETWORK${NC}"
echo -e "${YELLOW}[*] Port Range: $PORT_RANGE${NC}"
echo ""

# Create output directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="wallbreaker_test_$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}[+] Output directory: $OUTPUT_DIR${NC}"
echo ""

# Function to perform host discovery
discover_hosts() {
    echo -e "${YELLOW}[*] Phase 1: Host Discovery - Testing the wall...${NC}"
    echo "[*] Discovering live hosts on target network..."
    
    nmap -sn -T4 "$TARGET_NETWORK" -oG "$OUTPUT_DIR/host_discovery.gnmap" | tee "$OUTPUT_DIR/host_discovery.txt"
    
    # Extract live hosts
    grep "Status: Up" "$OUTPUT_DIR/host_discovery.gnmap" | awk '{print $2}' > "$OUTPUT_DIR/live_hosts.txt"
    
    LIVE_HOSTS=$(wc -l < "$OUTPUT_DIR/live_hosts.txt")
    echo -e "${GREEN}[+] Found $LIVE_HOSTS live hosts${NC}"
    echo ""
}

# Function to perform port scanning
port_scan() {
    echo -e "${YELLOW}[*] Phase 2: Port Scanning - Looking for cracks...${NC}"
    
    if [ ! -s "$OUTPUT_DIR/live_hosts.txt" ]; then
        echo -e "${RED}[!] No live hosts found. Skipping port scan.${NC}"
        return
    fi
    
    echo "[*] Scanning ports on discovered hosts..."
    echo "[*] This may take a while depending on the number of hosts and ports..."
    echo ""
    
    nmap -Pn -sT -p "$PORT_RANGE" --open -T4 -iL "$OUTPUT_DIR/live_hosts.txt" \
        -oA "$OUTPUT_DIR/port_scan" | tee "$OUTPUT_DIR/port_scan.txt"
    
    echo ""
}

# Function to perform service detection on open ports
service_detection() {
    echo -e "${YELLOW}[*] Phase 3: Service Detection - Analyzing the breach...${NC}"
    
    # Check if any open ports were found
    if ! grep -q "open" "$OUTPUT_DIR/port_scan.nmap" 2>/dev/null; then
        echo -e "${GREEN}[+] No open ports found - The wall is holding strong!${NC}"
        return
    fi
    
    echo "[*] Performing service version detection on open ports..."
    echo ""
    
    nmap -Pn -sV -sC --open -iL "$OUTPUT_DIR/live_hosts.txt" \
        -p "$PORT_RANGE" -oA "$OUTPUT_DIR/service_detection" | tee "$OUTPUT_DIR/service_detection.txt"
    
    echo ""
}

# Function to generate summary report
generate_report() {
    echo -e "${YELLOW}[*] Generating WallBreaker Report${NC}"
    echo ""
    
    REPORT="$OUTPUT_DIR/REPORT.txt"
    
    cat > "$REPORT" << EOF
================================================
🧱 WallBreaker - Network Segmentation Test Report
================================================
Test Date: $(date)
Tester IP: $CURRENT_IP
Tester Network: $CURRENT_NETWORK
Target Network: $TARGET_NETWORK
Port Range Tested: $PORT_RANGE

================================================
FINDINGS SUMMARY
================================================

EOF
    
    # Count results
    LIVE_HOSTS=$(wc -l < "$OUTPUT_DIR/live_hosts.txt" 2>/dev/null || echo "0")
    OPEN_PORTS=$(grep -c "open" "$OUTPUT_DIR/port_scan.nmap" 2>/dev/null || echo "0")
    
    echo "Live Hosts Discovered: $LIVE_HOSTS" >> "$REPORT"
    echo "Total Open Ports Found: $OPEN_PORTS" >> "$REPORT"
    echo "" >> "$REPORT"
    
    if [ "$OPEN_PORTS" -eq 0 ]; then
        cat >> "$REPORT" << EOF
RESULT: ✅ PASS - WALL INTACT
The network segmentation "wall" is holding strong.
No open ports were accessible from the guest network to the main network.

CONCLUSION: Network segmentation appears to be properly configured.

EOF
    else
        cat >> "$REPORT" << EOF
RESULT: ❌ FAIL - WALL BREACHED
Network segmentation "wall" has been compromised!
Open ports are accessible from the guest network to the main network.

SECURITY RISK: Guest WiFi users can potentially access resources on the main network.
This represents a significant security vulnerability that should be addressed immediately.

================================================
DETAILED FINDINGS
================================================

EOF
        
        # Extract open ports details
        if [ -f "$OUTPUT_DIR/port_scan.nmap" ]; then
            echo "Open Ports by Host:" >> "$REPORT"
            echo "" >> "$REPORT"
            grep -B 4 "open" "$OUTPUT_DIR/port_scan.nmap" >> "$REPORT"
        fi
    fi
    
    cat >> "$REPORT" << EOF

================================================
RECOMMENDATIONS
================================================

1. Review firewall rules between guest and main network
2. Ensure proper VLAN separation is configured
3. Verify wireless controller isolation settings
4. Implement strict ACLs between network segments
5. Consider implementing additional access controls
6. Regular testing of network segmentation controls
7. Monitor for unauthorized bridging between networks

================================================
RAW DATA LOCATION
================================================

All scan data and raw output files are located in:
$OUTPUT_DIR/

Files:
- host_discovery.txt : Host discovery results
- live_hosts.txt : List of responsive hosts
- port_scan.* : Port scan results (multiple formats)
- service_detection.* : Service version detection results
- REPORT.txt : This summary report

================================================
TOOL INFORMATION
================================================

Tool: WallBreaker v1.0
Purpose: Network Segmentation Testing
Generated: $(date)

For more information, see the WallBreaker documentation.

EOF
    
    # Display report
    cat "$REPORT"
    
    echo ""
    echo -e "${GREEN}[+] Report saved to: $REPORT${NC}"
}

# Main execution
echo -e "${BLUE}[*] Starting WallBreaker Assessment${NC}"
echo -e "${BLUE}[*] Testing if the segmentation wall can be breached...${NC}"
echo ""

discover_hosts
port_scan
service_detection
generate_report

echo ""
echo -e "${GREEN}[+] WallBreaker Assessment Complete!${NC}"
echo -e "${GREEN}[+] All results saved in: $OUTPUT_DIR/${NC}"
echo ""

# Final summary
if [ -f "$OUTPUT_DIR/port_scan.nmap" ] && grep -q "open" "$OUTPUT_DIR/port_scan.nmap"; then
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  🚨 WALL BREACHED - CRITICAL FINDING  🚨  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo -e "${RED}[!] Open ports detected - Segmentation compromised!${NC}"
    exit 1
else
    echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ WALL INTACT - TEST PASSED  ✅  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
    echo -e "${GREEN}[+] No breaches found - Segmentation is effective${NC}"
    exit 0
fi

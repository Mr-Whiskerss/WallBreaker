#!/bin/bash

################################################################################
# WallBreaker - Network Segmentation Testing Tool
# Version: 1.1 (Enhanced with --no-ping flag)
# Author: Modified by Dan for penetration testing
# Purpose: Validate network segmentation between WiFi networks
#
# LEGAL NOTICE: This tool is for AUTHORIZED security testing only.
# Ensure you have written authorization before use.
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script metadata
VERSION="1.1"
SCRIPT_NAME="WallBreaker"

# Default values
NO_PING=false
TARGET_NETWORK=""
PORT_RANGE="1-1000,3389,5985-5986,8080,8443"

################################################################################
# Function: Print banner
################################################################################
print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      WallBreaker v${VERSION}                      ║"
    echo "║          Network Segmentation Testing Tool                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

################################################################################
# Function: Print usage
################################################################################
usage() {
    cat << EOF
${YELLOW}Usage:${NC}
    $0 [OPTIONS] <target_network> [port_range]

${YELLOW}Arguments:${NC}
    target_network    Target network in CIDR notation (e.g., 192.168.1.0/24)
    port_range        Optional port range (default: 1-1000,3389,5985-5986,8080,8443)

${YELLOW}Options:${NC}
    -n, --no-ping     Skip ping/ICMP host discovery (useful when ICMP is blocked)
                      Uses TCP SYN scan to detect hosts instead
    -h, --help        Display this help message
    -v, --version     Display version information

${YELLOW}Examples:${NC}
    # Standard scan with ping discovery
    sudo $0 192.168.1.0/24

    # Skip ping, use TCP SYN for host detection (useful when ICMP blocked)
    sudo $0 --no-ping 192.168.1.0/24

    # Custom port range with no-ping
    sudo $0 -n 10.0.0.0/24 22,80,443,445,3389

    # Full port scan without ping
    sudo $0 --no-ping 172.16.0.0/24 1-65535

${YELLOW}Common Use Cases:${NC}
    # Guest WiFi → Corporate network testing
    sudo $0 --no-ping 10.0.10.0/24

    # When target blocks ICMP but allows TCP
    sudo $0 -n 192.168.50.0/24 22,445,3389,8080

${YELLOW}Notes:${NC}
    - Requires root/sudo privileges for SYN scans
    - The --no-ping flag uses nmap's -Pn option
    - Without ping, scans may take longer but work when ICMP is filtered
    - Results stored in timestamped directory: wallbreaker_test_YYYYMMDD_HHMMSS/

EOF
}

################################################################################
# Function: Check prerequisites
################################################################################
check_prerequisites() {
    echo -e "${BLUE}[*] Checking prerequisites...${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] This script must be run as root (sudo)${NC}"
        echo -e "${YELLOW}[*] Try: sudo $0 $@${NC}"
        exit 1
    fi
    
    # Check for nmap
    if ! command -v nmap &> /dev/null; then
        echo -e "${RED}[!] nmap is not installed${NC}"
        echo -e "${YELLOW}[*] Install with: sudo apt install nmap${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[✓] Prerequisites check passed${NC}"
}

################################################################################
# Function: Create output directory
################################################################################
create_output_dir() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT_DIR="wallbreaker_test_${TIMESTAMP}"
    
    mkdir -p "$OUTPUT_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!] Failed to create output directory${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[✓] Output directory created: ${OUTPUT_DIR}${NC}"
}

################################################################################
# Function: Host Discovery
################################################################################
host_discovery() {
    echo -e "\n${BLUE}[*] Phase 1: Host Discovery${NC}"
    echo -e "${YELLOW}[*] Target Network: ${TARGET_NETWORK}${NC}"
    
    if [[ "$NO_PING" == true ]]; then
        echo -e "${YELLOW}[*] Mode: No-Ping (TCP SYN scan for host detection)${NC}"
        echo -e "${YELLOW}[*] Note: This assumes all hosts are up and may take longer${NC}"
        
        # Use -Pn to skip ping and treat all hosts as online
        nmap -Pn -sn -T4 "$TARGET_NETWORK" \
            -oA "${OUTPUT_DIR}/host_discovery" \
            > "${OUTPUT_DIR}/host_discovery.txt" 2>&1
    else
        echo -e "${YELLOW}[*] Mode: Standard (ICMP ping discovery)${NC}"
        
        # Standard ping discovery
        nmap -sn -T4 "$TARGET_NETWORK" \
            -oA "${OUTPUT_DIR}/host_discovery" \
            > "${OUTPUT_DIR}/host_discovery.txt" 2>&1
    fi
    
    # Extract live hosts
    if [[ "$NO_PING" == true ]]; then
        # For no-ping mode, we'll scan all hosts in the range
        # Extract network range and create host list
        echo -e "${YELLOW}[*] Preparing all hosts for scanning (no-ping mode)${NC}"
        # This is handled in port_scan function
    else
        grep "Nmap scan report for" "${OUTPUT_DIR}/host_discovery.txt" | \
            awk '{print $5}' > "${OUTPUT_DIR}/live_hosts.txt"
    fi
    
    if [[ "$NO_PING" == true ]]; then
        echo -e "${YELLOW}[*] No-ping mode: Will scan all hosts in network range${NC}"
    else
        HOST_COUNT=$(wc -l < "${OUTPUT_DIR}/live_hosts.txt" 2>/dev/null || echo "0")
        echo -e "${GREEN}[✓] Discovered ${HOST_COUNT} live hosts${NC}"
    fi
}

################################################################################
# Function: Port Scanning
################################################################################
port_scan() {
    echo -e "\n${BLUE}[*] Phase 2: Port Scanning${NC}"
    echo -e "${YELLOW}[*] Port Range: ${PORT_RANGE}${NC}"
    
    if [[ "$NO_PING" == true ]]; then
        echo -e "${YELLOW}[*] Scanning entire network (no-ping mode)${NC}"
        TARGET="$TARGET_NETWORK"
    else
        if [[ ! -s "${OUTPUT_DIR}/live_hosts.txt" ]]; then
            echo -e "${YELLOW}[!] No live hosts found. Scan complete.${NC}"
            return
        fi
        TARGET=$(cat "${OUTPUT_DIR}/live_hosts.txt" | tr '\n' ' ')
    fi
    
    NMAP_FLAGS="-p ${PORT_RANGE} -T4 --open"
    
    if [[ "$NO_PING" == true ]]; then
        NMAP_FLAGS="${NMAP_FLAGS} -Pn"
        echo -e "${YELLOW}[*] Using -Pn flag to skip host discovery${NC}"
    fi
    
    nmap $NMAP_FLAGS $TARGET \
        -oA "${OUTPUT_DIR}/port_scan" \
        > "${OUTPUT_DIR}/port_scan.txt" 2>&1
    
    echo -e "${GREEN}[✓] Port scan complete${NC}"
}

################################################################################
# Function: Service Detection
################################################################################
service_detection() {
    echo -e "\n${BLUE}[*] Phase 3: Service Detection${NC}"
    
    # Check if any open ports were found
    if ! grep -q "open" "${OUTPUT_DIR}/port_scan.txt" 2>/dev/null; then
        echo -e "${YELLOW}[!] No open ports found. Skipping service detection.${NC}"
        return
    fi
    
    echo -e "${YELLOW}[*] Running service version detection on open ports...${NC}"
    
    NMAP_FLAGS="-p ${PORT_RANGE} -sV -T4 --open"
    
    if [[ "$NO_PING" == true ]]; then
        NMAP_FLAGS="${NMAP_FLAGS} -Pn"
        TARGET="$TARGET_NETWORK"
    else
        if [[ ! -s "${OUTPUT_DIR}/live_hosts.txt" ]]; then
            return
        fi
        TARGET=$(cat "${OUTPUT_DIR}/live_hosts.txt" | tr '\n' ' ')
    fi
    
    nmap $NMAP_FLAGS $TARGET \
        -oA "${OUTPUT_DIR}/service_detection" \
        > "${OUTPUT_DIR}/service_detection.txt" 2>&1
    
    echo -e "${GREEN}[✓] Service detection complete${NC}"
}

################################################################################
# Function: Generate Report
################################################################################
generate_report() {
    echo -e "\n${BLUE}[*] Generating Report...${NC}"
    
    REPORT_FILE="${OUTPUT_DIR}/REPORT.txt"
    
    cat > "$REPORT_FILE" << EOF
╔══════════════════════════════════════════════════════════════╗
║              WallBreaker Security Assessment Report          ║
╚══════════════════════════════════════════════════════════════╝

Assessment Date: $(date)
Target Network: ${TARGET_NETWORK}
Port Range: ${PORT_RANGE}
Scan Mode: $([ "$NO_PING" == true ] && echo "No-Ping (TCP SYN)" || echo "Standard (ICMP)")

═══════════════════════════════════════════════════════════════

EXECUTIVE SUMMARY
═════════════════

This assessment tested network segmentation between the current network
and the target network: ${TARGET_NETWORK}

The goal was to identify if proper network isolation exists between
network segments (e.g., Guest WiFi vs. Corporate WiFi).

═══════════════════════════════════════════════════════════════

HOST DISCOVERY RESULTS
══════════════════════

EOF
    
    if [[ "$NO_PING" == true ]]; then
        echo "Mode: No-Ping (Assumed all hosts in range are up)" >> "$REPORT_FILE"
        echo "Note: ICMP was skipped; used TCP SYN for detection" >> "$REPORT_FILE"
    else
        if [[ -f "${OUTPUT_DIR}/live_hosts.txt" ]]; then
            HOST_COUNT=$(wc -l < "${OUTPUT_DIR}/live_hosts.txt")
            echo "Live Hosts Found: ${HOST_COUNT}" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            cat "${OUTPUT_DIR}/live_hosts.txt" >> "$REPORT_FILE"
        else
            echo "No live hosts detected" >> "$REPORT_FILE"
        fi
    fi
    
    cat >> "$REPORT_FILE" << EOF

═══════════════════════════════════════════════════════════════

PORT SCAN RESULTS
═════════════════

EOF
    
    if grep -q "open" "${OUTPUT_DIR}/port_scan.txt" 2>/dev/null; then
        grep -E "open|filtered" "${OUTPUT_DIR}/port_scan.txt" >> "$REPORT_FILE"
    else
        echo "No open ports discovered" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

═══════════════════════════════════════════════════════════════

SERVICE DETECTION RESULTS
══════════════════════════

EOF
    
    if [[ -f "${OUTPUT_DIR}/service_detection.txt" ]]; then
        grep -E "open|filtered" "${OUTPUT_DIR}/service_detection.txt" >> "$REPORT_FILE"
    else
        echo "Service detection not performed (no open ports found)" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

═══════════════════════════════════════════════════════════════

ASSESSMENT RESULT
═════════════════

EOF
    
    # Determine pass/fail
    if grep -q "open" "${OUTPUT_DIR}/port_scan.txt" 2>/dev/null; then
        cat >> "$REPORT_FILE" << EOF
RESULT: FAIL
═══════════════

❌ Network segmentation issues detected!

Open ports are accessible from the guest network to the main network.

SECURITY RISK: Guest WiFi users can potentially access resources on 
the main network. This violates network segmentation best practices.

RECOMMENDATION: Review firewall rules and VLAN configurations to ensure
proper isolation between network segments.

EOF
        RESULT_COLOR="${RED}"
        RESULT_TEXT="FAIL - Segmentation Issues Detected"
    else
        cat >> "$REPORT_FILE" << EOF
RESULT: PASS
════════════

✓ Network segmentation appears to be properly configured.

No open ports were accessible from the guest network to the main network.

The network "wall" is holding - proper isolation exists.

EOF
        RESULT_COLOR="${GREEN}"
        RESULT_TEXT="PASS - Proper Segmentation"
    fi
    
    cat >> "$REPORT_FILE" << EOF

═══════════════════════════════════════════════════════════════

DETAILED SCAN FILES
═══════════════════

All detailed scan results are available in the following files:

- host_discovery.txt / .nmap / .gnmap / .xml
- port_scan.txt / .nmap / .gnmap / .xml
- service_detection.txt / .nmap / .gnmap / .xml

═══════════════════════════════════════════════════════════════

END OF REPORT

EOF
    
    echo -e "${GREEN}[✓] Report generated: ${REPORT_FILE}${NC}"
    echo ""
    echo -e "${RESULT_COLOR}═══════════════════════════════════════${NC}"
    echo -e "${RESULT_COLOR}RESULT: ${RESULT_TEXT}${NC}"
    echo -e "${RESULT_COLOR}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}[*] Full report available at: ${OUTPUT_DIR}/REPORT.txt${NC}"
}

################################################################################
# Main Script Execution
################################################################################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--no-ping)
            NO_PING=true
            shift
            ;;
        -h|--help)
            print_banner
            usage
            exit 0
            ;;
        -v|--version)
            echo "WallBreaker version ${VERSION}"
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_NETWORK" ]]; then
                TARGET_NETWORK="$1"
            elif [[ -z "$PORT_RANGE" ]] || [[ "$PORT_RANGE" == "1-1000,3389,5985-5986,8080,8443" ]]; then
                PORT_RANGE="$1"
            else
                echo -e "${RED}Error: Too many arguments${NC}"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TARGET_NETWORK" ]]; then
    echo -e "${RED}Error: Target network is required${NC}"
    usage
    exit 1
fi

# Main execution
print_banner
check_prerequisites
create_output_dir

echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Starting WallBreaker Network Segmentation Test${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

host_discovery
port_scan
service_detection
generate_report

echo -e "\n${GREEN}[✓] Assessment complete!${NC}"
echo -e "${BLUE}[*] Results saved to: ${OUTPUT_DIR}/${NC}\n"

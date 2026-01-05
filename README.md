# WallBreaker - Network Segmentation Testing Tool

A penetration testing tool designed to validate network segmentation between WiFi networks (Guest vs. Main/Corporate). WallBreaker automates the discovery, scanning, and reporting process to identify segmentation failures that could allow unauthorized access between network segments.

## Purpose

During security assessments, it's critical to verify that guest networks are properly isolated from corporate/main networks. WallBreaker automates this validation by:

- Discovering live hosts on target network segments
- Scanning for accessible ports and services
- Identifying segmentation failures
- Generating detailed reports for clients

## Legal Notice

**AUTHORIZATION REQUIRED**: This tool is intended for authorized security testing only. Ensure you have:
- Written authorization from the network owner
- Clearly defined scope of testing
- Documented testing window
- Appropriate rules of engagement

Unauthorized network scanning may be illegal in your jurisdiction.

##  Prerequisites

### Required Tools
- `nmap` - Network scanning utility
- `bash` - Bourne Again SHell (version 4.0+)
- Standard Linux utilities (`awk`, `grep`, `ip`)

## Tool  Installation
```bash
# Clone or download the script
wget https://your-repo/wallbreaker.sh
# or
curl -O https://your-repo/wallbreaker.sh

# Make executable
chmod +x wallbreaker.sh

# Verify installation
./wallbreaker.sh
```

##  Usage

### Basic Syntax
```bash
./wallbreaker.sh <target_network> [port_range]
```

### Examples

**Standard scan (common ports):**
```bash
./wallbreaker.sh 192.168.1.0/24
```

**Custom port range:**
```bash
./wallbreaker.sh 10.0.0.0/24 22,80,443,445,3389
```

**Full port scan (comprehensive but slow):**
```bash
./wallbreaker.sh 172.16.0.0/24 1-65535
```

**Scan specific administrative ports:**
```bash
./wallbreaker.sh 192.168.50.0/24 22,23,445,3389,5985,5986,8080,8443
```

## 📋 Testing Workflow

### 1. Pre-Test Setup
```bash
# Connect to the Guest WiFi network
# Document your connection details
ip addr show
ip route show

# Identify the target (main) network range
# This should be provided by the client or discovered during reconnaissance
```

### 2. Execute Test
```bash
# Run the segmentation test
./wallbreaker.sh <main_network_range>

# Example: Testing from Guest WiFi (10.0.50.x) to Main WiFi (10.0.10.0/24)
./wallbreaker.sh 10.0.10.0/24
```

### 3. Review Results
```bash
# Navigate to the output directory
cd wallbreaker_test_YYYYMMDD_HHMMSS/

# Read the summary report
cat REPORT.txt

# Review detailed scan data
less port_scan.nmap
less service_detection.nmap
```

## Output Structure

WallBreaker creates a timestamped directory containing:
```
wallbreaker_test_20240105_143022/
├── REPORT.txt                    # Executive summary and findings
├── host_discovery.txt            # Host discovery output
├── host_discovery.gnmap          # Host discovery (grepable format)
├── live_hosts.txt                # List of responsive hosts
├── port_scan.txt                 # Port scan output
├── port_scan.nmap                # Port scan (nmap format)
├── port_scan.gnmap               # Port scan (grepable format)
├── port_scan.xml                 # Port scan (XML format)
├── service_detection.txt         # Service detection output
├── service_detection.nmap        # Service detection (nmap format)
├── service_detection.gnmap       # Service detection (grepable)
└── service_detection.xml         # Service detection (XML format)
```

## Understanding Results

### PASS Result
```
RESULT: PASS
Network segmentation appears to be properly configured.
No open ports were accessible from the guest network to the main network.
```
The "wall" is holding - Guest network is isolated from Main network

### FAIL Result
```
RESULT: FAIL
Network segmentation issues detected!
Open ports are accessible from the guest network to the main network.

SECURITY RISK: Guest WiFi users can potentially access resources on the main network.
```
The "wall" has been broken - Guest users can potentially access Main network resources

## Common Port Ranges

**Default scan includes:**
- 1-1000: Common services
- 3389: RDP (Windows Remote Desktop)
- 5985-5986: WinRM (Windows Remote Management)
- 8080, 8443: Alternative HTTP/HTTPS ports

**Recommended comprehensive scan:**
- 22: SSH
- 23: Telnet
- 80, 443: HTTP/HTTPS
- 135, 139, 445: Windows SMB/NetBIOS
- 1433: MS SQL Server
- 3306: MySQL
- 3389: RDP
- 5432: PostgreSQL
- 5900: VNC
- 5985-5986: WinRM
- 8080, 8443: Alternative web services

##  Troubleshooting

### "nmap: command not found"
```bash
# Install nmap (see Prerequisites section)
sudo apt install nmap  # Debian/Ubuntu
```

### "Permission denied" errors
```bash
# Some scan types require root privileges
sudo ./wallbreaker.sh 192.168.1.0/24
```

### No hosts discovered
- Verify you're on the correct network
- Check target network range is correct
- Some networks may have ICMP blocked (use -Pn flag in nmap)
- Firewall may be blocking host discovery packets

### Scan taking too long
- Reduce port range (scan only critical ports)
- Use faster timing template (already using -T4)
- Reduce target network size if possible


##  License

This tool is provided for authorized security testing only. Use responsibly.

##  Resources

- [Nmap Official Documentation](https://nmap.org/docs.html)
- [OWASP Testing Guide - Network Segmentation](https://owasp.org/www-project-web-security-testing-guide/)
- [PCI DSS Network Segmentation Requirements](https://www.pcisecuritystandards.org/)

---

**Version:** 1.0  
**Last Updated:** January 2026  
**Tool Name:** WallBreaker  
**Purpose:** Authorized Penetration Testing Only

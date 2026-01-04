
# Self-Hosted DNS Resolver 

# So, why would anyone even want their own DNS resolver?

First things first, It's super cool xD

* **Custom Blocklists & "Nuclear Options":**  Manual Control: Instantly block specific domains (e.g., tiktok.com or facebook.com) for productivity or detox.

Automated Lists: Integrate massive community-driven lists (HaGeZi, StevenBlack) to block hundreds of thousands of malicious or explicit domains.

Wildcard Blocking: Block entire TLDs or subdomains with a single rule.

* **Battery & Data Savings:** By blocking ads at the DNS level, your device never downloads heavy tracking scripts, video ads, or banners. This reduces CPU cycles and radio usage, significantly extending battery life on mobile and laptops.

* **Total Privacy:** Your ISP cannot log your browsing history. 

* **App Monitoring:** You can see exactly which background apps are "phoning home" and identify "chatty" telemetry services.

* **Zero-Trust:** You bypass third-party resolvers like Google or Cloudflare. 

## High-Level Architecture

The setup uses a frontend/backend model to isolate encryption from resolution logic:

1. **Client (Mac/Phone):** Sends an encrypted HTTPS request (Port 443) to your domain.
2. **dnsdist (Frontend):** Handles SSL/TLS termination, checks Access Control Lists (ACLs), and monitors traffic.
3. **Unbound (Backend):** Performs recursive lookups by contacting Root, TLD, and Authoritative servers.

---

## CRITICAL SECURITY WARNING

**Never expose Port 53 to `0.0.0.0/0`.** Open DNS resolvers are frequently used in **DNS Amplification Attacks**.

* **Port 53 (UDP/TCP):** Only allow your specific Home IP in the AWS Security Group.
* **Port 443 (TCP):** Safe to open to the world *only* if you have configured a strong `dnsdist` ACL to limit access to your own devices.

---

## 🛠️ Step 1: Infrastructure & Domain

1. **AWS EC2:** Launch a `t3.micro` (Ubuntu). Assign an **Elastic IP**.
2. **Domain:** Use a service like **DuckDNS** to point a subdomain to your Elastic IP.
3. **SSL Certificate:** Generate certificates via Certbot:

```bash
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.duckdns.org

```

---

## 🛠️ Step 2: Installation & Blocklist Setup

1. **Install Packages:**

```bash
sudo apt update && sudo apt install -y dnsdist unbound

```

2. **Initialize Blocklist Directory:**

```bash
sudo mkdir -p /etc/dnsdist/blocklists

```

3. **Deploy the Update Script:**
Create `/usr/local/bin/update-dns-blocklist.sh` using the script provided in this repository. This script handles the "Fetch, Clean, and Reload" cycle:

* **Comment Stripping:** Removes all lines starting with `#`.
* **FQDN Formatting:** Appends a trailing dot (`.`) to every domain (e.g., `example.com.`), required for the high-speed `SuffixMatchNode` engine.
* **Deduplication:** Runs `sort -u` to remove redundant entries across lists, minimizing the RAM footprint.

```bash
sudo chmod +x /usr/local/bin/update-dns-blocklist.sh
sudo /usr/local/bin/update-dns-blocklist.sh

```

---

## 🛠️ Step 3: Configuration

### 1. Unbound (The Brain)

Unbound performs recursive resolution, talking directly to Root Servers. It listens only on `127.0.0.1:5335`.

* **Config:** Refer to the `unbound.conf.d/` directory in this repo.
* **Setup:**

```bash
sudo cp -r unbound.conf.d /etc/unbound/
sudo systemctl restart unbound

```

### 2. dnsdist (The Bouncer)

Handles Access Control, DoH (DNS-over-HTTPS) encryption, and the blocklist engine.

* **Config:** Refer to `dnsdist.conf` in this repo.
* **Permissions:** Ensure the `_dnsdist` user can read your SSL certificates:

```bash
sudo chown _dnsdist:_dnsdist /etc/dnsdist/certs/*.pem

```

* **Validation:**

```bash
sudo dnsdist --check-config
sudo systemctl restart dnsdist

```

---

## 🛠️ Step 4: Client Setup (The Bootstrap)

Because of the "Chicken and Egg" problem (your computer needs DNS to find the IP of your DNS domain), you must perform a one-time bootstrap:

1. **macOS/OS Settings:** Add your **AWS Elastic IP** manually to your System DNS settings. This allows the computer to resolve your domain name to start the HTTPS tunnel.
2. **Secure DNS:** In your browser (Chrome/Firefox) or OS settings, enable **DNS-over-HTTPS** and enter your custom URL:
`https://your-domain.duckdns.org/dns-query`

---

## 🔍 Verification & Testing

### 1. Functional Check

Verify that ads and adult content are being sinkholed correctly by querying the local resolver:

```bash
# Test Ad Block (Should return NXDOMAIN)
dig @127.0.0.1 -p 53 doubleclick.net

# Test Adult Block (Should return REFUSED)
dig @127.0.0.1 -p 53 0xxx.ws

```

### 2. Performance Stress Test

To ensure the `SuffixMatchNode` engine is handling the ~350,000 rules without latency spikes, run a benchmark from your local machine:

```bash
dnspyre -s YOUR_AWS_PUBLIC_IP -n 100 --duration 60s google.com

```

---

## Analytics & Monitoring

To monitor queries in real-time and see which apps are active in the background:

```bash
# Watch the live log
sudo journalctl -u dnsdist -f

# Enter the interactive console (if configured)
sudo dnsdist -c 127.0.0.1:8083 -a <your_key>

```

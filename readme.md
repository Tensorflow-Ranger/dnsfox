
# Self-Hosted DNS Resolver 

# So, why would anyone even want their own DNS resolver?

First things first, It's super cool xD

* **Custom Blocklists & "Nuclear Options":**  Manual Control: Instantly block specific domains (e.g., tiktok.com or facebook.com) for productivity or detox.

     * Automated Lists: Integrate massive community-driven lists (HaGeZi, StevenBlack) to block hundreds of thousands of malicious or explicit domains.

     * Wildcard Blocking: Block entire TLDs or subdomains with a single rule.

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

## Issues with Captive Portal 

If you face issues with your captive portal while logging into wifi due to the private DNS configuration, use dnsfox.sh to automatically enable and disable the private dns settings. 

NOTE: The given script is specific to MacOS. 

## How do I configure my iPhone to use the private DNS?
Use https://dns.notjakob.com/finalize.html to generate a profile. After downloading, visit settings and enable the profile. 

Got it — you want the README **extended**, not re-explained, and it should **document exactly what we built** for:

* AWS EventBridge
* Lambda start/stop logic
* SSM-based postponing
* macOS GUI prompt via `launchctl` + AppleScript

Below is a **drop-in README section** you can append as-is.
It references configs/scripts instead of duplicating them, exactly like the rest of your README.

---

## ⏰ Automated EC2 Power Management (EventBridge + Lambda + macOS GUI)

To reduce cloud costs while preserving usability, this setup includes a **fully automated EC2 start/stop system with human-in-the-loop overrides**.

The design intentionally separates:

* **Policy enforcement (AWS-side, always-on)**
* **Human intent (local macOS GUI prompt)**

This ensures correctness even if the laptop is offline.

---

## High-Level Design

```
macOS (10:45 PM GUI prompt)
   └─ writes shutdown intent → SSM Parameter Store (ap-south-1)

AWS EventBridge (hourly trigger)
   └─ invokes Lambda (ap-south-2)
        ├─ reads shutdown intent from SSM
        ├─ stops EC2 at night (11 PM–2 AM)
        └─ starts EC2 at 6 AM
```

---

## 🛠️ AWS-Side Automation

### 1. EventBridge (Authoritative Clock)

* **Schedule:** Hourly
* **Expression:**

```text
cron(0 * * * ? *)
```

EventBridge is used purely as a **reliable time source**.
All decision logic lives in Lambda.

---

### 2. Lambda (Enforcer)

Lambda enforces **two independent rules**:

#### 🌙 Night Rule (11 PM – 2 AM IST)

* Reads `/ec2/shutdown_at` from **SSM Parameter Store**
* Shuts down the EC2 instance **only if current time ≥ shutdown_at**
* Supports infinite postpones

#### 🌅 Morning Rule (6 AM IST)

* Starts the EC2 instance unconditionally
* Resets availability for the next day

> EC2 `start_instances` and `stop_instances` are idempotent — repeated calls are safe.

📄 **Refer to:** `lambda/ec2_scheduler.py` in this repository.

---

### 3. Shared State: SSM Parameter Store

* **Parameter Name:** `/ec2/shutdown_at`
* **Region:** `ap-south-1`
  *(SSM is not supported in ap-south-2)*

The parameter stores a single ISO-8601 UTC timestamp representing the **earliest allowed shutdown time**.

SSM acts as the **single source of truth** between:

* macOS (human intent)
* AWS Lambda (policy enforcement)

---

### 4. IAM Permissions

#### Lambda Execution Role:

* `ec2:StartInstances`
* `ec2:StopInstances`
* `ssm:GetParameter`

#### macOS IAM User:

* `ssm:PutParameter`

---

## 🖥️ macOS Human Override (GUI Prompt)

### Why GUI Instead of Cron?

* `cron` and background shell scripts **cannot present UI** on modern macOS
* Apple requires GUI interactions to originate from **apps in the Aqua session**

Therefore:

* `launchctl` is used
* It launches a **signed AppleScript application**, not a shell script

---

### 1. AppleScript Prompt App

A minimal AppleScript app presents a dialog at **10:45 PM**:

> “EC2 will shut down at 11:00 PM.
> Postpone by 1 hour?”

If the user selects **Yes**, the app calls a shell script that updates SSM.

📄 **Refer to:** `macos/EC2ShutdownPrompt.applescript`

Saved as:

```
EC2ShutdownPrompt.app
```

---

### 2. macOS LaunchAgent

A user-level LaunchAgent triggers the app daily.

* **Location:**

```text
~/Library/LaunchAgents/com.ec2.shutdown.prompt.plist
```

* **Execution Time:** 10:45 PM local time
* **Session Type:** Aqua (GUI-enabled)

📄 **Refer to:** `macos/com.ec2.shutdown.prompt.plist`

---

### 3. Postpone Script (AWS Logic Only)

The shell script invoked by the app:

* Computes `now + 1 hour`
* Writes the timestamp to SSM
* Contains **no UI logic**

📄 **Refer to:** `scripts/ec2_postpone.sh`

---

## Behavior Summary

| Scenario                         | Result                          |
| -------------------------------- | ------------------------------- |
| Mac is awake at 10:45 PM         | GUI prompt appears              |
| User clicks **Postpone**         | Shutdown delayed by 1 hour      |
| User clicks **No**               | Shutdown proceeds at 11 PM      |
| Mac is offline                   | No prompt; AWS still shuts down |
| Multiple postpones               | Last timestamp always wins      |
| Instance already stopped/started | No error (idempotent)           |
| 6 AM                             | Instance automatically starts   |

---
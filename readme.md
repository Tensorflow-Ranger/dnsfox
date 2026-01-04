
# Self-Hosted DNS Resolver 

# So, Why would anyone even want their own DNS resolver?

It's superrr cool xD

* **Total Privacy:** Your ISP cannot log your browsing history. All queries between your device and AWS are encrypted via TLS 1.3, making them look like standard web traffic.
* **Battery & Data Savings:** By blocking ads at the DNS level, your device never downloads heavy tracking scripts, video ads, or banners. This reduces CPU cycles and radio usage, significantly extending battery life on mobile and laptops.
* **App Monitoring:** Using the `dnsdist` live console or web dashboard, you can see exactly which background apps are "phoning home" and identify "chatty" telemetry services.
* **Zero-Trust:** You bypass third-party resolvers like Google or Cloudflare. Your server talks directly to the Internet Root Servers via Unbound.
* **Bypass Restrictions:** Take control of your network settings by clearing "Managed" browser profiles and OS-level restrictions.

## High-Level Architecture

The setup uses a frontend/backend model to isolate encryption from resolution logic:

1. **Client (Mac/Phone):** Sends an encrypted HTTPS request (Port 443) to your domain.
2. **dnsdist (Frontend):** Handles SSL/TLS termination, checks Access Control Lists (ACLs), and monitors traffic.
3. **Unbound (Backend):** Performs recursive lookups by contacting Root, TLD, and Authoritative servers.

---

## CRITICAL SECURITY WARNING

**Never expose Port 53 to `0.0.0.0/0` (The World).** Open DNS resolvers are frequently used in **DNS Amplification Attacks**.

* **Port 53 (UDP/TCP):** Only allow your specific Home IP in the AWS Security Group.
* **Port 443 (TCP):** Safe to open to the world *only* if you have configured a strong `dnsdist` ACL to limit access to your own devices.

---

## Step 1: Infrastructure & Domain

1. **AWS EC2:** Launch a t3.micro (Ubuntu). Assign an **Elastic IP**.
2. **Domain:** Use a service like **DuckDNS** to point a subdomain to your Elastic IP.
3. **SSL Certificate:** Generate certificates via Certbot:
```bash
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.duckdns.org

```



---

## Step 2: Installation

```bash
sudo apt update && sudo apt install -y dnsdist unbound

```

---

## Step 3: Configuration

### 1. Unbound (The Brain)

Unbound performs recursive resolution and listens only on `127.0.0.1:5335`.

* **Config:** Refer to the `unbound.conf.d/` directory in this repo.
* **Setup:**
```bash
sudo cp -r unbound.conf.d /etc/unbound/
sudo systemctl restart unbound

```



### 2. dnsdist (The Bouncer)

Handles Access Control, DoH encryption, and forwarding.

* **Config:** Refer to `dnsdist.conf` in this repo.
* **Permissions:** Ensure `_dnsdist` can read the SSL certs:
```bash
sudo chown _dnsdist:_dnsdist /etc/dnsdist/certs/*.pem

```


* **Validation:**
```bash
sudo dnsdist --check-config

```



---

## Step 4: Client Setup (The Bootstrap)

Because of the "Chicken and Egg" problem (finding the server's IP before the secure tunnel exists), you must:

1. **macOS Settings:** Add the **AWS Elastic IP** manually to your Network DNS settings. This "bootstraps" the lookup for your domain.
2. **Browser Settings:** In Chrome/Firefox, enable **Secure DNS** and enter your URL:
`https://your-domain.duckdns.org/dns-query`

---

## Analytics & Monitoring

To monitor queries in real-time and see which apps are active in the background:

```bash
# Watch the live log
sudo journalctl -u dnsdist -f

# Enter the interactive console (if configured)
sudo dnsdist -c 127.0.0.1:8083 -a <your_key>

```
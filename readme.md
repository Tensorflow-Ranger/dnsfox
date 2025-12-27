```markdown
Self-Hosted DNS Resolver using dnsdist + Unbound

This repository documents how to set up a secure, private DNS resolver using:

- dnsdist → front-end DNS proxy (ACLs, rate limiting, monitoring)
- Unbound → recursive DNS resolver (the “brain”)

**Architecture**
```

Client → dnsdist (port 53) → Unbound (port 5335) → Internet

```

---

Repository 

- dnsdist.conf → main dnsdist configuration  
- unbound.conf.d/ → modular Unbound configuration directory  

---

Step 1: Install Dependencies

Install dnsdist
```bash
sudo apt update && sudo apt install -y dnsdist
````

### Install Unbound

```bash
sudo apt install -y unbound
```

---

## Step 2: Configure Unbound (Backend Resolver)

Unbound performs recursive resolution and listens **only on localhost**.

### Copy Unbound configs from this repository

```bash
sudo cp -r unbound.conf.d /etc/unbound/
```

Ensure `/etc/unbound/unbound.conf` includes:

```conf
include: "/etc/unbound/unbound.conf.d/*.conf"
```

Restart and enable Unbound:

```bash
sudo systemctl restart unbound
sudo systemctl enable unbound
```

Unbound will now listen on `127.0.0.1:5335`.

---

## Step 3: Configure dnsdist (Frontend)

dnsdist handles:

* Access control (prevents open resolver abuse)
* Rate limiting
* Forwarding queries to Unbound
* Web-based monitoring

### Copy dnsdist configuration

```bash
sudo cp dnsdist.conf /etc/dnsdist/dnsdist.conf
```

### IMPORTANT

Before starting:

* Edit `/etc/dnsdist/dnsdist.conf`
* Replace `YOUR_HOME_IP` with your public IPv4
* Add your IPv6 address if applicable

---

## Step 4: Fix Permissions (Crucial)

dnsdist runs as a restricted user and must be able to read its config.

```bash
sudo chown _dnsdist:_dnsdist /etc/dnsdist/dnsdist.conf
```

---

## Step 5: AWS Security Group Configuration

Update **Inbound Rules** for your EC2 instance:

| Protocol | Port | Source       | Purpose               |
| -------- | ---- | ------------ | --------------------- |
| UDP      | 53   | Your Home IP | DNS                   |
| TCP      | 53   | Your Home IP | DNS (large responses) |
| TCP      | 8083 | Your Home IP | dnsdist dashboard     |

**Never expose port 53 to `0.0.0.0/0`**
This would turn your server into an open resolver.

---

## Step 6: Validate and Start dnsdist

Check the configuration:

```bash
sudo dnsdist --check-config
```

Expected output:

```
Configuration '/etc/dnsdist/dnsdist.conf' ok!
```

Start and enable dnsdist:

```bash
sudo systemctl restart dnsdist
sudo systemctl enable dnsdist
```

---

## Step 7: Verify the Setup

From your **local machine**, run:

```bash
dig @YOUR_AWS_PUBLIC_IP google.com
```

If you receive an IP address, your resolver is working correctly!

---

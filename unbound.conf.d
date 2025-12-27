server:
    interface: 0.0.0.0
    port: 5335

    # Enable both protocols
    do-udp: yes
    do-tcp: yes

    # These two lines are the most important for "dig" to work
    access-control: 127.0.0.0/8 allow
    access-control: <your_resolver_ip> allow

    # Safety: Disable IPv6 for now so it stops causing "Refused" errors
    do-ip6: no
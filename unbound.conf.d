server:
    interface: 0.0.0.0
    port: 5335

    # Enable both protocols
    do-udp: yes
    do-tcp: yes

    # These two lines are the most important for "dig" to work
    access-control: 127.0.0.0/8 allow
    access-control: 172.31.0.0/16 allow

    # Safety: Disable IPv6 for now so it stops causing "Refused" errors
    do-ip6: no
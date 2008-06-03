{ 
"cpu-limit": { "lax": 80.00, "tight": 120.00, "closed": 120.00 },
"sess-limit": { "lax": 5000.00, "tight": 7000.00, "closed": 10000.00 },
"request-load": { "lax": 60.00, "tight": 70.00, "closed": 80.00 },
"session-load": { "lax": 50.00, "tight": 60.00, "closed": 75.00 },
"tcp-chk-load": { "lax": 4000.00, "tight": 10000.00, "closed": 14000.00 },
"udp-chk-load": { "lax": 4000.00, "tight": 6000.00, "closed": 10000.00 },
"icmp-chk-load": { "lax": 2500.00, "tight": 6000.00, "closed": 10000.00 },
"evil-load": { "lax": 800.00, "tight": 1600.00, "closed": 2000.00 },
"fence": { 
    "relaxed": { "inheritance": 0.100000,
                  "limited": { "prob": 70.00, "post": 65.00 },
                  "closed": { "prob": 85.00, "post": 100.00 },
                  "error": { "prob": 20.00, "post": 110.00 }},
    "lax": { "inheritance": 0.400000,
             "limited": { "prob": 75.00, "post": 50.00 },
             "closed": { "prob": 80.00, "post": 80.00 },
             "error": { "prob": 20.00, "post": 100.00 } },
    "tight": { "inheritance": 0.600000,
               "limited": { "prob": 70.00, "post": 15.00 },
               "closed": { "prob": 90.00, "post": 60.00 },
               "error": { "prob": 20.00, "post": 70.00 } },
    "closed": { "inheritance": 0.900000,
                "limited": { "prob": 90.00, "post": 5.00 },
                "closed": { "prob": 95.00, "post": 20.00 },
                "error": { "prob": 20.00, "post": 40.00 }}},

"multipliers": { "request-load": 2.778000, "session-load": 3.125000,
                 "evil-load": 0.250000, "tcp-chk-load": 0.012500, 
                 "udp-chk-load": 0.012500, "icmp_chk-load": 40.00,
                 "active-session": 0.032000 },

"lru": { "low-water": 512, "high-water": 1024, "sieve-size": 8, "ip-rate": 0.010000 },
"misc": { "debug-rate": 0, "debug-threshold": 155.00, "log-rotate-delay": 10000, "log-size": 12 }, 
"users": []
}


{ 
"cpu-limit": { "lax": 80.000000, "tight": 120.000000, "closed": 120.000000 },
"sess-limit": { "lax": 5000.000000, "tight": 7000.000000, "closed": 10000.000000 },
"request-load": { "lax": 60.000000, "tight": 70.000000, "closed": 80.000000 },
"session-load": { "lax": 50.000000, "tight": 60.000000, "closed": 75.000000 },
"tcp-chk-load": { "lax": 4000.000000, "tight": 10000.000000, "closed": 14000.000000 },
"udp-chk-load": { "lax": 4000.000000, "tight": 6000.000000, "closed": 10000.000000 },
"icmp-chk-load": { "lax": 2500.000000, "tight": 6000.000000, "closed": 10000.000000 },
"evil-load": { "lax": 800.000000, "tight": 1600.000000, "closed": 2000.000000 },
"fence": { 
    "relaxed": { "inheritance": 0.100000,
                  "limited": { "prob": 70.000000, "post": 65.000000 },
                  "closed": { "prob": 85.000000, "post": 100.000000 },
                  "error": { "prob": 20.000000, "post": 110.000000 }},
    "lax": { "inheritance": 0.400000,
             "limited": { "prob": 75.000000, "post": 50.000000 },
             "closed": { "prob": 80.000000, "post": 80.000000 },
             "error": { "prob": 20.000000, "post": 100.000000 } },
    "tight": { "inheritance": 0.600000,
               "limited": { "prob": 70.000000, "post": 15.000000 },
               "closed": { "prob": 90.000000, "post": 60.000000 },
               "error": { "prob": 20.000000, "post": 70.000000 } },
    "closed": { "inheritance": 0.900000,
                "limited": { "prob": 90.000000, "post": 5.000000 },
                "closed": { "prob": 95.000000, "post": 20.000000 },
                "error": { "prob": 20.000000, "post": 40.000000 }}},

"multipliers": { "request-load": 2.778000, "session-load": 3.125000,
                 "evil-load": 0.250000, "tcp-chk-load": 0.012500, 
                 "udp-chk-load": 0.012500, "icmp_chk-load": 40.000000,
                 "active-session": 0.032000 },

"lru": { "low-water": 512, "high-water": 1024, "sieve-size": 8, "ip-rate": 0.010000 },
"misc": { "debug-rate": 0, "debug-threshold": 155.000000, "log-rotate-delay": 10000, "log-size": 12 }, 
"users": []
}


{
    "cpu-limit" :     { "lax" : 80.0,    "tight" : 120.0,   "closed" : 120.0 },
    "sess-limit" :    { "lax" : 5000,    "tight" : 7000,    "closed" : 10000 },
    /* We have no control of the request load (we can drop SYNs, but not stop them) */
    /* Therefore, the request load must limits should essentially be impossible to reach */
    "request-load" :  { "lax" : 60000.0, "tight" : 70000.0, "closed" : 80000.0 },
    "session-load" :  { "lax" : 50.0,    "tight" : 60.0,    "closed" : 75.0 },
    "tcp-chk-load" :  { "lax" : 4000.0,  "tight" : 10000.0, "closed" : 14000.0 },
    "udp-chk-load" :  { "lax" : 4000.0,  "tight" : 6000.0,  "closed" : 10000.0 },
    "icmp-chk-load" : { "lax" : 2500.0,  "tight" : 6000.0,  "closed" : 10000.0 },
    "evil-load" :     { "lax" : 800.0,   "tight" : 1600.0,  "closed" : 2000.0 },

    /*   Fence definition */
    /*   The fence and multipliers are calculated using a reputation
     *   maximum of 100 These are applicable to an individual user */
     "fence" : {
         "relaxed" : { "inheritance" : 0.1,
                       "limited"     : { "prob" : 70, "post" : 65 },
                       "closed"      : { "prob" : 85, "post" : 100 },
                       "error"       : { "prob" : 20, "post" : 110 }},
         "lax"     : { "inheritance" : 0.4,
                       "limited"     : { "prob" : 75, "post" : 50 },
                       "closed"      : { "prob" : 80, "post" : 80 },
                       "error"       : { "prob" : 20, "post" : 100 }},
         "tight"   : { "inheritance" : 0.6,
                       "limited"     : { "prob" : 70, "post" : 15 },
                       "closed"      : { "prob" : 90, "post" : 60 },
                       "error"       : { "prob" : 20, "post" : 70 }},
         "closed"   : { "inheritance" : 0.9,
                       "limited"     : { "prob" : 90, "post" : 5 },
                       "closed"      : { "prob" : 95, "post" : 20 },
                       "error"       : { "prob" : 20, "post" : 40 }}
     },
 
     "multipliers" : { "request-load" : 2.778, "session-load" : 3.125, "tcp-chk-load" : 0.0125,
                       "udp-chk-load" : 0.0125, "icmp-chk-load" : 40.0, "evil-load" : 0.25,
                       "active-sessions" : 0.032 },

     "lru" : { "low-water" : 512, "high-water" : 1024, "sieve-size" : 8, "ip-rate" : 0.01 },

      "debug" : { "rate" : 0.25, "threshold" : 155.0 }
}


#!/usr/bin/env python
from parse import *
from subprocess import *
import json

# Get QoS statistics from the output of qos-service.py sessions command

#Parse patterns for qos-service.py sessions output
parsePattern='proto {} state {} src {} dst {} src-port {:d} dst-port {:d} packets {:d} bytes {:d} priority {:d}'
entryKeys=('proto','state','src','dst','src_port','dst_port','packets','bytes','priority')

output=[]
proc = Popen('/usr/share/untangle-netd/bin/qos-service.py sessions', stdout=PIPE, shell=True)
entry={}
for line in proc.stdout:
      res=parse(parsePattern,line[:-1])
      if res:
        parsed = res.fixed
        output.append(dict(zip(entryKeys,parsed)))

print json.dumps(output)

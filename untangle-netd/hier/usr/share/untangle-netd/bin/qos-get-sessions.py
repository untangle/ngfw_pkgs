#!/usr/bin/env python
from parse import *
from subprocess import *
import json

# Get QOS statistics from the output of qos-service sessions command

#Parse patterns for qos-service sessions output
parsePattern='proto {} state {} src {} dst {} src-port {:d} dst-port {:d} packets {:d} bytes {:d} priority {:d}'
exports=[]
exportedNames=['UPLINKS']
entryKeys=('proto','state','src','dst','src_port','dst_port','packets','bytes','priority')

# Check the file for the definition of $UPLINKS as it needs to be exported
# for the proper functioning of the QOS script
with open('/etc/untangle-netd/iptables-rules.d/300-qos') as definitions:
  for line in definitions:
    for name in exportedNames:
      if name in line:
        exports.append(line[:-1])

exports.append('/usr/share/untangle-netd/bin/qos-service sessions')
command =' && '.join(exports)
output=[]
proc = Popen(command, stdout=PIPE, shell=True)
entry={}
for line in proc.stdout:
      res=parse(parsePattern,line[:-1])
      if res:
        parsed = res.fixed
        output.append(dict(zip(entryKeys,parsed)))

print json.dumps(output)

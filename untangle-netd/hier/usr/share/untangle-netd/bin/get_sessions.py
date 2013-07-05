#!/usr/bin/env python
from parse import *
from subprocess import *
import json

# Get QOS statistics from the output of qos-service sessions command

#Parse patterns for qos-service sessions output
parsePattern='proto {} state {} src {} dst {} src-port {:d} dst-port {:d} packets {:d} bytes {:d} priority {:d}'
exports=[]
exportedNames=['UPLINKS']

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
        input = res.fixed
        entry={}
        entry['proto']=input[0]
        entry['state']=input[1]
        entry['src']=input[2]
        entry['dst']=input[3]
        entry['src_port']=input[4]
        entry['dst_port']=input[5]
        entry['packets']=input[6]
        entry['bytes']=input[7]
        entry['priority']=input[8]
        output.append(entry)

print json.dumps(output)
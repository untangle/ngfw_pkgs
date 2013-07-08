#!/usr/bin/env python
from parse import *
from subprocess import *
import json

# Get QOS statistics from the output of qos-service status command

#Parse patterns for qos-service status output
firstLine='interface: {} class {} {} {} rate {} ceil {} burst {} cburst {}'
secondLine=' Sent {:d} bytes {:d} pkt (dropped {:d}, overlimits {:d} requeues {:d}) '
thirdLine=' rate {} {} backlog {} {} requeues {:d} '
fourthLine= ' lended: {:d} borrowed: {:d} giants: {:d}'
lastLine=' tokens: {:d} ctokens:{:d}'
priorityParser='{} prio {:d}'

indexMap={1:firstLine, 2:secondLine, 3:thirdLine, 4:fourthLine, 5:lastLine}

exports=[]
exportedNames=['UPLINKS']

# Check the file for the definition of $UPLINKS as it needs to be exported
# for the proper functioning of the QOS script
with open('/etc/untangle-netd/iptables-rules.d/300-qos') as definitions:
  for line in definitions:
    for name in exportedNames:
      if name in line:
        exports.append(line[:-1])

exports.append('/usr/share/untangle-netd/bin/qos-service status')
command =' && '.join(exports)
output=[]

proc = Popen(command, stdout=PIPE, shell=True)
count=1
entry={}
for line in proc.stdout:
    if count <= 5:
      res=parse(indexMap[count],line)
      parsed = res.fixed
      if count == 1:
        entry['interface_name']=parsed[0]
        entry['burst']=parsed[len(parsed)-2]
        if 'prio' in parsed[3]:
          prioParse = parse(priorityParser, parsed[3])
          val=prioParse.fixed
          entry['priority']=val[len(val)-1]
      if count == 2:
        entry['sent']=str(parsed[0]) + ' bytes'
      if count == 3:
        entry['rate']=parsed[0]
      if count == 5:
        entry['tokens']=parsed[0]
        entry['ctokens']=parsed[1]
      count+=1
    else:
      if 'imq' not in entry['interface_name']:
        output.append(dict(entry))
      entry.clear()
      count=1
      continue

print json.dumps(output)
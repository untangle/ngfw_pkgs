# support-diagnostics

This is a set of tools designed to help determin issues with Untangle appliances.
While it's not intended to be exhaustive or cover every case, 
it attempts to cover many causes  that can take a long time to determine.

It's designed to be easy to extend.

## Overview

A *collector* pulls data from the system and one or more *analyzers* examine 
the collected data to produce one or more *analyzer results*.

Each anaylzer result consists of the following attributes:

* severity.  Pass, Warn, or Fail.
* summary.  A brief description of the result.
* detail.  Extended information about the result.
* recommendation.  If possible, how to deal with warning or failure results.

By default results are presented in a block format such as:
```
Fail
Summary         Pointing to unknown server 'ftp.debian.org'
Detail          No customer or corporate units should be pointing to an unknown package server
Recommendation  From file:
                /etc/apt/sources.list:
                delete entry:
                deb http://ftp.debian.org/debian buster main contrib
```

For results where more items with brief results, a tabular format may be more appropriate:
```
Partition Usage
Warning        tmpfs      /tmp           -> /tmp       85% Disk usage near critical
Pass           Linux      /dev/sda1      -> /boot      25%
Warning        Linux      /dev/sda2      -> unknown    unknown
Pass           Linux      /dev/sdb1      -> /overlay   1%
```

### Severity
A result severity is displayed in a color and the easiest to visually parse.

| Severity | Color | Description |
| -------- | ----- | ----------- |
| Pass| Green | The result determined the system area is working properly.|
| Warn | Yellow | Not an error but out of the ordinary. |
| Fail | Red | System area is not working properly and should be addressed. |

While Pass and Fail are straightforward, what could constitute a Warn? 
* Disk approaching but not yet at critical usage.
* Partition found that is not mounted.
* source.list pointing to internal production server.

There are also cases where we may not be able to truly call a result "fail" but
further exploration by support is warrented.  

For example, if Spam Blocker sees messages with TIME_LIMIT_EXCEEDED that 
likely indicates a problem with the DNS resolver. But what percentage of 
messages should meet a threshold to be actionable?  It might suggest a a
conversation between the support representative and the customer.

## Command line options

At this time, the following command line options are supported:

| Option | Arguments | Description |
| -------- | ----- | ----------- |
| ---categories=\<list\> | Comma separated list | Analyzer categories.  The default, 'all' runs every analyzer.|


## Updates

The support_diagnostics script checks for updates once a day from 
updates.untangle.com and will automatically download and install.

The information is stored under /root/.support_diagnostics.json so if you need
to force an update, you can remove this file and re-run support_diagnostics.

## Writing Modules

The heart of support_diagnostics operation is to use catgorized analyzers to
collect data, review, and produce a result for a report.

### analyzer
An analyzer examines a collector's results to produce a grouped analysis.

For example, the SpamBlockerAnalyzer looks for the timeout results.  It could 
also be expanded to look at Bayes results.

### collector
A collector gathers information for a single system "object" such as:

* All apt sources.list files.
* All mail logs.

A single collector can be used by multiple analyzers.  For example, the 
MailLogCollector can be used by SpamBlockerAnalyzer but perhaps also another 
analyzer that would scan the same data to determine if virus scanning is 
working properly.

Each collector returns a list of CollectorResult objects that have identifiers.
The output field can be in any format.

For many areas, just collecting raw data like logs is enough and the analyzer
can perform regex matches for information of interest.  

For other areas, a more ordered result may be approrpiate such as the 
FileSystemCollector which collates disk partition and disk usage data into
objects for the PartitionsAnalyzer to review.

### platforms

The support_diagnostics tool is designed for MFW and NGFW architectures.
At this time, we determine these products by their base operating system, 
either openwrt (MFW) or debian (NGFW).  Some modules work on either.

* all.  Modules that work on either.
* openwrt.  Modules that examine MFW-based systems.
* debian.  Modules that examine NGFW-based systems.

For modules under the all category, you may need to perform specific processing
for a platform.  For example, the FileSystemCollector looks for diretories
and files sizes that commonly indicate problem.  Such code is handled as:

```
...
platform_entries = {
    'openwrt': [ '/tmp/reports.db'],
    'debian': [ '/var/log', '/var/lib/postgresql', '/etc', '/usr/share/untangle' ]
}
...
        platform = support_diagnostics.Configuration.platform
        if platform in self.platform_entries:
            for entry in self.platform_entries[support_diagnostics.Configuration.platform]:
                # openwrt does not have -b option.
                proc = subprocess.Popen(['du', "-s", entry], stdout=subprocess.PIPE)

...

```

That said, in general modules should be written for the specific platform.
For example, a firewall analyzer would be much too complicated to design
for both platforms.

## Releases

Since this tool is designed to be updated as needed (like after dicovering an 
issue in the field that took hours or days to find and now you know you have a
set of commands you can run to identify it again), it's perpetually outside
the normal release cycles for our products.

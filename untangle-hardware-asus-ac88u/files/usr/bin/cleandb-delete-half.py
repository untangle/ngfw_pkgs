#! /usr/bin/env python 
# $Id: reports-generate-reports.py 38486 2014-08-21 22:29:30Z cblaise $

import getopt, logging, mx, os, os.path, re, sys, tempfile, time, shutil, datetime, traceback
from subprocess import Popen, PIPE
from psycopg2.extensions import DateFromMx, TimestampFromMx
from uvm.settings_reader import get_node_settings_item
from uvm.settings_reader import get_node_settings

def usage():
     print """\
usage: %s [num days of data to keep]
Options:
""" % sys.argv[0]

REPORTS_PYTHON_DIR = '/usr/lib/python%d.%d' % (sys.version_info[0], sys.version_info[1])
NODE_MODULE_DIR = '%s/reports/node' % REPORTS_PYTHON_DIR

import reports.engine
import reports.sql_helper as sql_helper

reports.engine.init_engine(NODE_MODULE_DIR)
connection = sql_helper.get_connection()
cursor = connection.cursor()


def get_mid_date(id_column,table):
     # Get the mid-point by ID
     cursor.execute("SELECT (max(%s)+min(%s))/2 AS mid FROM %s" % (id_column,id_column,table))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print "Invalid mid point from reports.sessions"
          sys.exit(1)

     mid_session_id = int(row[0])

     # Get the "time_stamp" on the mid-point (the ID closest to mid-point)
     cursor.execute("SELECT time_stamp FROM %s WHERE %s < %s ORDER BY %s DESC LIMIT 1"%(table, id_column, str(mid_session_id), id_column))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print "Invalid time_stamp from reports.sessions"
          sys.exit(1)

     time_stamp = row[0]

     cutoff = mx.DateTime.Parser.DateTimeFromString(str(time_stamp))
     return cutoff

if len(sys.argv) < 1:
     usage()
     sys.exit(1)


#mid_session_id = sql_helper.run_sql("SELECT (max(session_id)+min(session_id))/2 AS mid FROM reports.sessions")
#print mid_session_id

sessions_cutoff = get_mid_date("session_id","reports.sessions")
print "sessions     cutoff estimate: %s" % str(sessions_cutoff)

http_cutoff = get_mid_date("request_id","reports.http_events")
print "http_events  cutoff estimate: %s" % str(http_cutoff)

# Take the later of the two cutoff (to make sure we cut AT LEAST half of all data in all tables)
cutoff = sessions_cutoff
if ( http_cutoff > sessions_cutoff ):
     cutoff = http_cutoff

print "cutoff: %s" % str(cutoff)

#print mx.DateTime(cutoff.timetuple()[:3])
test = mx.DateTime.Parser.DateTimeFromString("%d-%d-%d"%cutoff.timetuple()[:3])
print test

reports.engine.reports_cleanup(cutoff)     




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
          print "Invalid mid point from %s" % table
          sys.exit(1)

     mid_session = row[0]
     if mid_session == None:
          return None
     mid_session_id = int(row[0])

     # Get the "time_stamp" on the mid-point (the ID closest to mid-point)
     cursor.execute("SELECT time_stamp FROM %s WHERE %s < %s ORDER BY %s DESC LIMIT 1"%(table, id_column, str(mid_session_id), id_column))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print "Invalid time_stamp from %s" % table
          sys.exit(1)

     time_stamp = row[0]

     cutoff = mx.DateTime.Parser.DateTimeFromString(str(time_stamp))
     return cutoff

def get_count(table):
     # Get the mid-point by ID
     cursor.execute("SELECT count(*) FROM %s" % (table))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print "Invalid count from %s" % table
          sys.exit(1)

     count = int(row[0])
     return count

if len(sys.argv) < 1:
     usage()
     sys.exit(1)

# Print the before table size - just for debugging/logging
sessions_count = get_count("reports.sessions")
session_minutes_count = get_count("reports.session_minutes")
http_count = get_count("reports.http_events")
print "sessions                   count: %s" % str(sessions_count)
print "session_minutes            count: %s" % str(session_minutes_count)
print "http_events                count: %s" % str(http_count)
     
# Find the mid-point for the major three tables
sessions_cutoff = get_mid_date("session_id","reports.sessions")
session_minutes_cutoff = get_mid_date("session_id","reports.session_minutes")
http_cutoff = get_mid_date("request_id","reports.http_events")
print "sessions         cutoff estimate: %s" % str(sessions_cutoff)
print "session_minutes  cutoff estimate: %s" % str(session_minutes_cutoff)
print "http_events      cutoff estimate: %s" % str(http_cutoff)

# Take the latest of mid-points (to make sure we cut AT LEAST half of all data in all tables)
cutoff = max(sessions_cutoff, session_minutes_cutoff, http_cutoff)
print "using cutoff: %s" % str(cutoff)

# Clean the tables with the maximum cutoff
reports.engine.reports_cleanup(cutoff)     

# Print the after table size - just for debugging/logging
sessions_count = get_count("reports.sessions")
session_minutes_count = get_count("reports.session_minutes")
http_count = get_count("reports.http_events")
print "sessions              post count: %s" % str(sessions_count)
print "session_minutes       post count: %s" % str(session_minutes_count)
print "http_events           post count: %s" % str(http_count)


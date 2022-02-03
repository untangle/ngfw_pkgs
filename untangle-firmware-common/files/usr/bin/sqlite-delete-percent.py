#! /usr/bin/python3
# $Id: reports-generate-reports.py 38486 2014-08-21 22:29:30Z cblaise $

import datetime
import os
import os.path
import sys
import traceback


def usage():
     print("""\
usage: %s percent
percent: percent of amount of data to delete (eg, 10 = 10%)
Options:
""" % sys.argv[0])


PYTHON_DIR = '/usr/lib/python%d.%d' % (sys.version_info[0], sys.version_info[1])
REPORTS_PYTHON_DIR = '%s/reports' % (PYTHON_DIR)

import reports.sql_helper as sql_helper
sql_helper.DBDRIVER = "sqlite"
sql_helper.SCHEMA = "main"

connection = sql_helper.get_connection()
cursor = connection.cursor()
percent = 2


def get_mid_date(id_column,table,percent):
     # Get the mid-point by ID
     cursor.execute("SELECT (min(%s) + cast(((max(%s)-min(%s))*(%i.0/100.0)) as int) ) AS mid FROM %s" % (id_column,id_column,id_column,percent,table))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print("Invalid mid point from %s" % table)
          sys.exit(1)

     mid_session = row[0]
     if mid_session == None:
          return None
     mid_session_id = int(row[0])

     # Get the "time_stamp" on the mid-point (the ID closest to mid-point)
     cursor.execute("SELECT time_stamp FROM %s WHERE %s < %s ORDER BY %s DESC LIMIT 1"%(table, id_column, str(mid_session_id), id_column))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print("Invalid time_stamp from %s" % table)
          sys.exit(1)

     time_stamp = row[0]
     cutoff = datetime.datetime.fromtimestamp(time_stamp/1000)
     print(cutoff)
     return cutoff


def get_count(table):
     # Get the mid-point by ID
     cursor.execute("SELECT count(*) FROM %s" % (table))
     row = cursor.fetchone()
     if row == None or len(row) < 1:
          print("Invalid count from %s" % table)
          sys.exit(1)

     count = int(row[0])
     return count


if len(sys.argv) < 2:
     usage()
     sys.exit(1)

try:
     percent = int(sys.argv[1])
except:
     usage()
     sys.exit(1)
     
# Print the before table size - just for debugging/logging
sessions_count = get_count("sessions")
session_minutes_count = get_count("session_minutes")
http_count = get_count("http_events")
print("sessions                   count: %s" % str(sessions_count))
print("session_minutes            count: %s" % str(session_minutes_count))
print("http_events                count: %s" % str(http_count))
     
# Find the mid-point for the major three tables
sessions_cutoff = get_mid_date("session_id","sessions",percent)
session_minutes_cutoff = get_mid_date("session_id","session_minutes",percent)
http_cutoff = get_mid_date("request_id","http_events",percent)
print("sessions         cutoff estimate: %s" % str(sessions_cutoff))
print("session_minutes  cutoff estimate: %s" % str(session_minutes_cutoff))
print("http_events      cutoff estimate: %s" % str(http_cutoff))

# Take the latest of mid-points (to make sure we cut AT LEAST half of all data in all tables)
cutoff = max(sessions_cutoff, session_minutes_cutoff, http_cutoff)
print("using cutoff: %s" % str(cutoff))

# delete the stuff
for f in os.listdir(REPORTS_PYTHON_DIR):
     if f.endswith('py'):
          (m, e) = os.path.splitext(f)
          if "__init__" == m:
               continue
          name = 'reports.%s' % m
          print(name)
          obj = __import__('reports.%s' % m)
          app = getattr(obj,m)
          #obj = eval(name)
          try:
               if "cleanup_tables" in dir(app):
                    print("%s.cleanup_tables()" % name)
                    app.cleanup_tables( cutoff )
          except:
               print("%s.cleanup_tables() Exception:" % name)
               traceback.print_exc()

# Print the after table size - just for debugging/logging
sessions_count = get_count("sessions")
session_minutes_count = get_count("session_minutes")
http_count = get_count("http_events")
print("sessions              post count: %s" % str(sessions_count))
print("session_minutes       post count: %s" % str(session_minutes_count))
print("http_events           post count: %s" % str(http_count))


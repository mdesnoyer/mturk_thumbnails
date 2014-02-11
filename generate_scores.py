#!/usr/bin/env python
'''Script that generates the scores file from the database.

The scores file is a csv file of the form:
<image>,<score>,<stimset>

Author: Mark Desnoyer (desnoyer@neon-lab.com)
Copyright: Neon Labs 2014
'''

import csv
from optparse import OptionParser
import psycopg2
import subprocess
import urlparse

def GetDatabaseURL(app):
    '''Retrieves the database URL from the heroku configuration.'''
    print 'Getting database attached to Heroku app %s' % app
    proc = subprocess.Popen('heroku config:get DATABASE_URL --app %s' % app,
                            stdout=subprocess.PIPE, shell=True)

    retval = proc.stdout.readlines()
    proc.wait()
    return retval[0].strip()

def main(options):
    urlparse.uses_netloc.append("postgres")
    url = urlparse.urlparse(GetDatabaseURL(options.app))

    conn = psycopg2.connect(
        database=url.path[1:],
        user=url.username,
        password=url.password,
        host=url.hostname,
        port=url.port)

    cursor = conn.cursor()
    print 'Writing scores to %s' % options.output
    with open(options.output, 'w') as outputStream:
        writer = csv.writer(outputStream)
        cursor.execute('select image, valence, stimset '
                       'from image_scores where '
                       '(valid_keeps + valid_returns) / 2 > %i'
                       'order by stimset' %
                       options.min_clicks)
        curRow = cursor.fetchone()
        while curRow is not None:
            writer.writerow(curRow)
            curRow = cursor.fetchone()
    

if __name__ == '__main__':
    parser = OptionParser()

    parser.add_option('--app', '-a', default='gentle-escarpment-8454',
                      help='Heroku app of the database to connect to')
    parser.add_option('--output', '-o', default='scores.csv',
                      help='Output file')
    parser.add_option('--min_clicks', type='int', default=100,
                      help='Minimum number of clicks an image needs to be counted.')

    options, args = parser.parse_args()

    main(options)

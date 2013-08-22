#!/usr/bin/env python
'''Script that generates the valence scores from the database.

Copyright Neon Labs 2013
Author: Mark Desnoyer (desnoyer@neon-lab.com)
'''
import logging
from optparse import OptionParser
import scipy as sp
import numpy as np
import psycopg2 as dbapi

_log = logging.getLogger(__name__)

class ValenceStats:
    def __init__(self):
        self.stats = {} # image -> [absolute valence score, # of valid views]

    def init_image(self, image):
        if image not in self.stats:
            self.stats[image] = [0,0]
            
    def keep_image(self, image):
        self.init_image(image)
        self.stats[image][0] += 1
        self.stats[image][1] += 1

    def return_image(self, image):
        self.init_image(image)
        self.stats[image][0] -= 1
        self.stats[image][1] += 1

    def view_image(self, image):
        self.init_image(image)
        self.stats[image][1] += 1

def IsRandom(worker_id, job_id):
    '''Returns true if the worker was cheating.

    This is calulated using the Kolmogorov–Smirnov test to see if the
    distribution of scores for this job are different than random.

    '''

    # The find_random_score distribution script was used to find out
    # that the random distribution was very close to a gaussian with
    # mean of 0 and std of 1.332956

def AddValidViews(stats, worker_id, job_id):
    if IsRandom(worker_id, job_id):
        return stats
    

def main(options):
    stats = ValenceStats()
    
    db_connection = dbapi.connect(database=options.database,
                                  host=options.host,
                                  user=options.user,
                                  password=options.password,
                                  port=options.port)
    try:
        worker_cursor = db_connection.cursor()
        worker_cursor.execute('select distinct worker_id, stimset_id from image_choices;')
        for worker_id, job_id in worker_cursor:
            stats = AddValidViews(stats, worker_id, job_id)
        
    finally:
        db_connection.close()

if __name__ == '__main__':
    parser = OptionParser()

    parser.add_option('--output', '-o', default='valence_scores.csv',
                      help='Output file')
    parser.add_option('--host', '-h',
                      default='ec2-23-23-234-207.compute-1.amazonaws.com',
                      help='Database host')
    parser.add_option('--database', '-d', default='ypqkdxvnyynxtc',
                      help='Database to interact with')
    parser.add_option('--port', '-P', default=5432, type='int',
                      help='Database port')
    parser.add_option('--password', '-p', default='Kr3_R6gYvLqGk_WnYc9dclK6sF',
                      help='Database password')
    
    options, args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    main(options)

#!/usr/bin/env python
'''Give a list of trials, estimate the probability distrubtion of scores.

Done using a monte carlo approach

Outputs a file, where each line is in the format:
<score>,<probability>

Can also output a file of g statistic vs. probability of getting it randomly.
This can be used to run a randomization test of good fit. File will be of the form:
<g_statistic>,<prob(random >= statistic)>

Copyright Neon Labs 2013
Author: Mark Desnoyer (desnoyer@neon-lab.com)
'''

import csv
import numpy as np
from optparse import OptionParser
import random

def FindMaxScore(trials):
    max_score = 0
    for trial in trials:
        if 1 in trial:
            max_score += 1

    return max_score

def ParseTrials(trial_file):
    with open(trial_file) as f:
        return [(int(x[0]), int(x[1]), int(x[2])) for x in csv.reader(f)]

def RunSimulatedExperiment(trials, max_score):
    '''Runs a simulated experiment and returns the count of the number of images with each score'''
    scores = np.zeros((np.max(trials) + 1))

    # Simulate the experiment
    for trial in trials:
        scores[random.choice(trial)] += 1
        scores[random.choice(trial)] -= 1

    # Count the images with each score
    counts = np.zeros((2*FindMaxScore(trials)+1))
    for score in scores:
        counts[score + max_score] += 1


    return counts

def DetermineProbabilityDistribution(trials, accuracy):
    '''Returns the probability of having an image at each score.'''
    last_probs = None
    cur_probs = None
    max_score = FindMaxScore(trials)
    score_counts = np.zeros((2*max_score+1))
    scores = np.arange(-max_score, max_score+1)

    while ((last_probs is None) or 
           (np.max(np.abs(cur_probs - last_probs)) > options.accuracy)):
        last_probs = cur_probs

        score_counts += RunSimulatedExperiment(trials, max_score)
        cur_probs = score_counts / np.sum(score_counts)

    return cur_probs

def CalculateG(p_expected, o_counts):
    valid = np.nonzero(o_counts)
    safe_counts = o_counts[valid]
    e_counts = (p_expected * np.sum(o_counts))[valid]
    return 2 * np.sum(np.multiply(safe_counts,
                                  np.log(np.divide(safe_counts, e_counts))))

def EstimateGStats(trials, p_expected, accuracy):

    last_p = None
    cur_p = None
    g_samples = []
    max_score = FindMaxScore(trials)
    while last_p is None or (np.abs(last_p - cur_p) > accuracy):
        last_p = cur_p

        for i in range(1000):
            g_samples.append(
                CalculateG(p_expected,
                           RunSimulatedExperiment(trials, max_score)))

        cur_p = float(np.sum(np.array(g_samples) >= 4.0)) / len(g_samples)

    stats = [(0.0,1.0)]
    g_samples = np.sort(np.array(g_samples))
    for g in g_samples:
        if len(stats) > 0 and g == stats[-1][0]:
            continue
        stats.append((g, float(np.sum(g_samples >= g)) / len(g_samples)))

    return stats

def OutputData(filename, data):
    with open(filename, 'w') as f:
        print 'Writing to %s' % filename
        writer = csv.writer(f)
        for row in data:
            writer.writerow(row)

def main(options):
    random.seed(options.seed)

    trials = ParseTrials(options.input)
    max_score = FindMaxScore(trials)
    p_expected = DetermineProbabilityDistribution(trials, options.accuracy)
    OutputData(options.output, zip(np.arange(-max_score, max_score+1),
                                   p_expected))

    gstats = EstimateGStats(trials, p_expected, options.accuracy)
    OutputData(options.g_output, gstats)

if __name__ == '__main__':
    parser = OptionParser()

    parser.add_option('--input', '-i', default=None,
                      help='Input file. List of trials')
    parser.add_option('--output', '-o', default='score_prob.csv',
                      help='Output file')
    parser.add_option('--g_output', '-g', default='g_stats.csv',
                      help='Output file for the g stat cdf')
    parser.add_option('--accuracy', type='float', default=1e-4,
                      help='Termination criteria')
    parser.add_option('--seed', type='int', default=1984398,
                      help='Random seed')

    options, args = parser.parse_args()

    main(options)

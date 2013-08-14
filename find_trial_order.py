#!/usr/bin/env python
'''Script that finds a valid trial order for the bday task.

The trial order is a sequence of trials such that:
1) Each image appears exactly k times
2) Any pair of images only appears in at most one trial
3) The slot that each images appears in is distributed

The output is a csv file such that each line is a trial of the form:
<image#1>,<image#2>,<image#3>
'''
import csv
import copy
import numpy as np
from optparse import OptionParser
import random

def ChooseFirstTrials(nimages):
    '''Select the first set of trials by just shuffling the images.'''
    images = range(nimages)
    random.shuffle(images)

    return [[images[i], images[i+1], images[i+2]] for 
            i in range(0, nimages, 3)]

class TrialCollector:
    def __init__(self, nimages, nviews):
        self.trials = [] # [(im1,im2,im3)]

        # im# -> list of images already paired with this one
        self.paired = [set() for x in xrange(nimages)]

        for trial in ChooseFirstTrials(nimages):
            self.RegisterTrial(trial)

        # list of images that can still be selected
        self.avail = range(nimages)
        for i in range(nviews-2):
            self.avail.extend(range(nimages))
        random.shuffle(self.avail)        

    def RegisterTrial(self, trial=None, availIdx=None):
        if availIdx is not None:
            trial = [self.avail[availIdx[0]], self.avail[availIdx[1]],
                     self.avail[availIdx[2]]]
            del self.avail[availIdx[0]]
            del self.avail[availIdx[1]]
            del self.avail[availIdx[2]]
            
        self.trials.append(trial)
        self.paired[trial[0]].update(trial[1:])
        self.paired[trial[1]].update([trial[0], trial[2]])
        self.paired[trial[2]].update(trial[0:2])

    def IterateValidTrials(self):
        '''Iterates through the valid trials in avail.

        Yields: (i,j,k) indicies into self.avail
        '''
        for i in xrange(len(self.avail)-1, -1, -1):
            availI = self.avail[i]
            for j in xrange(i-1, -1, -1):
                availJ = self.avail[j]
                if ((availI == availJ) or (availJ in self.paired[availI])):
                    continue
                
                for k in xrange(j-1, -1, -1):
                    availK = self.avail[k]
                    if ((availI == availK) or 
                        (availJ == availK) or 
                        (availK in self.paired[availI]) or 
                        (availK in self.paired[availJ])):
                        continue
                    
                    # We've found a valid trial
                    yield (i,j,k)
        

def SelectTrials(collector):
    '''Selects the valid trials left from TrialCollector

    returns A TrialCollector object with the chosen trials if possible, None otherwise
    '''
    if len(collector.avail) == 0:
        return collector

    for trialIdx in collector.IterateValidTrials():
        collectorCopy = copy.deepcopy(collector)
        collectorCopy.RegisterTrial(availIdx = trialIdx)
        newCollector = SelectTrials(collectorCopy)
        if newCollector is not None:
            return newCollector

    return None
    

def ShuffleImageLoc(trials):
    '''Shuffles the images location in all the trials in place.'''
    for trial in trials:
        random.shuffle(trial)

    return trials

def VerifyTrials(trials, nimages, nviews):
    imageCount = np.zeros(nimages, dtype=np.int32)
    pairs = np.zeros((nimages,nimages), dtype=np.int32)
    for x, y ,z in trials:
        imageCount[x] += 1
        imageCount[y] += 1
        imageCount[z] += 1
        pairs[x,y] += 1
        pairs[y,x] += 1
        pairs[x,z] += 1
        pairs[z,x] += 1
        pairs[y,z] += 1
        pairs[z,y] += 1

    assert(np.max(imageCount) == nviews)
    assert(np.min(imageCount) == nviews)
    assert(np.max(pairs) == 1)

def main(options):
    random.seed(options.seed)
    collector = TrialCollector(options.nimages, options.nviews)
    collector = SelectTrials(collector)
    if collector is None:
        print 'Could not find any valid trials'
        exit(1)

    ShuffleImageLoc(collector.trials)

    VerifyTrials(collector.trials, options.nimages, options.nviews)

    # Output the trials
    with open(options.output, 'wb') as f:
        writer = csv.writer(f)
        for trial in collector.trials:
            writer.writerow(trial)

if __name__ == '__main__':
    parser = OptionParser()

    parser.add_option('--output', '-o', default='trials.csv',
                      help='Output file')
    parser.add_option('-k', '--nviews', type='int', default=4,
                      help='Number of times to show each image')
    parser.add_option('-n', '--nimages', type='int', default=108,
                      help='Number of different images to show')
    parser.add_option('--seed', type='int', default=1984398,
                      help='Random seed')
    
    options, args = parser.parse_args()

    # Make sure that we can create full trials
    if (options.nimages % 3) <> 0:
        print 'Number of images must be a multiple of 3'
        exit(1)

    main(options)

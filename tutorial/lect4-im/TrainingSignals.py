#!/usr/bin/env python3
# Set up imports and paths
import sys, os
import numpy as np
# Get the helper functions for connecting to the buffer
try:     pydir=os.path.dirname(__file__)
except:  pydir=os.getcwd()    
sigProcPath = os.path.join(os.path.abspath(pydir),'../../python/signalProc')
sys.path.append(sigProcPath)
import bufhelp
import preproc
import pickle

dname  ='training_data'
cname  ='clsfr'

print("Training classifier")
if os.path.exists(dname+'.pk'):
    f     =pickle.load(open(dname+'.pk','rb'))
    data  =f['data']
    events=f['events']
    hdr   =f['hdr']
# try the hdf5 file
if not 'data' in dir() and os.path.exists(dname+'.h5'):
    import h5py
    f     = h5py.File(dname+'.mat','r')
    data  =f['data']
    events=f['events']
    hdr   =f['hdr']
# try the .mat file if all else fails
if not 'data' in dir() and os.path.exists(dname+'.mat'):
    from scipy.io import loadmat
    f     = loadmat(dname+'.mat')
    data  =f['data']
    events=f['events']
    hdr   =f['hdr']


#-------------------------------------------------------------------
#  Run the standard pre-processing and analysis pipeline using the preproc class
# 1: detrend

labels = np.array([e.value.endswith('True') for e in events])

print(data[0])

X = np.array(data).T
print(X.shape, labels.shape)

X = preproc.detrend(X)

# 2: bad-channel removal

goodch, badch = preproc.outlierdetection(X);
print(goodch)
X = X[goodch,:,:];

# 3: apply spatial filter

X=preproc.spatialfilter(X,'car')

# 4 & 5: map to frequencies and select frequencies of interest

print(hdr)

X,freqs = preproc.powerspectrum(X,dim=1,fSample=hdr.fSample)
print(freqs)

freqbands   =[20,10,30,60]
X,freqIdx=preproc.selectbands(X,dim=1,band=freqbands,bins=freqs)
freqs=freqs[freqIdx]

# 6 : bad-trial removal

goodtr, badtr = preproc.outlierdetection(X,dim=2)
X = X[:,:,goodtr]
labels = labels[goodtr]

# 7: train classifier, default is a linear-least-squares-classifier
import linear
#mapping = {('stimulus.target', 0): 0, ('stimulus.target', 1): 1}
X2d = np.reshape(X,(-1,X.shape[2])).T # sklearn needs data to be [nTrials x nFeatures]
classifier = linear.fit(X2d,labels.astype(int))#,mapping)
print(X2d[labels].mean(axis=0) - X2d[~labels].mean(axis=0))
print(labels.astype(int))

# save the trained classifer
print('Saving clsfr to : %s'%(cname+'.pk'))
pickle.dump({'classifier':classifier, 'goodch': goodch, 'freqbands': freqbands, 'classifier': classifier, 'fSample': hdr.fSample},open(cname+'.pk','wb'))
    

print(classifier.intercept_, classifier.coef_)

#!/bin/bash
TOLOMATIC=/Users/rvosa/Dropbox/documents/projects/current/tolomatic/
rm -rf $TOLOMATIC/examples/tolweb/result
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-$HADOOP_VERSION-streaming.jar \
    -cmdenv DATADIR=$HOME/Desktop/tolomatic \
    -input $TOLOMATIC/examples/tolweb/taxa.txt \
    -output $TOLOMATIC/examples/tolweb/result \
    -mapper mapper.pl \
    -combiner combiner.pl \
    -reducer reducer.pl \
    -verbose

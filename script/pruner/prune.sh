#!/bin/bash
TOLOMATIC=/Users/rvosa/Dropbox/documents/projects/current/tolomatic/
RESULT=$TOLOMATIC/examples/tolweb/result
rm -rf $RESULT
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-$HADOOP_VERSION-streaming.jar \
    -cmdenv DATADIR=$HOME/Desktop/tolomatic \
    -input $TOLOMATIC/examples/tolweb/mammals.txt \
    -output $RESULT \
    -mapper mapper.pl \
    -combiner combiner.pl \
    -reducer reducer.pl \
    -verbose
#!/bin/bash
TOLOMATIC=/Users/rvosa/Dropbox/documents/projects/current/tolomatic/
rm -rf $TOLOMATIC/examples/primates/result
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-$HADOOP_VERSION-streaming.jar \
    -cmdenv DATADIR=$TOLOMATIC/examples/primates/nodes \
    -input $TOLOMATIC/examples/primates/taxa.txt \
    -output $TOLOMATIC/examples/primates/result \
    -mapper mapper.pl \
    -combiner combiner.pl \
    -reducer reducer.pl \
    -verbose

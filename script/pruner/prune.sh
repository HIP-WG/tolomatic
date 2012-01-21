#!/bin/bash
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-$HADOOP_VERSION-streaming.jar \
    -input `pwd`/supertree \
    -output `pwd`/tolout \
    -mapper map.pl \
    -file map.pl \
    -file taxa.txt \
    -reducer aggregate \
    -verbose

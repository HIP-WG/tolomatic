#!/bin/bash
TOLOMATIC=/Users/rvosa/Dropbox/documents/projects/current/tolomatic/
RESULT=$TOLOMATIC/examples/tolweb/xmlbuilder
rm -rf $TOLOMATIC/examples/tolweb/xmlbuilder
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-$HADOOP_VERSION-streaming.jar \
    -input $TOLOMATIC/examples/tolweb/pruner_result.txt \
    -output $TOLOMATIC/examples/tolweb/xmlbuilder \
    -mapper mapper.pl \
    -combiner combiner.pl \
    -reducer reducer.pl \
    -verbose
RESULTFILE=$RESULT/part-00000
cat header.xml > $RESULT/result.xml
grep '<otu' $RESULTFILE >> $RESULT/result.xml
cat delimiter.xml >> $RESULT/result.xml
grep '<node' $RESULTFILE >> $RESULT/result.xml
grep '<edge' $RESULTFILE >> $RESULT/result.xml
cat footer.xml >> $RESULT/result.xml

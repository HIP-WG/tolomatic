PERL=perl
MKPATH=mkdir -p
RMRF=rm -rf
VERBOSITY=

SCRIPT=script
PRUNESCRIPTS=$(SCRIPT)/pruner
PRUNEMAPPER=$(PRUNESCRIPTS)/mapper.pl
PRUNECOMBINER=$(PRUNESCRIPTS)/combiner.pl
PRUNEREDUCER=$(PRUNESCRIPTS)/reducer.pl
EXAMPLES=examples
TMP=tmp
SAMPLE=sample.txt
OUTFILE=outfile.tre
OUTFORMAT=newick
RAWDATA=$(EXAMPLES)/rawdata

MAMMALTREE=$(RAWDATA)/Bininda-emonds_2007_mammals.nex
MAMMALDIR=$(EXAMPLES)/mammals
MAMMALMAP=$(MAMMALDIR)/map.txt

FISHTREE=$(RAWDATA)/Westneat_Lundberg_BigFishTree.nex
FISHDIR=$(EXAMPLES)/fishes
FISHMAP=$(FISHDIR)/map.txt

TOLTREE=$(RAWDATA)/TOL.xml
TOLDIR=$(EXAMPLES)/tol
TOLMAP=$(TOLDIR)/map.txt

ANGIOTREE=$(RAWDATA)/Smith_2011_angiosperms.txt
ANGIODIR=$(EXAMPLES)/angiosperms
ANGIOMAP=$(ANGIODIR)/map.txt

PHYLOMATICTREE=$(RAWDATA)/Phylomatictree.nex
PHYLOMATICDIR=$(EXAMPLES)/phylomatic
PHYLOMATICMAP=$(PHYLOMATICDIR)/map.txt

.PHONY : clean_mammals clean_fishes clean_tol clean_angio clean_phylomatic

init_all : init_mammals init_fishes init_tol init_angio init_phylomatic

init_mammals : $(MAMMALMAP)
clean_mammals : 
	$(RMRF) $(MAMMALDIR)

init_fishes : $(FISHMAP)
clean_fishes :
	$(RMRF) $(FISHDIR)

init_tol : $(TOLMAP)
clean_tol :
	$(RMRF) $(TOLDIR)

init_angio : $(ANGIOMAP)
clean_angio :
	$(RMRF) $(ANGIODIR)

init_phylomatic : $(PHYLOMATICMAP)
clean_phylomatic :
	$(RMRF) $(PHYLOMATICDIR)

$(MAMMALMAP) :
	$(MKPATH) $(MAMMALDIR)
	$(PERL) $(SCRIPT)/tree2table.pl \
		--file=$(MAMMALTREE) \
		--format=nexus \
		--dir=$(MAMMALDIR) > $@

$(FISHMAP) :
	$(MKPATH) $(FISHDIR)
	$(PERL) $(SCRIPT)/tree2table.pl \
		--file=$(FISHTREE) \
		--format=nexus \
		--dir=$(FISHDIR) > $@

$(TOLMAP) :
	$(MKPATH) $(TOLDIR)
	$(PERL) $(SCRIPT)/tree2table.pl \
		--file=$(TOLTREE) \
		--format=tolweb \
		--dir=$(TOLDIR) > $@

$(ANGIOMAP) :
	$(MKPATH) $(ANGIODIR)
	$(PERL) $(SCRIPT)/tree2table.pl \
		--file=$(ANGIOTREE) \
		--format=newick \
		--dir=$(ANGIODIR) > $@

$(PHYLOMATICMAP) :
	$(MKPATH) $(PHYLOMATICDIR)
	$(PERL) $(SCRIPT)/tree2table.pl \
		--file=$(PHYLOMATICTREE) \
		--format=nexus \
		--dir=$(PHYLOMATICDIR) > $@

sample_fishes : init_fishes
	$(RMRF) $(TMP) $(SAMPLE)
	$(PERL) $(SCRIPT)/randomtaxa.pl -i $(FISHMAP) -p $(PERCENTAGE) > $(SAMPLE)
	$(HADOOP_HOME)/bin/hadoop  jar $(HADOOP_HOME)/hadoop-$(HADOOP_VERSION)-streaming.jar \
		-cmdenv DATADIR=$(FISHDIR) \
		-cmdenv PERL5LIB="$(PERL5LIB):lib" \
		-input $(SAMPLE) \
		-output $(TMP) \
		-mapper $(PRUNEMAPPER) \
		-combiner $(PRUNECOMBINER) \
		-reducer $(PRUNEREDUCER) \
		$(VERBOSITY)
	$(PERL) $(SCRIPT)/newickify.pl -i $(TMP)/part-00000 -f $(OUTFORMAT) > $(OUTFILE)

sample_mammals : init_mammals
	$(RMRF) $(TMP) $(SAMPLE)
	$(PERL) $(SCRIPT)/randomtaxa.pl -i $(MAMMALMAP) -p $(PERCENTAGE) > $(SAMPLE)
	$(HADOOP_HOME)/bin/hadoop  jar $(HADOOP_HOME)/hadoop-$(HADOOP_VERSION)-streaming.jar \
		-cmdenv DATADIR=$(MAMMALDIR) \
		-cmdenv PERL5LIB="$(PERL5LIB):lib" \
		-input $(SAMPLE) \
		-output $(TMP) \
		-mapper $(PRUNEMAPPER) \
		-combiner $(PRUNECOMBINER) \
		-reducer $(PRUNEREDUCER) \
		$(VERBOSITY)
	$(PERL) $(SCRIPT)/newickify.pl -i $(TMP)/part-00000 -f $(OUTFORMAT) > $(OUTFILE)

sample_tol : init_tol
	$(RMRF) $(TMP) $(SAMPLE)
	$(PERL) $(SCRIPT)/randomtaxa.pl -i $(TOLMAP) -p $(PERCENTAGE) > $(SAMPLE)
	$(HADOOP_HOME)/bin/hadoop  jar $(HADOOP_HOME)/hadoop-$(HADOOP_VERSION)-streaming.jar \
		-cmdenv DATADIR=$(TOLDIR) \
		-cmdenv PERL5LIB="$(PERL5LIB):lib" \
		-input $(SAMPLE) \
		-output $(TMP) \
		-mapper $(PRUNEMAPPER) \
		-combiner $(PRUNECOMBINER) \
		-reducer $(PRUNEREDUCER) \
		$(VERBOSITY)
	$(PERL) $(SCRIPT)/newickify.pl -i $(TMP)/part-00000 -f $(OUTFORMAT) > $(OUTFILE)

sample_angio : init_angio
	$(RMRF) $(TMP) $(SAMPLE)
	$(PERL) $(SCRIPT)/randomtaxa.pl -i $(ANGIOMAP) -p $(PERCENTAGE) > $(SAMPLE)
	$(HADOOP_HOME)/bin/hadoop  jar $(HADOOP_HOME)/hadoop-$(HADOOP_VERSION)-streaming.jar \
		-cmdenv DATADIR=$(ANGIODIR) \
		-cmdenv PERL5LIB="$(PERL5LIB):lib" \
		-input $(SAMPLE) \
		-output $(TMP) \
		-mapper $(PRUNEMAPPER) \
		-combiner $(PRUNECOMBINER) \
		-reducer $(PRUNEREDUCER) \
		$(VERBOSITY)
	$(PERL) $(SCRIPT)/newickify.pl -i $(TMP)/part-00000 -f $(OUTFORMAT) > $(OUTFILE)

sample_phylomatic : init_phylomatic
	$(RMRF) $(TMP) $(SAMPLE)
	$(PERL) $(SCRIPT)/randomtaxa.pl -i $(PHYLOMATICMAP) -p $(PERCENTAGE) > $(SAMPLE)
	$(HADOOP_HOME)/bin/hadoop  jar $(HADOOP_HOME)/hadoop-$(HADOOP_VERSION)-streaming.jar \
		-cmdenv DATADIR=$(PHYLOMATICDIR) \
		-cmdenv PERL5LIB="$(PERL5LIB):lib" \
		-input $(SAMPLE) \
		-output $(TMP) \
		-mapper $(PRUNEMAPPER) \
		-combiner $(PRUNECOMBINER) \
		-reducer $(PRUNEREDUCER) \
		$(VERBOSITY)
	$(PERL) $(SCRIPT)/newickify.pl -i $(TMP)/part-00000 -f $(OUTFORMAT) > $(OUTFILE)
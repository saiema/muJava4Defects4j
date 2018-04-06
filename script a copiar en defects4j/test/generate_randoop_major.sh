#!/usr/bin/env bash
################################################################################
#
# This script tests the test generation using Randoop.
#
# args:
# $1 : Project
# $2 : Variant
# $3 : Type [f|b]
################################################################################
# Import helper subroutines and variables, and init Defects4J
export MAJOR_OPT="-J-Dmajor.export.mutants=true"
major_mutants_dir="/tmp/major_mutants"
export MAJOR_OPT="-J-Dmajor.export.mutants=true -J-Dmajor.export.directory=$major_mutants_dir"
if [ -d "$major_mutants_dir" ]; then
	rm -rf $major_mutants_dir
fi
source test.include
init

# Directory for Randoop test suites
randoop_dir=$TMP_DIR/randoop
if [ -d "$randoop_dir" ]; then
	rm -rf $randoop_dir
fi

pid="$1"
bid="$2"
type="$3"

vid=${bid}$type
# Test suite source and number
suite_src=randoop
suite_num=1
suite_dir=$randoop_dir/$pid/$suite_src/$suite_num

run_randoop.pl -p $pid -v $vid -n 1 -o $randoop_dir -b 10 || die "run Randoop on $pid-$vid"
fix_test_suite.pl -p $pid -d $suite_dir || die "fix test suite"

generate_mutants.pl -p $pid -b $bid -y $type

if [ -d $randoop_dir ]; then
	echo "Randoop test suite folder found"
	testSuite="$randoop_dir/$pid/randoop/1/$pid-$bid$type-randoop.1.tar.bz2"
	echo $testSuite
	if [ -f $testSuite ]; then
		echo "Randoop test suite found : $testSuite"
	fi
fi

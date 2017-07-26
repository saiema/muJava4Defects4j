# muJava4Defects4j
A script to use mujava++ along with defetcs4j

## Background

### muJava++

muJava++ is a work based on muJava (https://github.com/EpsilonX/MuJava, https://cs.gmu.edu/~offutt/mujava/) that improves on

* A design focused in using muJava++ as a library with a simple API
* A new operator family (PRVO)
* Avoiding repeating mutants
* Facilitate the addition of new operators
* Support for code comments to specify statements to mutate

muJava++ can be found in it's repository (https://github.com/saiema/MuJava), the latests additions that are not yet merged with the master branch, can be found in branch https://github.com/saiema/MuJava/tree/mujava2-dev-1.7.

This project currently contains all needed libraries as jar files, so there is no need to download anything else (excepto for defects4j)

### Defects4j

Defects4j is a benchmark containing several programs versions, each with a single bug version and a fixed version. Each program version contains a set of developer written tests, in this set a single test expose the bug in the bugged version and passes in the fixed version.

Defects4j repository can be found in https://github.com/rjust/defects4j, a web page with help about using defects4j http://people.cs.umass.edu/~rjust/defects4j/html_doc/defects4j.html, and René Just et al paper in which Defects4j was presented https://homes.cs.washington.edu/~mernst/pubs/bug-database-issta2014.pdf.

## Requirements

This project requires java-7 (Defects4j doesn't work with java-8 or later for the moment), and you must install defects4j (instruccions can be found in defects4j repository)

## Usage

The script to use is 'runMujavaWithD4J.sh'. You will need to modify the line 24 'JAVA_HOME_TO_USE="/usr/lib/jvm/java-7-oracle/"' according to where you have java-7 installed. The arguments to the script are:

1. Project (Chart, Lang, etc)
2. Variant number (1, 2, etc)
3. mujava++ properties template file (the project contains some demo properties templates)
4. 0 or non-zero for using all tests or only triggering tests

You will need to modify the file 'default_basic.properties' accordingly.

## Extra notes

Sorry for the poor documentation, this will be improved as soon as I can.

#!/bin/bash

#$1 : Project (Chart, Lang, etc)
#$2 : variant number
#$3 : variant type
#$3 : mujava++ properties file
#$4 : -MC (for variant modified class) or fully qualified name of the class to analyze (to use several classes separated by :)
#$5 : -MJ or mutants folder with the following structure : rootFolder/foldersForEachMutant/fully qualified path ending with a single java file
#$6 : external jars folder (to be used by defects4j and mujava); - to specify no external jar folder
#$7 : external classpath (relative to checkout dir, separated by :); - to specify no external classpath
#$8 : -A (to use all tests), -T (to use triggering tests), and -Z (to used zipped tests as java files)
#$9(only with -Z) : bz2 or gz test suite file location

# This will run muJava++ usigin a template properties file
# The properties file will be modified to define which classes to mutate and which tests to use.

function isSeparatingLine() {
	local input=$1
	local  __resultvar=$2
	if [ "$input" == "--------------------------------------------------------------------------------" ]; then
		eval $__resultvar=1
	else
		eval $__resultvar=0
	fi
}

function beginswith() { case $2 in "$1"*) true;; *) false;; esac; }

JAVA_HOME_TO_USE="/usr/lib/jvm/java-7-oracle/"
CURRENT_DIR=$(pwd)
MUJAVA_HOME="mujava"
MUJAVA_LIB_DIR=$MUJAVA_HOME"/libs"
JUNIT_LIB=$MUJAVA_LIB_DIR"/junit.jar"
MUJAVA_JAR=$MUJAVA_HOME"/mujava++.jar"
pushd $MUJAVA_LIB_DIR
MUJAVA_LIBS=$(find . | awk '/\.jar/' | sed "s/\\.\\///g" | xargs -I {} echo $MUJAVA_LIB_DIR/{}":")
MUJAVA_LIBS="${MUJAVA_LIBS::-1}"
MUJAVA_LIBS=$(tr -d "\n\r" < <(echo $MUJAVA_LIBS))
MUJAVA_LIBS=$(echo $MUJAVA_LIBS | sed "s/ //g")
popd
echo "CURRENT DIR: $CURRENT_DIR"
echo "MUJAVA HOME: $MUJAVA_HOME"
echo "MUJAVA LIBS FOLDER: $MUJAVA_LIB_DIR"
echo "MUJAVA JAR: $MUJAVA_JAR"
echo "MUJAVA LIBS: $MUJAVA_LIBS"

project="$1"
variant="$2"
type="$3"
propertiesFile="$4"
classOption="$5"
mutantsOrigin="$6"
externalJarFolder="$7"
externalCP="$8"
triggeringTests="$9"
zipPath="${10}"

info=$(defects4j info -p $project -b $variant)
exitCode="$?"

if [[ ! $exitCode == "0" ]]; then
	"defects4j info command failed"
	exit 1;
fi

checkoutVariant=$variant"f"
checkoutDir="/tmp/"$project"_"$variant"_fixed"

checkout=$(defects4j checkout -p $project -v $checkoutVariant -w $checkoutDir)
exitCode="$?"

if [[ ! $exitCode == "0" ]]; then
	"defects4j checkout command failed"
	exit 2;
fi

pushd $checkoutDir								#ENTERED TO CHECKOUDIR
pwd

projectJUnit="lib/junit.jar"
echo "searching and replacing project JUnit jar in $projectJUnit ..."

if [ -f $projectJUnit ]; then
	echo "project JUnit jar found..."
	rm $projectJUnit
	echo "...removed..."
	cp "$CURRENT_DIR/$JUNIT_LIB" "lib"
	if [ -f $projectJUnit ]; then
		echo "...and replaced"
	else
		echo "...but failed to replace"
		exit 2;
	fi
else
	echo "project JUnit jar not found."
fi

echo "Current java home: $JAVA_HOME"
jh_backup=$JAVA_HOME
echo "Changing java home to $JAVA_HOME_TO_USE"
export JAVA_HOME=$JAVA_HOME_TO_USE
echo "New java home: $JAVA_HOME"

echo "Current J2REDIR: $J2REDIR"
echo "Changing J2REDIR to $JAVA_HOME_TO_USE""jre"
export J2REDIR=$JAVA_HOME_TO_USE"jre"
echo "New J2REDIR: $J2REDIR"

echo "Current J2SDKDIR: $J2SDKDIR"
echo "Changing J2SDKDIR to $JAVA_HOME_TO_USE"
export J2SDKDIR=$JAVA_HOME_TO_USE
echo "New J2SDKDIR: $J2SDKDIR"

triggeringTestsFound=0
#Obtaining test source folder
while read -r line ; do
		#echo "Processing $line"
		if [ "$line" == "Root cause in triggering tests:" ]; then
		#	echo "triggering tests to follow"
			triggeringTestsFound=1
			continue
		fi
		if [ "$triggeringTestsFound" -eq "1" ]; then
			isSeparatingLine "$line" isLine
			if [ "$isLine" -eq "0" ]; then
				if beginswith "- " "$line"; then		    	
					cleanedLine="${line/- /}"
					testAsPath=$(echo $cleanedLine | sed -r 's/::.*$//' | sed -r "s/\\./\\//g")".java"
		#			echo "$testAsPath"
					fullPathToTTest=$(find $checkoutDir -wholename "*$testAsPath")
					testSrcDir="${fullPathToTTest/$testAsPath}"
					echo $testSrcDir
					break
				else
					continue			
				fi
			else
				triggeringTestsFound=0
		#		echo "Finishing processing triggering tests"
				break
			fi
		fi
	done < <(echo "$info")
#===========================


sourceDir=$checkoutDir"/source/"
binDir=$checkoutDir"/build/"
testBinDir=$checkoutDir"/build-tests/"
testSrcDir=$testSrcDir
projectLibDir=$checkoutDir"/lib"
pushd $projectLibDir					#ENTERED Project lib dir
projectJars=$(find . | awk '/\.jar/' | sed "s/\\.\\///g" | xargs -I {} echo $projectLibDir/{}":")
projectJars="${projectJars::-1}"
projectJars=$(tr -d "\n\r" < <(echo $projectJars))
projectJars=$(echo $projectJars | sed "s/ //g")
popd							#EXITED Project lib dir (should be in initial directory)

externalJars=""
if [[ ! "$externalJarFolder" == "-" ]]; then
	pushd $externalJarFolder					#ENTERED external jar dir
	find . | awk '/\.jar/' | sed "s/\\.\\///g" | xargs -I {} cp {} "$projectLibDir"
	externalJars=$(find . | awk '/\.jar/' | sed "s/\\.\\///g" | xargs -I {} echo $externalJarFolder/{}":")
	externalJars="${externalJars::-1}"
	externalJars=$(tr -d "\n\r" < <(echo $externalJars))
	externalJars=$(echo $externalJars | sed "s/ //g")
	popd								#EXITED external jar dir (should be in initial directory)
fi
echo "external jars: $externalJars"


triggeringTestsFound=0
tests=""
echo "$triggeringTests"
singleTest=""
if [[ "$triggeringTests" == "-T" ]]; then
	while read -r line ; do
		echo "Processing $line"
		if [ "$line" == "Root cause in triggering tests:" ]; then
			echo "triggering tests to follow"
			triggeringTestsFound=1
			continue
		fi
		if [ "$triggeringTestsFound" -eq "1" ]; then
			isSeparatingLine "$line" isLine
			if [ "$isLine" -eq "0" ]; then
				if beginswith "- " "$line"; then		    	
					cleanedLine="${line/- /}"
					cleanedLine=$(echo $cleanedLine | sed -r 's/::.*$//')
					singleTest=$cleanedLine
					if [[ -z "${tests// }" ]]; then
						tests=$cleanedLine
					else
						tests=$tests" "$cleanedLine
					fi
				else
					continue			
				fi
			else
				triggeringTestsFound=0
				echo "Finishing processing triggering tests"
				break
			fi
		fi
	done < <(echo "$info")
elif [[ "$triggeringTests" == "-A" ]]; then
	pushd $testSrcDir 							#ENTERED TESTSBINDIR
	pwd	
	while read -r line ; do
		if [[ -z "${tests// }" ]]; then
				tests=$line
				singleTest=$line
			else
				tests=$tests" "$line
			fi
	done < <(find . | awk '/.*Tests\.java/' | sed "s/\\.\\///g" | sed "s/\\//\\./g" | sed "s/\\.java//g")
	popd 													
	pwd
elif [[ "$triggeringTests" == "-Z" ]]; then
	#unzip and copy tests to defects4j test source folder
	#this option will work as calling with -A but will change the original with the provided tests
	root="${zipPath#.}";root="${zipPath%"$root"}${root%.*}"
	ext="${zipPath#"$root"}"
	tarOptions=""	
	if [[ "$ext" == ".bz2" ]]; then
		tarOptions="xvjf"
	elif [[ "$ext" == ".gz" ]]; then
		tarOptions="xvzf"
	else
		echo "Unsupported file format for test suites $ext"
		exit 6
	fi
	rm -rf "${testSrcDir::-1}"
	mkdir "${testSrcDir::-1}"
	cp "$zipPath" "$testSrcDir"
	pushd "$testSrcDir"						#ENTERED TESTSSRCDIR
	pwd
	tar "$tarOptions" "$zipPath"
	zipFile=$(basename $zipPath)
	rm -f "$testSrcDir$zipFile"
	while read -r line ; do
		if [[ -z "${tests// }" ]]; then
				tests=$line
				singleTest=$line
			else
				tests=$tests" "$line
			fi
	done < <(find . | awk '/.*\.java/' | sed "s/\\.\\///g" | sed "s/\\//\\./g" | sed "s/\\.java//g")
	popd								#EXITED TESTSSRCDIR (should be in initial directory)
	pwd
else
	echo "Unknown option $triggeringTests"
	exit 5
fi

echo "Tests found : $tests"


compile=$(defects4j compile)
exitCode="$?"

if [[ ! $exitCode == "0" ]]; then
	echo "defects4j compile command failed"
	exit 3;
fi

#SEARCH A COMPILED TEST
echo $singleTest
if [[ -z "${singleTest// }" ]]; then
	echo "Contact your java black wizard!"
	exit 7
fi
testAsPath=$(echo $singleTest | sed -r "s/\\./\\//g")".class"
echo "$testAsPath"
fullPathToSingleTest=$(find $checkoutDir -wholename "*$testAsPath")
testBinDir="${fullPathToSingleTest/$testAsPath}"
echo $testBinDir
#======================

#testCommand=$(defects4j 'test')
#exitCode="$?"

#if [[ ! $exitCode == "0" ]]; then
#	echo "defects4j test command failed"
#	exit 4;
#fi

popd											#EXITED CHECKOUTDIR (should be in initial directory)
pwd

modifiedClassesFound=0
modifiedClasses=""

singleClassToRun=""
callMJwithAllClasses=0
if [[ "$classOption" == "-MC" ]]; then
	while read -r line ; do
		echo "Processing $line"
		if [ "$line" == "List of modified sources:" ]; then
	  		echo "modified classes to follow"
	  		modifiedClassesFound=1
			continue
		fi
		if [ "$modifiedClassesFound" -eq "1" ]; then
			isSeparatingLine "$line" isLine
			if [ "$isLine" -eq "0" ]; then
				cleanedLine="${line/- /}"
				if [[ -z "${modifiedClasses// }" ]]; then
					singleClassToRun=$cleanedLine
					modifiedClasses=$cleanedLine
				else
					modifiedClasses=$modifiedClasses","$cleanedLine
				fi
			else
				modifiedClassesFound=0
				echo "Finishing processing modified classes"
				break
			fi
		fi
	done < <(echo "$info")
else
	callMJwithAllClasses=1
	modifiedClasses=""
	oldIFS=$IFS
	IFS=':'
	a=($classOption)
	for i in ${a[*]}
	do
		echo $i
		if [[ -z "${modifiedClasses// }" ]]; then
			modifiedClasses=$i
			singleClassToRun=$i
		else
			modifiedClasses=$modifiedClasses" "$i
		fi
	done
	IFS=$oldIFS
	echo $modifiedClasses
	#modifiedClasses="$classOption"
	#singleClassToRun="$classOption"
fi

echo "Clasess to mutate: "$modifiedClasses

#SEARCH A COMPILED CLASS
echo "Single class to run: $singleClassToRun"
if [[ -z "${singleClassToRun// }" ]]; then
	echo "Contact your java black wizard!"
	exit 8
fi
classAsPath=$(echo $singleClassToRun | sed -r "s/\\./\\//g")".class"
echo "class as path: $classAsPath"
fullPathToSingleClass=$(find $checkoutDir -wholename "*$classAsPath" | head -n 1)
echo "full path single class: $fullPathToSingleClass"
binDir="${fullPathToSingleClass/$classAsPath}"
echo "Bin dir: $binDir"
#======================

if [ "$mutantsOrigin" == "-MJ" ]; then
	echo "using muJava++ to generate mutants"
else
	echo "using external mutants root folder: $mutantsOrigin"
	echo "you must use a template with the option mutation.basic.useExternalMutants set as true"
fi

if [[ "$callMJwithAllClasses" -eq "0" ]]; then
	declare -a a="(${modifiedClasses/,/ })";
	for i in ${a[*]}
	do 
		echo "Methods for class $i"
		methods=""
		pushd $binDir 							#ENTERED BINDIR
		pwd
		while read -r line ; do
			if [[ -z "${methods// }" ]]; then
				methods=$line
			else
				methods=$methods" "$line
			fi
		done < <(echo $(javap $i | grep -o "[a-zA-Z0-9]*(".*")" | sed 's/(.*)//g' | grep -o "^[a-z].*"))
		popd 									#EXITED BINDIR (should be in initial directory)
		pwd
		newPropertiesFile="$i""-""${propertiesFile/template-/}"
		cp $propertiesFile $newPropertiesFile
		sed -i "s|<MUTFOLDER>|$mutantsOrigin|g" $newPropertiesFile
		sed -i "s|<SOURCEDIR>|$sourceDir|g" $newPropertiesFile
		sed -i "s|<BINDIR>|$binDir|g" $newPropertiesFile
		sed -i "s|<TESTSBINDIR>|$testBinDir|g" $newPropertiesFile
		sed -i "s|<CLASSTOMUTATE>|$i|g" $newPropertiesFile
		sed -i "s|<METHODS>|$methods|g" $newPropertiesFile
		sed -i "s|<TESTS>|$tests|g" $newPropertiesFile
	done
else
	newPropertiesFile="several-""${propertiesFile/template-/}"
	cp $propertiesFile $newPropertiesFile
	sed -i "s|<MUTFOLDER>|$mutantsOrigin|g" $newPropertiesFile
	sed -i "s|<SOURCEDIR>|$sourceDir|g" $newPropertiesFile
	sed -i "s|<BINDIR>|$binDir|g" $newPropertiesFile
	sed -i "s|<TESTSBINDIR>|$testBinDir|g" $newPropertiesFile
	sed -i "s|<CLASSTOMUTATE>|$modifiedClasses|g" $newPropertiesFile
	sed -i "s|<TESTS>|$tests|g" $newPropertiesFile
fi

externalClasspath=""
if [[ ! "$externalCP" == "-" ]]; then
	externalClasspath=""
	oldIFS=$IFS
	IFS=':'
	a=($externalCP)
	#declare -a a="(${externalCP/:/ })";
	for i in ${a[*]}
	do
		echo $i
		externalClasspath=$externalClasspath":"$checkoutDir"/"$i
		echo $externalClasspath	
	done
	IFS=$oldIFS
fi

echo "Running mujava with properties file: $newPropertiesFile"
#echo "java -cp $MUJAVA_LIBS:$MUJAVA_JAR mujava.app.Main $newPropertiesFile"
mujavaClasspath=$MUJAVA_LIBS:$MUJAVA_JAR:$binDir:$testBinDir:$projectLibDir$externalClasspath
if [[ ! -z "${tests// }" ]]; then
	mujavaClasspath=$mujavaClasspath:$projectJars
fi
if [[ ! -z "${externalJars// }" ]]; then
	mujavaClasspath=$mujavaClasspath:$externalJars
fi

$(java -version)
java -XX:+UseG1GC -cp $mujavaClasspath "mujava.app.Main" -p $newPropertiesFile

echo "restoring java home to $jh_backup"
export JAVA_HOME=$jh_backup
echo "java home restored to $JAVA_HOME"

echo "restoring J2REDIR to $jh_backup""/jre"
export J2REDIR=$jh_backup"/jre"
echo "java J2REDIR restored to $J2REDIR"

echo "restoring J2SDKDIR to $jh_backup"
export J2SDKDIR=$jh_backup
echo "java J2SDKDIR to $J2SDKDIR"


#javap org.jfree.chart.renderer.category.AbstractCategoryItemRenderer | grep -o "[a-zA-Z0-9]*(".*")" | sed 's/(.*)//g' | grep -o "^[a-z].*" (OBTENER METODOS)

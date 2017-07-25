#!/bin/bash

#$1 : Project (Chart, Lang, etc)
#$2 : variant number
#$3 : mujava++ properties file
#$4 : 0 or non-zero for using all tests or only triggering tests


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
propertiesFile="$3"
triggeringTests="$4"

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


#echo "Breaking project"
#rm $checkoutDir"/lib/servlet.jar"


compile=$(defects4j compile)
exitCode="$?"

if [[ ! $exitCode == "0" ]]; then
	"defects4j compile command failed"
	exit 3;
fi

testCommand=$(defects4j 'test')
exitCode="$?"

if [[ ! $exitCode == "0" ]]; then
	"defects4j test command failed"
	exit 4;
fi

popd											#EXITED CHECKOUTDIR (should be in initial directory)
pwd

sourceDir=$checkoutDir"/source/"
binDir=$checkoutDir"/build/"
testBinDir=$checkoutDir"/build-tests/"
projectLibDir=$checkoutDir"/lib"
pushd $projectLibDir
projectJars=$(find . | awk '/\.jar/' | sed "s/\\.\\///g" | xargs -I {} echo $projectLibDir/{}":")
projectJars="${projectJars::-1}"
projectJars=$(tr -d "\n\r" < <(echo $projectJars))
projectJars=$(echo $projectJars | sed "s/ //g")
popd

modifiedClassesFound=0
modifiedClasses=""


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

echo "Clases to mutate: "$modifiedClasses

triggeringTestsFound=0
tests=""
if [ "$triggeringTests" -ne "0" ]; then
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
else
	pushd $testBinDir 							#ENTERED TESTSBINDIR
	pwd	
	while read -r line ; do
		if [[ -z "${tests// }" ]]; then
				tests=$line
			else
				tests=$tests" "$line
			fi
	done < <(find . | awk '/.*Tests\.class/' | sed "s/\\.\\///g" | sed "s/\\//\\./g" | sed "s/\\.class//g")
	popd 										#EXITED TESTSBINDIR (should be in initial directory)
	pwd
fi

echo "Tests found : $tests"

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
	sed -i "s|<SOURCEDIR>|$sourceDir|g" $newPropertiesFile
	sed -i "s|<BINDIR>|$binDir|g" $newPropertiesFile
	sed -i "s|<TESTSBINDIR>|$testBinDir|g" $newPropertiesFile
	sed -i "s|<CLASSTOMUTATE>|$i|g" $newPropertiesFile
	sed -i "s|<METHODS>|$methods|g" $newPropertiesFile
	sed -i "s|<TESTS>|$tests|g" $newPropertiesFile
done

echo "Running mujava with properties file: $newPropertiesFile"
#echo "java -cp $MUJAVA_LIBS:$MUJAVA_JAR mujava.app.Main $newPropertiesFile"
mujavaClasspath=$MUJAVA_LIBS:$MUJAVA_JAR:$binDir:$testBinDir:$projectLibDir
if [[ ! -z "${tests// }" ]]; then
	mujavaClasspath=$mujavaClasspath:$projectJars
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

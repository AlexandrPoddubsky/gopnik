#!/bin/bash -e

source ./colors.bash

printHelp() {
	echo "------------------"
	echo "  bootstrap.bash  "
	echo "------------------"
	echo
	echo "Options:"
	echo
	echo "  --version \"v0.0.0\" - Vesion"
	echo "  -h | --help - Show this help"
	echo
	exit 1
}

while [[ $# > 0 ]]
do
	key="$1"
	shift
	case $key in
		--version)
			VERSION="$1"
			shift
		;;
		-h|--help)
			printHelp
		;;
		*)
			# unknown option
		;;
	esac
done

echo "${bold}${magenta}Generating Go code...${normal}"
protoc --go_out=src/tilerender slave/proto/*.proto
go-bindata -o src/gopnikprerender/bindata.go  -prefix "src/gopnikprerender/" src/gopnikprerender/public/fonts/ src/gopnikprerender/public/css/ src/gopnikprerender/public/js/ src/gopnikprerender/templates/
go-bindata -o src/gopnikperf/bindata.go  -prefix "src/gopnikperf/" src/gopnikperf/public/fonts/ src/gopnikperf/public/css/ src/gopnikperf/public/css/images src/gopnikperf/public/js/ src/gopnikperf/templates/
go-bindata -o src/sampledata/bindata.go -pkg "sampledata"  -prefix "sampledata_tiles" sampledata_tiles/

cat << EOF > src/sampledata/env.go
package sampledata

const Stylesheet = "`pwd`/sampledata/stylesheet.xml"
const MapnikInputPlugins = "`mapnik-config --input-plugins`"
var SlaveCmd = []string{"`pwd`/bin/gopnikslave",
		"-stylesheet", Stylesheet,
		"-pluginsPath", MapnikInputPlugins}
EOF

echo "${bold}${magenta}Configuring plugins...${normal}"
DEFPLUGINS=`ls -d ./src/defplugins/* | egrep -o 'defplugins/[a-z]+'`
PLUGINS_CONFIG="src/plugins_enabled/config.go"
cat << EOF > $PLUGINS_CONFIG
package plugins_enabled

import (
EOF
for p in $DEFPLUGINS; do
	echo -e "\t_ \"$p\"" >> $PLUGINS_CONFIG
done

echo ')' >> $PLUGINS_CONFIG

echo "${bold}${magenta}Setup version...${normal}"
VERSION_CONFIG="src/program_version/version.go"
if [[ "x$VERSION" != "x" ]]; then
cat << EOF > $VERSION_CONFIG
package program_version

func init() {
	version = "$VERSION"
	publishVersion()
}
EOF
fi

echo "${bold}${magenta}Configuring C++ code...${normal}"
[ -d slave_build ] || mkdir slave_build
cd slave_build
cmake ../slave
cd - > /dev/null

echo "${bold}${green}Done${normal}"

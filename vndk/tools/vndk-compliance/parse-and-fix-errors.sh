#!/bin/bash
if [ "$PWD" != "$ANDROID_BUILD_TOP" ]; then
echo "Run in root directory"
exit 1
fi
if [ ! -f "log" ]; then
echo "log not found"
exit 1
fi
echo "Parsing log"
cat log | grep "FAILED\|error:" > log.error
ADD_TO_HEADER_LIBS=(hardware system cutils utils)
ADD_TO_SHARED_LIBS=(log)
ALL_LIBS=(${ADD_TO_HEADER_LIBS[@]} ${ADD_TO_SHARED_LIBS[@]})
for lib in "${ALL_LIBS[@]}"; do
echo "Parsing log.error for $lib"
cat log.error | grep -B1 "error: '$lib\/" | grep FAILED | awk 'BEGIN{FS="_intermediates"}{print $1}' | awk 'BEGIN{FS="S/";}{print $2}' | sort -u > log.$lib
echo "Parsing log.$lib"
for module in `cat log.$lib`; do find . -name Android.\* | xargs grep -w -H $module | grep "LOCAL_MODULE\|name:"; done > log.$lib.paths
echo "log.$lib.paths: remove lines for devices other than the one you are compiling for."
echo "Remove duplicate makefile paths"
read enter
if [ -s "log.$lib.paths" ]; then
not_vendor_list=`cat log.$lib.paths | awk 'BEGIN{FS=":"}{print $1}' | xargs grep -L 'LOCAL_PROPRIETARY_MODULE\|LOCAL_VENDOR_MODULE'`
else
not_vendor_list=
fi
if [ ! -z "$not_vendor_list" ]; then
echo "These modules don't have proprietary or vendor flag set."
printf "%s\n" $not_vendor_list
echo "Check makefile and update log."$lib".paths"
read enter
fi
done
for lib in "${ADD_TO_HEADER_LIBS[@]}"; do
echo "Patching makefiles to fix "$lib" errors"
cat log.$lib.paths | awk 'BEGIN{FS=":"}{print $1}' | xargs sed -i '/include \$(BUILD/i LOCAL_HEADER_LIBRARIES += lib'$lib'_headers'
echo "Checking for unsaved files"
repo status
echo "Please COMMIT them"
read enter
done
for lib in "${ADD_TO_SHARED_LIBS[@]}"; do
echo "Patching makefiles to fix "$lib" errors"
if [ $lib -eq "log" ]; then
cat log.$lib.paths | awk 'BEGIN{FS=":"}{print $1}' | xargs sed -i '/include \$(BUILD/i ifdef BOARD_VNDK_VERSION\nLOCAL_SHARED_LIBRARIES += lib'$lib'\nendif'
else
cat log.$lib.paths | awk 'BEGIN{FS=":"}{print $1}' | xargs sed -i '/include \$(BUILD/i LOCAL_SHARED_LIBRARIES += lib'$lib
fi
echo "Checking for unsaved files"
repo status
echo "Please COMMIT them"
read enter
done

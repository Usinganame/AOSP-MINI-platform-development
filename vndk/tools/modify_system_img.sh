#!/bin/bash -ex
usage () {
echo "See online documentation"
}
exit_badparam () {
echo "ERROR: $1" >&2
usage
exit 1
}
cleanup_and_exit () {
readonly result="$?"
rm -rf "$TEMP_DIR"
exit "$result"
}
trap cleanup_and_exit EXIT
while getopts :v: opt; do
case "$opt" in
 v)
readonly VENDOR_VERSION="$OPTARG"
;;
\?)
exit_badparam "Invalid: -"$OPTARG""
;;
:)
exit_badparam ""$OPTARG" requires argument."
;;
esac
done
shift "$((OPTIND-1))"
if [[ $# -lt 1 || $# -gt 2 ]]; then
exit_badparam "wrong # of arguments"
fi
readonly SYSTEM_TARGET_FILES="$1"
readonly NEW_SPL="$2"
if [[ ! -f "$SYSTEM_TARGET_FILES" ]]; then
exit_badparam "Couldn't get package, "$SYSTEM_TARGET_FILES""
fi
if [[ $# -eq 2 ]] && [[ ! "$NEW_SPL" =~ ^[0-9]{4}-(0[0-9]|1[012])-([012][0-9]|3[01])$ ]]; then
exit_badparam "<new_security_patch_level> need YYYY-MM-DD format"
fi
if [[ -z "${ANDROID_BUILD_TOP+x}" ]]; then
build_top=""
else
build_top="$ANDROID_BUILD_TOP"/
fi
readonly add_img_to_target_files="$build_top"build/make/tools/releasetools/add_img_to_target_files.py
if [[ ! -f "$add_img_to_target_files" ]]; then
echo "Error: Can't find script,", "$add_img_to_target_files"
echo "Run from root directory"
exit 1
fi
readonly TEMP_DIR="$(mktemp -d /tmp/"$(basename $0)"_XXXXXXXX)"
readonly SPL_PROPERTY_NAME="ro.build.version.security_patch"
readonly RELEASE_VERSION_PROPERTY_NAME="ro.build.version.release"
readonly VNDK_VERSION_PROPERTY="ro.vndk.version"
readonly VNDK_VERSION_PROPERTY_OMR1="$VNDK_VERSION_PROPERTY"=27
readonly BUILD_PROP_PATH="SYSTEM/build.prop"
readonly PROP_DEFAULT_PATH="SYSTEM/etc/prop.default"
unzip "$SYSTEM_TARGET_FILES" "$BUILD_PROP_PATH" "$PROP_DEFAULT_PATH" -d "$TEMP_DIR"
readonly BUILD_PROP_FILE="$TEMP_DIR"/"$BUILD_PROP_PATH"
readonly PROP_DEFAULT_FILE="$TEMP_DIR"/"$PROP_DEFAULT_PATH"
if [[ -f "$BUILD_PROP_FILE" ]]; then
readonly CURRENT_SPL=$(sed -n -r "s/^"$SPL_PROPERTY_NAME"=(.*)$/\1/p" "$BUILD_PROP_FILE")
readonly CURRENT_VERSION=$(sed -n -r "s/^"$RELEASE_VERSION_PROPERTY_NAME"=(.*)$/\1/p" "$BUILD_PROP_FILE")
echo "Reading build.prop..."
echo "  Current security patch level: "$CURRENT_SPL""
echo "  Current release version: "$CURRENT_VERSION""
if [[ "$NEW_SPL" != "" ]]; then
if [[ "$CURRENT_SPL" == "" ]]; then
echo "ERROR: Can't find "$SPL_PROPERTY_NAME" in "$BUILD_PROP_PATH""
exit 1
else
sed -i "s/^"$SPL_PROPERTY_NAME"=.*$/"$SPL_PROPERTY_NAME"="$NEW_SPL"/" "$BUILD_PROP_FILE"
echo "Replacing..."
echo "  New security patch level: "$NEW_SPL""
fi
fi
if [[ "$VENDOR_VERSION" != "" ]]; then
if [[ "$CURRENT_VERSION" == "" ]]; then
echo "ERROR: Can't find "$RELEASE_VERSION_PROPERTY_NAME" in "$BUILD_PROP_PATH""
exit 1
 else
sed -i "s/^"$RELEASE_VERSION_PROPERTY_NAME"=.*$/"$RELEASE_VERSION_PROPERTY_NAME"="$VENDOR_VERSION"/" "$BUILD_PROP_FILE"
echo "Replacing..."
echo "  New release version for vendor.img: "$VENDOR_VERSION""
fi
if [[ "$VENDOR_VERSION" == "8.1.0" ]]; then
if [[ -f "$PROP_DEFAULT_FILE" ]]; then
readonly CURRENT_VNDK_VERSION=$(sed -n -r "s/^"$VNDK_VERSION_PROPERTY"=(.*)$/\1/p" "$PROP_DEFAULT_FILE")
if [[ "$CURRENT_VNDK_VERSION" != "" ]]; then
echo "WARNING: "$VNDK_VERSION_PROPERTY" is already set to "$CURRENT_VNDK_VERSION" in "$PROP_DEFAULT_PATH""
echo "Didn't overwrite "$VNDK_VERSION_PROPERTY""
else
echo "Adding \""$VNDK_VERSION_PROPERTY_OMR1"\" to "$PROP_DEFAULT_PATH" for O-MR1 vendor image."
sed -i -e "\$a\#\n\# FOR O-MR1 DEVICES\n\#\n"$VNDK_VERSION_PROPERTY_OMR1"" "$PROP_DEFAULT_FILE"
fi
else
echo "ERROR: Can't find "$PROP_DEFAULT_PATH" in "$SYSTEM_TARGET_FILES""
fi
fi
fi
else
echo "ERROR: Can't find "$BUILD_PROP_PATH" in "$SYSTEM_TARGET_FILES""
exit 1
fi
(
cd "$TEMP_DIR"
zip -ur "$SYSTEM_TARGET_FILES" ./*
)
zip -d "$SYSTEM_TARGET_FILES" IMAGES/system\*
"$add_img_to_target_files" -a "$SYSTEM_TARGET_FILES"
echo "Done."

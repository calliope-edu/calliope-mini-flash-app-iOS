#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR

if [ -z ${UNLOCALIZED_RESOURCES_FOLDER_PATH+x} ]; then
  # If UNLOCALIZED_RESOURCES_FOLDER_PATH is not set, then there's nowhere for us to copy
  # resources to, so exit 0 (signalling the script phase was successful).
  exit 0
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

RESOURCES_TO_COPY=${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt
> "$RESOURCES_TO_COPY"

XCASSET_FILES=()

# This protects against multiple targets copying the same framework dependency at the same time. The solution
# was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")

case "${TARGETED_DEVICE_FAMILY:-}" in
  1,2)
    TARGET_DEVICE_ARGS="--target-device ipad --target-device iphone"
    ;;
  1)
    TARGET_DEVICE_ARGS="--target-device iphone"
    ;;
  2)
    TARGET_DEVICE_ARGS="--target-device ipad"
    ;;
  3)
    TARGET_DEVICE_ARGS="--target-device tv"
    ;;
  4)
    TARGET_DEVICE_ARGS="--target-device watch"
    ;;
  *)
    TARGET_DEVICE_ARGS="--target-device mac"
    ;;
esac

install_resource()
{
  if [[ "$1" = /* ]] ; then
    RESOURCE_PATH="$1"
  else
    RESOURCE_PATH="${PODS_ROOT}/$1"
  fi
  if [[ ! -e "$RESOURCE_PATH" ]] ; then
    cat << EOM
error: Resource "$RESOURCE_PATH" not found. Run 'pod install' to update the copy resources script.
EOM
    exit 1
  fi
  case $RESOURCE_PATH in
    *.storyboard)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .storyboard`.storyboardc $RESOURCE_PATH --sdk ${SDKROOT} ${TARGET_DEVICE_ARGS}" || true
      ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .storyboard`.storyboardc" "$RESOURCE_PATH" --sdk "${SDKROOT}" ${TARGET_DEVICE_ARGS}
      ;;
    *.xib)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .xib`.nib $RESOURCE_PATH --sdk ${SDKROOT} ${TARGET_DEVICE_ARGS}" || true
      ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .xib`.nib" "$RESOURCE_PATH" --sdk "${SDKROOT}" ${TARGET_DEVICE_ARGS}
      ;;
    *.framework)
      echo "mkdir -p ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}" || true
      mkdir -p "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" $RESOURCE_PATH ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}" || true
      rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      ;;
    *.xcdatamodel)
      echo "xcrun momc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH"`.mom\"" || true
      xcrun momc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodel`.mom"
      ;;
    *.xcdatamodeld)
      echo "xcrun momc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodeld`.momd\"" || true
      xcrun momc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodeld`.momd"
      ;;
    *.xcmappingmodel)
      echo "xcrun mapc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcmappingmodel`.cdm\"" || true
      xcrun mapc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcmappingmodel`.cdm"
      ;;
    *.xcassets)
      ABSOLUTE_XCASSET_FILE="$RESOURCE_PATH"
      XCASSET_FILES+=("$ABSOLUTE_XCASSET_FILE")
      ;;
    *)
      echo "$RESOURCE_PATH" || true
      echo "$RESOURCE_PATH" >> "$RESOURCES_TO_COPY"
      ;;
  esac
}
if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/Highlighter/highlight.min.js"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/a11y-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/a11y-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/agate.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/an-old-hope.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/androidstudio.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/arduino-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/arta.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/ascetic.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-cave-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-cave-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-dune-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-dune-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-estuary-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-estuary-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-forest-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-forest-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-heath-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-heath-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-lakeside-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-lakeside-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-plateau-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-plateau-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-savanna-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-savanna-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-seaside-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-seaside-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-sulphurpool-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-sulphurpool-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atom-one-dark-reasonable.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atom-one-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atom-one-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/brown-paper.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/codepen-embed.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/color-brewer.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/darcula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/darkula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/default.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/docco.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/dracula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/far.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/foundation.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/github-gist.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/github.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/gml.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/googlecode.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/grayscale.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/gruvbox-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/gruvbox-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/hopscotch.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/hybrid.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/idea.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/ir-black.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/isbl-editor-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/isbl-editor-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/kimbie.dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/kimbie.light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/lightfair.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/magula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/mono-blue.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/monokai-sublime.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/monokai.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/nord.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/obsidian.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/ocean.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/paraiso-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/paraiso-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/pojoaque.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/purebasic.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/qtcreator_dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/qtcreator_light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/railscasts.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/rainbow.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/routeros.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/school-book.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/shades-of-purple.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/solarized-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/solarized-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/sunburst.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night-blue.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night-bright.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night-eighties.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/vs.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/vs2015.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/xcode.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/xt256.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/zenburn.min.css"
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/Highlighter/highlight.min.js"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/a11y-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/a11y-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/agate.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/an-old-hope.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/androidstudio.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/arduino-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/arta.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/ascetic.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-cave-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-cave-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-dune-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-dune-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-estuary-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-estuary-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-forest-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-forest-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-heath-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-heath-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-lakeside-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-lakeside-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-plateau-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-plateau-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-savanna-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-savanna-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-seaside-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-seaside-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-sulphurpool-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atelier-sulphurpool-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atom-one-dark-reasonable.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atom-one-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/atom-one-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/brown-paper.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/codepen-embed.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/color-brewer.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/darcula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/darkula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/default.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/docco.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/dracula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/far.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/foundation.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/github-gist.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/github.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/gml.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/googlecode.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/grayscale.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/gruvbox-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/gruvbox-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/hopscotch.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/hybrid.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/idea.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/ir-black.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/isbl-editor-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/isbl-editor-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/kimbie.dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/kimbie.light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/lightfair.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/magula.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/mono-blue.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/monokai-sublime.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/monokai.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/nord.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/obsidian.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/ocean.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/paraiso-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/paraiso-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/pojoaque.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/purebasic.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/qtcreator_dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/qtcreator_light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/railscasts.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/rainbow.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/routeros.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/school-book.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/shades-of-purple.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/solarized-dark.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/solarized-light.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/sunburst.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night-blue.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night-bright.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night-eighties.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow-night.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/tomorrow.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/vs.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/vs2015.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/xcode.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/xt256.min.css"
  install_resource "${PODS_ROOT}/Highlightr/Pod/Assets/styles/zenburn.min.css"
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
if [[ "${ACTION}" == "install" ]] && [[ "${SKIP_INSTALL}" == "NO" ]]; then
  mkdir -p "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
fi
rm -f "$RESOURCES_TO_COPY"

if [[ -n "${WRAPPER_EXTENSION}" ]] && [ "`xcrun --find actool`" ] && [ -n "${XCASSET_FILES:-}" ]
then
  # Find all other xcassets (this unfortunately includes those of path pods and other targets).
  OTHER_XCASSETS=$(find -L "$PWD" -iname "*.xcassets" -type d)
  while read line; do
    if [[ $line != "${PODS_ROOT}*" ]]; then
      XCASSET_FILES+=("$line")
    fi
  done <<<"$OTHER_XCASSETS"

  if [ -z ${ASSETCATALOG_COMPILER_APPICON_NAME+x} ]; then
    printf "%s\0" "${XCASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  else
    printf "%s\0" "${XCASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" --app-icon "${ASSETCATALOG_COMPILER_APPICON_NAME}" --output-partial-info-plist "${TARGET_TEMP_DIR}/assetcatalog_generated_info_cocoapods.plist"
  fi
fi

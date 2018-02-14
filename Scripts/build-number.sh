#!/bin/sh

# Copyright 2017 Torsten Curdt.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BUILD_VERSION=$(head -1 "${SRCROOT:-.}/Version")
BUILD_REVISION=$(git rev-parse --short HEAD 2>/dev/null | tr -cd '[[:xdigit:]]')
BUILD_NUMBER=$(git rev-list --count --all --until "$(git show --format=%cd -s HEAD)")
BUILD_YEAR=`date +%Y`

echo "BUILD_NUMBER   $BUILD_NUMBER"
echo "BUILD_REVISION $BUILD_REVISION"
echo "BUILD_VERSION  $BUILD_VERSION"
echo "BUILD_YEAR     $BUILD_YEAR"

if [ "${TARGET_BUILD_DIR}" != "" ]; then

  for PLIST in "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}" "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}.dSYM/Contents/Info.plist"; do
    if [ -f "$PLIST" ]; then
      echo -n "OK"
      /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUILD_VERSION" "$PLIST"
      /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
      /usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString $BUILD_REVISION" "$PLIST"
    else
      echo -n "KO"
    fi
    echo " $PLIST"
  done

fi

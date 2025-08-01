#!/bin/bash -eu
# Copyright 2022 Google LLC
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
#
################################################################################

if [ -n "${OSS_FUZZ_CI-}" ]
then
        if [ "${SANITIZER}" = 'coverage' ]
        then
                exit 0
        fi

fi

cd $SRC/go-118-fuzz-build
go build .
mv go-118-fuzz-build /root/go/bin/

cd $SRC/moby

go clean -modcache

find . -type f \( -name "*.go" -o -name "go.mod" \) -exec sed -i \
  -e 's|github.com/docker/docker|github.com/moby/moby|g' \
  -e 's|github.com/moby/moby/v2|github.com/moby/moby|g' {} +

cp $SRC/jsonmessage_fuzzer.go $SRC/moby/client/pkg/jsonmessage/
cp $SRC/backend_build_fuzzer.go $SRC/moby/daemon/builder/backend/
cp $SRC/remotecontext_fuzzer.go $SRC/moby/daemon/builder/remotecontext/
cp $SRC/daemon_fuzzer.go $SRC/moby/daemon/

printf "package libnetwork\nimport _ \"github.com/AdamKorcz/go-118-fuzz-build/testing\"\n" > $SRC/moby/registerfuzzdependency.go

go mod edit -replace github.com/moby/moby=.
go mod edit -replace github.com/AdamKorcz/go-118-fuzz-build=$SRC/go-118-fuzz-build

rm -f $SRC/moby/daemon/logger/plugin_unsupported.go

rm -rf vendor
go mod tidy

if [ "$SANITIZER" != "coverage" ] ; then
        (cd ./daemon && go-fuzz -func FuzzDaemonSimple -o $SRC/moby/FuzzDaemonSimple.a .)
        $CXX $CXXFLAGS $LIB_FUZZING_ENGINE $SRC/moby/FuzzDaemonSimple.a \
        /src/LVM2.2.03.15/libdm/ioctl/libdevmapper.a \
        -o $OUT/FuzzDaemonSimple
fi

(cd ./client/pkg/jsonmessage && go-fuzz -func FuzzDisplayJSONMessagesStream -o $SRC/moby/FuzzDisplayJSONMessagesStream.a .)
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE $SRC/moby/FuzzDisplayJSONMessagesStream.a -o $OUT/FuzzDisplayJSONMessagesStream

(cd ./daemon/builder/backend && go-fuzz -func FuzzsanitizeRepoAndTags -o $SRC/moby/FuzzsanitizeRepoAndTags.a .)
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE $SRC/moby/FuzzsanitizeRepoAndTags.a -o $OUT/FuzzsanitizeRepoAndTags

(cd ./daemon/builder/remotecontext && go-fuzz -func FuzzreadAndParseDockerfile -o $SRC/moby/FuzzreadAndParseDockerfile.a .)
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE $SRC/moby/FuzzreadAndParseDockerfile.a -o $OUT/FuzzreadAndParseDockerfile

compile_native_go_fuzzer github.com/moby/moby/daemon/volume/mounts FuzzParseLinux FuzzParseLinux
compile_native_go_fuzzer github.com/moby/moby/pkg/tailfile FuzzTailfile FuzzTailfile
compile_native_go_fuzzer github.com/moby/moby/daemon/logger/jsonfilelog FuzzLoggerDecode FuzzLoggerDecode
compile_native_go_fuzzer github.com/moby/moby/daemon/libnetwork/etchosts FuzzAdd FuzzAdd
compile_native_go_fuzzer github.com/moby/moby/daemon/pkg/oci FuzzAppendDevicePermissionsFromCgroupRules FuzzAppendDevicePermissionsFromCgroupRules
compile_native_go_fuzzer github.com/moby/moby/daemon/logger/jsonfilelog/jsonlog FuzzJSONLogsMarshalJSONBuf FuzzJSONLogsMarshalJSONBuf

cp $SRC/*.options $OUT/

cd $SRC/go-archive
printf "package archive\nimport _ \"github.com/AdamKorcz/go-118-fuzz-build/testing\"\n" > $SRC/go-archive/registerfuzzdependency.go
go mod edit -replace github.com/AdamKorcz/go-118-fuzz-build=$SRC/go-118-fuzz-build
go mod tidy
compile_native_go_fuzzer github.com/moby/go-archive/compression FuzzDecompressStream FuzzDecompressStream
compile_native_go_fuzzer github.com/moby/go-archive FuzzApplyLayer FuzzApplyLayer
compile_native_go_fuzzer github.com/moby/go-archive FuzzUntar FuzzUntar

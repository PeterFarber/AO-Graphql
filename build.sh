#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LUA_GRAPHQL_DIR="${SCRIPT_DIR}/build/luagraphqlparser"
PROCESS_DIR="${SCRIPT_DIR}/aos/process"
LIBS_DIR="${PROCESS_DIR}/libs"

AO_IMAGE="p3rmaw3b/ao:0.1.2"

EMXX_CFLAGS="-s MEMORY64=1 -O3 -msimd128 -fno-rtti -DNDEBUG \
	-flto=full -s BUILD_AS_WORKER=1 -s EXPORT_ALL=1 \
	-s EXPORT_ES6=1 -s MODULARIZE=1 -s INITIAL_MEMORY=800MB \
	-s MAXIMUM_MEMORY=4GB -s ALLOW_MEMORY_GROWTH -s FORCE_FILESYSTEM=1 \
	-s EXPORTED_FUNCTIONS=_main -s EXPORTED_RUNTIME_METHODS=callMain -s \
	NO_EXIT_RUNTIME=1 -Wno-unused-command-line-argument -Wno-experimental /lua-5.3.4/src/liblua.a -I/lua-5.3.4/src"

# Clone luagraphqlparser if it doesn't exist
rm -rf ${LUA_GRAPHQL_DIR}
rm -rf libs
if [ ! -d "${LUA_GRAPHQL_DIR}" ]; then \
	git clone https://github.com/tarantool/luagraphqlparser.git ${LUA_GRAPHQL_DIR}; \
	cp ${SCRIPT_DIR}/inject/CMakeLists.txt ${LUA_GRAPHQL_DIR}/CMakeLists.txt; \
	cp ${SCRIPT_DIR}/inject/luagraphqlparser/lib.c ${LUA_GRAPHQL_DIR}/luagraphqlparser/lib.c; \
fi
cd ..
# Build luagraphqlparser into a static library with emscripten
docker run -v ${LUA_GRAPHQL_DIR}:/luagraphqlparser ${AO_IMAGE} sh -c \
		"cd /luagraphqlparser && mkdir build && cd build && emcmake cmake -DCMAKE_CXX_FLAGS='${EMXX_CFLAGS}' -S .. -B ."

docker run -v ${LUA_GRAPHQL_DIR}:/luagraphqlparser ${AO_IMAGE} sh -c \
		"cd /luagraphqlparser && cd build && cmake --build ." 

# Fix permissions
sudo chmod -R 777 ${LUA_GRAPHQL_DIR}


# # Copy luagraphqlparser to the libs directory
mkdir -p $LIBS_DIR/graphql
cp ${LUA_GRAPHQL_DIR}/build/luagraphqlparser/luagraphqlparser.a $LIBS_DIR/graphql/luagraphqlparser.a
cp ${LUA_GRAPHQL_DIR}/build/libgraphqlparser/libgraphqlparser.a $LIBS_DIR/graphql/libgraphqlparser.a


# Copy config.yml to the process directory
cp ${SCRIPT_DIR}/config.yml ${PROCESS_DIR}/config.yml

# Build the process module
cd ${PROCESS_DIR} 
docker run -e DEBUG=1 --platform linux/amd64 -v ./:/src ${AO_IMAGE} ao-build-module

# Copy the process module to the tests directory
cp ${PROCESS_DIR}/process.wasm ${SCRIPT_DIR}/tests/process.wasm
cp ${PROCESS_DIR}/process.js ${SCRIPT_DIR}/tests/process.js
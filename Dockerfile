ARG IMAGE=ubuntu:22.04
FROM --platform=linux/amd64 ${IMAGE} as builder
ENV WORKSPACE_DIR=/work
ENV INSTALL_DIR=${WORKSPACE_DIR}/install
ENV BUILD_DIR=${WORKSPACE_DIR}/build
ENV SRC_DIR=${WORKSPACE_DIR}/src

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY . /work/src/multiplier

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y wget clang curl gnupg software-properties-common lsb-release apt-utils graphviz xdot\
    && apt-get remove --purge --auto-remove cmake \
    && apt-get update \
    && apt-get clean all 

RUN apt-get install software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get install -y python3.12 python3.12-dev python3.12-venv

RUN curl -sl https://apt.llvm.org/llvm.sh --output llvm.sh \
    && bash llvm.sh 18 \
    $$ apt-get update \
    && apt-get install -y clang-18 clang-tools-18 lld-18

RUN wget https://github.com/Kitware/CMake/releases/download/v3.30.6/cmake-3.30.6-linux-x86_64.sh -q -O /tmp/cmake-install.sh \
    && chmod u+x /tmp/cmake-install.sh \
    && mkdir /opt/cmake-3.30.6 \
    && /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake-3.30.6 \
    && ln -s /opt/cmake-3.30.6/bin/* /usr/local/bin

RUN apt-get update \
    && apt-get install --no-install-recommends -y gpg zip unzip tar git pkg-config ninja-build ccache build-essential doctest-dev

WORKDIR /work
RUN mkdir -p "${BUILD_DIR}"
RUN mkdir -p "${SRC_DIR}"
RUN mkdir -p "${INSTALL_DIR}"

# Environment

RUN ln -sf "$(which ld.lld-18)" /usr/local/bin/ld.lld

RUN cmake \
    -S "${SRC_DIR}/multiplier" \
    -B "${BUILD_DIR}/multiplier" \
    -G Ninja \
    -DCMAKE_LINKER_TYPE=LLD \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$(which clang-18)" \
    -DCMAKE_CXX_COMPILER="$(which clang++-18)" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" 

RUN cmake --build "${BUILD_DIR}/multiplier" --target install
RUN chmod +x ${WORKSPACE_DIR}/install/bin/*

FROM --platform=linux/amd64 ${IMAGE} as release
RUN apt-get update && \
    apt-get install -yq --no-install-recommends libatomic1
COPY --from=builder ${INSTALL_DIR} ${INSTALL_DIR}
ENV PATH="${INSTALL_DIR}/bin:${PATH}"
WORKDIR /work

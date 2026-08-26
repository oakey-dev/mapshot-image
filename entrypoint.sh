#!/bin/bash
set -euo pipefail

############################################
# Adjustable defaults (env can override)
############################################
: "${MAPSHOT_ROOT_DIRECTORY:=/mapshot}"
: "${MAPSHOT_FACTORIO_DATADIR:=${MAPSHOT_ROOT_DIRECTORY}/factorio}"
: "${MAPSHOT_FACTORIO_BINARY:=${MAPSHOT_FACTORIO_DATADIR}/bin/x64/factorio}"
: "${MAPSHOT_WORK_DIR:=${MAPSHOT_FACTORIO_DATADIR}}"
: "${MAPSHOT_MODE:=render}"
: "${MAPSHOT_BINARY:=/usr/local/bin/mapshot}"

: "${MAPSHOT_AREA:=all}"
: "${MAPSHOT_JPG_QUALITY:=95}"
: "${MAPSHOT_LOG_LEVEL:=9}"
: "${MAPSHOT_MIN_JPG_QUALITY:=95}"
: "${MAPSHOT_NAME:=auto}"
: "${MAPSHOT_SAVE_MODE:=}"
: "${MAPSHOT_SURFACE:=_all_}"
: "${MAPSHOT_TILE_MAX:=0}"
: "${MAPSHOT_TILE_MIN:=64}"

: "${FACTORIO_VERSION:=stable}"
: "${FACTORIO_SAVE:=http://mapshot-saves:8080/_autosave1.zip}"
: "${CHECKSUM_FILE:=${MAPSHOT_ROOT_DIRECTORY}/last.sha256}"

if [[ -z "${FACTORIO_SAVE}" ]]; then
    : "${MAPSHOT_SAVE_MODE:=latest}"
fi

factorio_version_is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

factorio_version_gt() {
    [[ "$1" != "$2" ]] &&
        [[ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1 || true)" == "$1" ]]
}

get_factorio_version_from_location() {
    local url

    FACTORIO_USERNAME="${FACTORIO_USERNAME:?"ERROR missing username for download of factorio"}"
    FACTORIO_TOKEN="${FACTORIO_TOKEN:?"ERROR missing token for download of factorio"}"
    url="https://www.factorio.com/get-download/${FACTORIO_VERSION}/expansion/linux64?username=${FACTORIO_USERNAME}&token=${FACTORIO_TOKEN}"

    curl -fsSI "${url}" |
        sed -En 's/^[Ll]ocation:.*\/releases\/([0-9]+\.[0-9]+\.[0-9]+)_.*/\1/p' |
        head -n1 |
	tr -d '\r'
}

download_factorio() {
    local archive="${MAPSHOT_ROOT_DIRECTORY}/factorio-linux64.tar.xz"
    local extract_dir
    local install_dir="${MAPSHOT_ROOT_DIRECTORY}/factorio"
    local url

    extract_dir="$(mktemp -d)"

    FACTORIO_USERNAME="${FACTORIO_USERNAME:?"ERROR missing username for download of factorio"}"
    FACTORIO_TOKEN="${FACTORIO_TOKEN:?"ERROR missing token for download of factorio"}"
    url="https://www.factorio.com/get-download/${FACTORIO_VERSION}/expansion/linux64?username=${FACTORIO_USERNAME}&token=${FACTORIO_TOKEN}"

    echo "Downloading Factorio ${FACTORIO_VERSION}..."

    if ! curl -fsSL "${url}" -o "${archive}"; then
        echo "Failed to download Factorio; please check your credentials" >&2
        rm -rf "${archive}" "${extract_dir}"
        return 1
    fi

    if ! tar -xJf "${archive}" -C "${extract_dir}"; then
        echo "Failed to extract Factorio archive" >&2
        rm -rf "${archive}" "${extract_dir}"
        return 1
    fi

    if [[ ! -x "${extract_dir}/factorio/bin/x64/factorio" ]]; then
        echo "Downloaded archive does not contain a valid Factorio binary" >&2
        rm -rf "${archive}" "${extract_dir}"
        return 1
    fi

    mkdir -p "${install_dir}"

    # Preserve existing files, including script-output.
    cp -a "${extract_dir}/factorio/." "${install_dir}/"

    [[ -d "${MAPSHOT_FACTORIO_DATADIR}/mods" ]] || mkdir "${MAPSHOT_FACTORIO_DATADIR}/mods"
    echo "{}" >"${MAPSHOT_FACTORIO_DATADIR}/mods/mod-list.json"

    rm -rf "${archive}" "${extract_dir}"
}

if [[ ! -f "${MAPSHOT_FACTORIO_BINARY}" ]]; then
    echo "Factorio binary missing, downloading..."
    download_factorio
else
    installed_version="$(
        "${MAPSHOT_FACTORIO_BINARY}" --version |
            sed -nE 's/^Version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' |
            head -n1
    )"
    if [[ -z "${installed_version}" ]]; then
        echo "ERROR: Could not determine the installed Factorio version; skipping update"
        exit 1
    fi

    # shellcheck disable=SC2310
    if ! factorio_version_is_semver "${FACTORIO_VERSION}"; then
        echo "Resolving Factorio version alias: ${FACTORIO_VERSION}..."

        requested_version="$(
            get_factorio_version_from_location
        )"

        if [[ -z "${requested_version}" ]]; then
            echo "WARNING: Could not resolve ${FACTORIO_VERSION} to a semver version; skipping update"
            FACTORIO_VERSION=""
        else
            FACTORIO_VERSION="${requested_version}"
        fi
    fi

    if [[ -n "${FACTORIO_VERSION}" ]]; then
        # shellcheck disable=SC2310
        if factorio_version_gt "${FACTORIO_VERSION}" "${installed_version}"; then
            echo "Updating Factorio ${installed_version} -> ${FACTORIO_VERSION}..."
            download_factorio
        else
            echo "Factorio ${installed_version} is already up to date"
        fi
    fi
fi


if [[ "${MAPSHOT_MODE}" == "render" ]]; then
    term_handler() {
        killall Xvfb
    }
    trap 'term_handler' TERM INT

    if [[ "${MAPSHOT_SAVE_MODE:-}" != "latest" ]]; then
        if [[ -z "${FACTORIO_SAVE}" ]]; then
            echo "FACTORIO_SAVE is empty but MAPSHOT_SAVE_MODE is not latest"
            exit 1
        fi
        if [[ "${FACTORIO_SAVE:0:4}" == "http" ]]; then
            curl -fsSL "${FACTORIO_SAVE}" -o "${MAPSHOT_ROOT_DIRECTORY}/${MAPSHOT_NAME}.zip"
            FACTORIO_SAVE="${MAPSHOT_ROOT_DIRECTORY}/${MAPSHOT_NAME}.zip"
        fi
    else
        echo "Getting latest save"
        if [[ "${FACTORIO_SAVE:0:4}" == "http" ]]; then
            if [[ "${FACTORIO_SAVE: -4}" == ".zip" ]]; then
                FACTORIO_SAVE="$(dirname "${FACTORIO_SAVE}")"
            fi
            newest="$(curl -fsSL "${FACTORIO_SAVE}" | http-newest.awk | sort -rn)"
            echo -e "Found savefiles:\n${newest}"
            FACTORIO_SAVE_URL="${FACTORIO_SAVE}/$(awk '{print $2; exit}' <<<"${newest}")"

            echo "Fetching ${FACTORIO_SAVE_URL} as ${MAPSHOT_NAME}"
            curl -fsSL "${FACTORIO_SAVE_URL}" -o "${MAPSHOT_ROOT_DIRECTORY}/${MAPSHOT_NAME}.zip"
            FACTORIO_SAVE="${MAPSHOT_ROOT_DIRECTORY}/${MAPSHOT_NAME}.zip"
        else
            FACTORIO_SAVE="$(
                find /opt/factorio/saves/ -type f -exec ls -t {} \; 2>/dev/null | head -n 1
            )"
            if [[ -z "${FACTORIO_SAVE}" || ! -f "${FACTORIO_SAVE}" ]]; then
                echo "No save found under /opt/factorio/saves/; sleeping and retrying..."
                exit 1
            else
                echo "Using ${FACTORIO_SAVE} as ${MAPSHOT_NAME}"
                cp "${FACTORIO_SAVE}" "${MAPSHOT_ROOT_DIRECTORY}/${MAPSHOT_NAME}.zip"
                FACTORIO_SAVE="${MAPSHOT_ROOT_DIRECTORY}/${MAPSHOT_NAME}.zip"
            fi
        fi
    fi

    touch /tmp/healthz

    if [[ ! -f "${FACTORIO_SAVE}" ]]; then
        echo "The file FACTORIO_SAVE '${FACTORIO_SAVE}' could not be found, please check the path"
        exit 1
    elif [[ ! -s "${FACTORIO_SAVE}" ]]; then
        echo "The file FACTORIO_SAVE '${FACTORIO_SAVE}' is empty, please check the savegames"
        exit 1
    fi

    last="$(cat "${CHECKSUM_FILE}" || true)"
    checksum="$(sha256sum "${FACTORIO_SAVE}" | cut -d" " -f1)"

    if [[ "${checksum}" == "${last}" ]]; then
        echo "savegame did not change, nothing to do"
    else
        xvfb-run "${MAPSHOT_BINARY}" render --logtostderr \
            --factorio_binary "${MAPSHOT_FACTORIO_BINARY}" \
            --factorio_datadir "${MAPSHOT_FACTORIO_DATADIR}" \
            --area "${MAPSHOT_AREA}" \
            --jpgquality "${MAPSHOT_JPG_QUALITY}" \
            --minjpgquality "${MAPSHOT_MIN_JPG_QUALITY}" \
            --surface "${MAPSHOT_SURFACE}" \
            --tilemax "${MAPSHOT_TILE_MAX}" \
            --tilemin "${MAPSHOT_TILE_MIN}" \
            --work_dir "${MAPSHOT_WORK_DIR}" \
            --factorio_verbose \
            -v "${MAPSHOT_LOG_LEVEL}" \
            "${FACTORIO_SAVE}"
        echo -n "${checksum}" > "${CHECKSUM_FILE}"
    fi
    echo "... done"

elif [[ "${MAPSHOT_MODE}" == "serve" ]]; then
    exec "${MAPSHOT_BINARY}" serve \
        --factorio_binary "${MAPSHOT_FACTORIO_BINARY}" \
        --factorio_datadir "${MAPSHOT_FACTORIO_DATADIR}" \
        --work_dir "${MAPSHOT_WORK_DIR}"
elif [[ "${MAPSHOT_MODE}" == "update-factorio" ]]; then
    echo "... done"
else
    echo 'ERROR: MAPSHOT_MODE only supports "render", "update-factorio" or "serve"'
    exit 1
fi

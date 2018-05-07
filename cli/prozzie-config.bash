#!/usr/bin/env bash

# Prozzie - Wizzie Data Platform (WDP) main entrypoint
# Copyright (C) 2018 Wizzie S.L.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Includes
. "${BASH_SOURCE%/*}/include/common.bash"
. "${BASH_SOURCE%/*}/include/config.bash"
. "${BASH_SOURCE%/*}/include/cli.bash"

# Declare prozzie cli config directory path
declare -r PROZZIE_CLI_CONFIG="${BASH_SOURCE%/*}/config"
# .env file path
declare src_env_file="${PREFIX:-${DEFAULT_PREFIX}}/etc/prozzie/.env"

printShortHelp() {
    printf "Handle prozzie configuration\n"
}

printHelp() {
    printShortHelp
    printf "\tusage: prozzie config [<options>] [<module>] [<key>] [<value>]\n"
    printf "\t\tOptions:\n"
    printf "\t\t%-40s%s\n" "-w, --wizard" "Start modules wizard"
    printf "\t\t%-40s%s\n" "-d, --describe <module>" "Describe module vars"
    printf "\t\t%-40s%s\n" "-s, --setup <module>" "Configure module with setup assistant"
    printf "\t\t%-40s%s\n" "--describe-all" "Describe all modules vars"
    printf "\t\t%-40s%s\n" "-h, --help" "Show this help"

    exit 0
}

describeModule () {
    if [[ -f "$PROZZIE_CLI_CONFIG/$1.bash" ]]; then
        . "$PROZZIE_CLI_CONFIG/$1.bash"
        showVarsDescription
        exit 0
    fi
    exit 1
}

# Show help if option is not present
if [[ $# -eq 0 ]]; then
    printHelp
fi

if [[ $1 ]]; then
    case $1 in
        --shorthelp)
            printShortHelp
        ;;
        -h|--help)
            printHelp
        ;;
        -w|--wizard)
            wizard "$src_env_file"
            exit 0
        ;;
        -d|--describe)
            if [[ $2 ]]; then
                printf "Module ${2}: \n"
                describeModule "$2"
                printf "Module '%s' not found!\n" "$2"
                exit 1
            else
                printHelp
            fi
        ;;
        --describe-all)
            for config_module in "$PROZZIE_CLI_CONFIG"/*.bash; do
                . "$config_module"
                printf "Module ${config_module:36:-5}: \n"
                showVarsDescription
            done
            exit 0
        ;;
      -s|--setup)
            if [[ -f $PROZZIE_CLI_CONFIG/$2.bash ]]; then
                module=$PROZZIE_CLI_CONFIG/$2.bash
                . "$module"
                if [[ $2 == mqtt || $2 == syslog ]]; then
                    . "${BASH_SOURCE%/*}/include/kcli_base.bash"
                    tmp_fd properties
                    kcli_setup "/dev/fd/${properties}" "$2"
                    exec {properties}<&-
                else
                    printf "Setup %s configuration:\n" "$2"
                    app_setup "$@"
                fi
                exit 0
            fi
            printHelp
        ;;
        *)
            declare -r option="$PROZZIE_CLI_CONFIG/$1.bash"

            if [[ ! -f "$option" ]]; then
                printHelp
            fi

            . "$option"
            module=$1
            shift 1
            case $# in
                0)
                    if [[ "$module" =~ ^(mqtt|syslog)$ ]]; then
                        prozzie kcli get "$module"
                        exit 0
                    fi
                    zz_get_vars "$src_env_file"
                    exit 0
                ;;
                1)
                    if [[ "$module" =~ ^(mqtt|syslog)$ ]]; then
                        prozzie kcli get "$module"|grep "$1"|sed 's/'"${1}"'=//'
                        exit 0
                    fi
                    zz_get_var "$src_env_file" "$@"
                    exit 0
                ;;
                2)
                    if [[ "$module" =~ ^(mqtt|syslog)$ ]]; then
                        printf "Please use next commands in order to configure ${module}:\n"
                        printf "prozzie kcli rm <connector>\n"
                        printf "prozzie config -s ${module}\n"
                        exit 0
                    fi
                    zz_set_var "$src_env_file" "$@"
                    exit 0
                ;;
            esac
        ;;
    esac
fi

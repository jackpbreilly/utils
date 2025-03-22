#!/usr/bin/env bash
set -e

# GLOBALS
PYTHON_VERSION="python3"
PIP_VERSION="pip"
VENV_ACTIVATE="/bin/activate"

function does_venv_exist(){
    # Checks if either a passed in path is a venv or if VENV_PATH is a venv based on if VENV_ACTIVATE exists
    if [ "$1" ]; then
        local venv_path_to_check=$1
    else
        local venv_path_to_check=$VENV_PATH
    fi

    if [ -f $venv_path_to_check$VENV_ACTIVATE ]; then
        echo "does_venv_exist: $venv_path_to_check exists as a venv"
        return 0
    fi
    echo "does_venv_exist: $venv_path_to_check does not exist as a venv"
    return 1
}

function does_requirements_dot_txt_exist(){
    # Checks if requirements.txt exists
    if [ "$1" ]; then
        local requirements_dot_txt_path_to_check=$1
    else
        echo "does_requirements_dot_txt_exist: No valid parameter passed in"
        return 1
    fi

    if [ -f $requirements_dot_txt_path_to_check ]; then
        echo "does_requirements_dot_txt_exist: $requirements_dot_txt_path_to_check exists as a requirements.txt"
        return 0
    fi
    echo "does_requirements_dot_txt_exist: $requirements_dot_txt_path_to_check does not exist a requirements.txt"
    return 1
}

function does_bash_script_exist(){
    # Checks if bash scrit exists
    if [ "$1" ]; then
        local bash_script_to_check=$1
    else
        echo "does_bash_script_exist: No valid parameter passed in"
        return 1
    fi

    if [ -x $bash_script_to_check ]; then
        echo "does_bash_script_exist: $bash_script_to_check exists as a bash script"
        return 0
    fi
    echo "does_bash_script_exist: $bash_script_to_check does not exist as a bash script or is not execuable"
    return 1
}

function create_venv(){
    # Creates a venv from a passed in path or if not passed in will create one using mktemp
    if [ "$1" ]; then
        local venv_path_to_create=$VENV_PATH
    else
        local venv_path_to_check=$(mktemp --directory)
    fi
    echo "create_venv: Creating a venv at - $venv_path_to_check"

    $PYTHON_VERSION -m venv $venv_path_to_check
    VENV_PATH=$venv_path_to_check
}

function activate_venv(){
    # Activates a venv from passed in path or if not passed in will use VENV_PATH and VENV_ACTIVATE
    if [ "$1" ]; then
        local venv_path_to_activate=$1
    else
        local venv_path_to_activate=$VENV_PATH
    fi
    echo "activate_venv: Activating venv - $venv_path_to_check"

    source $venv_path_to_activate$VENV_ACTIVATE
}

function deactivate_venv(){
    # Deactivate a venv
    deactivate
}

function pip_install(){
    # Installs either a requirements.txt file or a single package
    if [ "$1" ]; then
        local to_install=$1
    else
        echo "pip_install: Nothing to install"
        return 1
    fi
    local install_args=''
    if does_requirements_dot_txt_exist $to_install; then
        install_args='-r'
    fi

    activate_venv $VENV_PATH
    $PIP_VERSION install $install_args $to_install
    deactivate_venv
}

function run_cli_test(){
    # Run a CLI test from a bash script
    if [ "$1" ]; then
        local cli_test_path=$1
    else
        echo "run_cli_test: Nothing to run"
        return 1
    fi
    activate_venv $VENV_PATH
    
    if does_bash_script_exist $cli_test_path; then
        $cli_test_path
    fi
    deactivate_venv
}

function clean_up(){
    if does_venv_exist $VENV_PATH; then
        rm -rf $VENV_PATH
    fi
}

function usage() {
    trap - EXIT   # Disable the EXIT trap so clean_up doesn't run
    echo "Usage: $(basename "$0") [options]"
    echo "Options:"
    echo "  -c, --create              Create a virtual environment"
    echo "  -i, --install FILE        Install dependencies from requirements FILE"
    echo "  -t, --test FILE           Run CLI test from bash script FILE"
    echo "  -p, --venv PATH           Specify virtual environment path (optional)"
    echo "  -h, --help                Display this help message"
    exit 1
}

trap clean_up EXIT

OPTS=$(getopt -o ci:t:p:h --long create,install:,test:,venv:,help -n 'venv-test-runner' -- "$@")

if [ $? != 0 ]; then
    usage
fi

eval set -- "$OPTS"
ACTION_CREATE=false
ACTION_INSTALL=false
ACTION_TEST=false

while true; do
    case "$1" in
        -c|--create)
            ACTION_CREATE=true
            shift ;;
        -i|--install)
            REQUIREMENTS_PATH="$2"
            ACTION_INSTALL=true
            shift 2 ;;
        -t|--test)
            CLI_TEST_PATH="$2"
            ACTION_TEST=true
            shift 2 ;;
        -p|--venv)
            VENV_PATH="$2"
            shift 2 ;;
        -h|--help)
            usage ;;
        --)
            shift
            break ;;
        *)
            usage ;;
    esac
done


if [ "$ACTION_CREATE" = true ] || [ "$ACTION_INSTALL" = true ] || [ "$ACTION_TEST" = true ]; then
    create_venv
fi

if [ "$ACTION_INSTALL" = true ]; then
    pip_install $(realpath $REQUIREMENTS_PATH)
fi

if [ "$ACTION_TEST" = true ]; then
    run_cli_test $(realpath $CLI_TEST_PATH)
fi
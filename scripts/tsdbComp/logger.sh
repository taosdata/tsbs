log_info() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ "$NO_COLOR" = "true" ]; then
        echo "[INFO] [$timestamp] $1"
    else
        echo -e "\e[32m[INFO]\e[0m [$timestamp] $1"
    fi
}

log_warning() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ "$NO_COLOR" = "true" ]; then
        echo "[WARNING] [$timestamp] $1" >&2
    else
        echo -e "\e[33m[WARNING]\e[0m [$timestamp] $1" >&2
    fi
}

log_error() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ "$NO_COLOR" = "true" ]; then
        echo "[ERROR] [$timestamp] $1" >&2
    else
        echo -e "\e[31m[ERROR]\e[0m [$timestamp] $1" >&2
    fi
}

log_debug() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ "$DEBUG" = "true" ]; then
        if [ "$NO_COLOR" = "true" ]; then
            echo "[DEBUG] [$timestamp] $1"
        else
            echo -e "\e[34m[DEBUG]\e[0m [$timestamp] $1"
        fi
    fi
}
#!/bin/bash

# Check if command exists and install it if not
function cmdInstall {
    local comd=$1
    if command -v ${comd} &> /dev/null; then
        log_info "${comd} is already installed"
    else
        if command -v apt &> /dev/null; then
            log_info "Installing ${comd} using apt"
            if apt-get install ${comd} -y 2>> ${error_install_file}; then
                log_info "${comd} installed successfully"
            else
                log_error "Failed to install ${comd} using apt"
            fi
        elif command -v yum &> /dev/null; then
            log_info "Installing ${comd} using yum"
            if yum install ${comd} -y 2>> ${error_install_file}; then
                log_info "${comd} installed successfully"
            else
                log_error "Failed to install ${comd} using yum"
            fi
        else
            log_warning "You should install ${comd} manually"
        fi
    fi
}

# Check if pip3 package exists and install it if not
# Check if pip3 packages exist and install them if not
function pip3_define_install {
    for comd in "$@"; do
        if pip3 show ${comd} &> /dev/null; then
            log_info "${comd} is already installed"
        else
            log_info "Installing ${comd} using pip3"
            if pip3 install ${comd} 2>> ${error_install_file}; then
                log_info "${comd} installed successfully"
            else
                log_error "Failed to install ${comd} using pip3"
            fi
        fi
    done
}

# Detect system type and version
function checkout_system {
    log_info "Detecting server version and hardware configuration..."

    # Detect system type
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION_ID=$VERSION_ID
        log_debug "Detected OS: $OS, Version: $VERSION_ID"
    else
        log_error "Unable to detect system type."
        exit 1
    fi

    # List of supported versions
    supported_versions=("Ubuntu 18.04" "Ubuntu 20.04" "Ubuntu 22.04")

    # Check if the current version is supported
    is_supported=false
    for version in "${supported_versions[@]}"; do
        if [[ "$OS $VERSION_ID" == "$version" ]]; then
            is_supported=true
            break
        fi
    done

    if [ "$is_supported" = false ]; then
        log_error "Unsupported system version. Current version: $OS $VERSION_ID"
        log_info "Supported versions: ${supported_versions[*]}"
        exit 1
    fi

    log_info "Detected system version: $OS $VERSION_ID"

    # Detect number of CPU cores
    cpu_cores=$(nproc)
    log_info "Number of CPU cores: $cpu_cores"

    # Detect memory size
    memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    memory_kb=$memory
    memory_mb=$((memory_kb / 1024))
    memory_gb=$(echo "scale=0; (${memory_mb} / 1024) + (${memory_mb} % 1024 > 0)" | bc)

    log_info "Memory size: $memory_gb GB"

    # Minimum hardware requirements
    min_cpu_cores=4
    min_memory_gb=8

    # Check if the minimum hardware requirements are met
    if [ "${cpu_cores}" -lt "${min_cpu_cores}" ] || [ "${memory_gb}" -lt "${min_memory_gb}" ]; then
        log_error "Server hardware configuration does not meet the minimum requirements."
        log_info "Minimum requirements: ${min_cpu_cores} CPU cores and ${min_memory_gb} GB memory"
        exit 1
    fi

    log_info "Server hardware configuration meets the minimum requirements."
    log_info "Detection completed, everything is normal."
}

# 解析 INI 文件并导出变量的函数
function parse_ini() {
    local ini_file="$1"
    local current_section=""
    local multiline_key=""
    local multiline_value=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 去除行首和行尾的空白字符
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 忽略注释行
        if [[ $line =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # 检查是否为节（section）
        if [[ $line =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            multiline_key=""
            multiline_value=""
        # 检查是否为键值对
        elif [[ $line =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # 去除键和值的前后空白字符
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # 去除值中的引号
            value=$(echo "$value" | sed 's/^"//;s/"$//')

            # 组合节名和键名，以避免命名冲突。如果不为空，并且是LoadTest 和 QueryTest 两个节
            if [[ -n $current_section && ($current_section == "LoadTest" || $current_section == "QueryTest") ]]; then
                full_key="${current_section}_${key}"
            else
                full_key="$key"
            fi

            # 检查是否为多行值的开始
            if [[ $value =~ \\$ ]]; then
                multiline_key="$full_key"
                multiline_value="${value%\\}"
            else
                # 导出变量
                export "$full_key"="$value"
            fi
        # 处理多行值
        elif [[ -n $multiline_key ]]; then
            if [[ $line =~ \\$ ]]; then
                multiline_value="${multiline_value} ${line%\\}"
            else
                # 去除最后一行的右引号
                line=$(echo "$line" | sed 's/"$//')
                multiline_value="${multiline_value} $line"
                export "$multiline_key"="$multiline_value"
                multiline_key=""
                multiline_value=""
            fi
        fi
    done < "$ini_file"
}

# Function to double the TS_END time
function double_ts_end() {
    local ts_end=$1
    local new_ts_end=$(date -u -d "$ts_end + $(($(date -u -d "$ts_end" +%s) - $(date -u -d "2016-01-01T00:00:00Z" +%s))) seconds" +"%Y-%m-%dT%H:%M:%SZ")
    echo $new_ts_end
}

function ceil(){
  floor=`echo "scale=0;$1/1"|bc -l ` # 向下取整
  add=`awk -v num1=$floor -v num2=$1 'BEGIN{print(num1<num2)?"1":"0"}'`
  echo `expr $floor  + $add`
}

function floor(){
  floor=`echo "scale=0;$1/1"|bc -l ` # 向下取整
  echo `expr $floor`
}

function run_command() {
    local command="$1"
    if [ "$clientHost" == "${DATABASE_HOST}"  ]; then
        # 本地执行
        eval "$command"
    else
        # 远程执行
        sshpass -p ${SERVER_PASSWORD} ssh root@$DATABASE_HOST << eeooff
            $command
            exit
eeooff
    fi
}

function set_command() {
    local command=$1
    local result
    if [ "$clientHost" == "${DATABASE_HOST}"  ]; then
        # 本地执行
        result=$(eval "$command")
    else
        # 远程执行
         result=`sshpass -p ${SERVER_PASSWORD} ssh root@$DATABASE_HOST "$command"`
    fi
    echo "$result"
}

function install_uv() {
    # install uv
    log_info "Installing uv for manage python version and env ..."
    curl -LsSf https://astral.sh/uv/install.sh | sh 
    log_info "libuv installed successfully" 

    # Add uv to PATH
    export PATH=$HOME/.local/bin:$PATH
    echo -e  '\n# uv env\nexport PATH=$HOME/.local/bin:$PATH\n' >> ~/.bashrc
    log_info "uv env has been added to PATH"
}

function install_python() {
    local work_dir="$1"
    if uv --version &> /dev/null; then
        log_info "uv is already installed"
    else
        install_uv
    fi
    # install python
    log_info "Installing python3.8 ..."
    cd $work_dir
    uv python install  3.8
    uv venv --python 3.8 tsbsvenv
    source $work_dir/tsbsvenv/bin/activate 
    uv pip install pandas matplotlib
    log_info "Python3.8 installed successfully"
}

function execute_python_file (){
    local work_dir="$1"
    local file="$2"
    shift 2  # 移除前两个参数
    source $work_dir/tsbsvenv/bin/activate 
    python3 --version
    python3 $file "$@"
}
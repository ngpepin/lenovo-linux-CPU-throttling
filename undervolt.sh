#!/bin/bash
#
# Script: undervolt.sh 
# Github repository: lenovo-linux-CPU-throttling
# Nicolas Pepin, Dec 2023
#
# License:
# --------
# This script is freely shared under the MIT License, a permissive open source license.
# The MIT License permits reuse within proprietary software provided that the license is included.
# This means you can modify, distribute, and use this script freely, even for commercial purposes.
# Full terms of the MIT License can be found here: https://opensource.org/licenses/MIT
#
# Disclaimer:
# -----------
# This script is provided "as is" without any warranties, either expressed or implied, including but not limited to implied
# warranties of merchantability and fitness for a particular purpose. The user assumes all risks regarding the quality and
# performance of the script. The author, Nicolas Pepin, shall not be liable for any direct, indirect, incidental, special,
# exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use,
# data, or profits; or business interruption) however caused and on any theory of liability, whether in contract, strict liability,
# or tort (including negligence or otherwise) arising in any way out of the use of this script, even if advised of the possibility
# of such damage.
#
# Script Description:
# -------------------
# This script is designed to periodically check and apply undervolt settings on a system.
# It is intended to be used as part of a systemd service to ensure that specific undervolt
# settings are maintained consistently, especially after system events like suspending or hibernating.
# Additionally, the script keeps track of the time elapsed since the last time it was necessary to
# re-apply settings and trims the log file to avoid it becoming too large.
#
# How to Use:
# -----#-----
# Place this script in a suitable location (e.g., /usr/local/bin/) and make it executable
# with the command 'chmod +x script_name.sh'. The script is intended to be invoked by a systemd service.
#
# Configurable Parameters:
# ------#-----------------
# - MAX_TEMP: The desired maximum temperature for the CPU.
# - BAT_DELTA: The temperature delta for the battery.
# - SLEEP_TIME: The time interval in minutes between each settings check.
# - LOG_FILE: The path to the log file where script output will be logged.
# - MAX_LOG_LINES: The maximum number of lines to keep in the log file.  
#   (with SLEEP_TIME=1, approx 275 lines will be generated per hour * 72 hrs = cap at 20,000 lines)
#
# Script SLEEP_TIME and BIOS Behavior (also see technical discussion below):
#
# The default SLEEP_TIME is set to 1 minute, which may seem quite aggressive. However, this can be adjusted 
# based on testing and individual experience. In my experience with Ubuntu on a Lenovo P1 Gen 1, the BIOS 
# tends to reset the maximum temperature rather unpredictably. The longest observed interval between resets 
# is approximately 2 hours, with the shortest being just a few minutes, justifying the script's brief sleep interval.
# The impact of frequent wake-ups on system resources is negligible, especially when weighed against the benefits 
# of maintaining optimal CPU performance through effective temperature management.
#   
# Basic Algorithm:
# ----------------
# 1. The script enters an infinite loop.
# 2. It reads the current undervolt settings.
# 3. It checks if the current temperature target matches either MAX_TEMP or MAX_TEMP + BAT_DELTA.
# 4. If the settings do not match, the script re-applies the desired undervolt settings and logs this action.
# 5. After re-applying settings or confirming correct settings, the script logs the time elapsed since it last had to make adjustments.
# 6. The script trims the log file if it exceeds the specified maximum number of lines.
# 7. The script then sleeps for a specified duration (SLEEP_TIME minutes) before repeating the process.
#
# Log File Output Format and Interpretation:
# ------------------------------------------
# The script logs its actions in a specified log file with a consistent format for easy interpretation.
# Each log entry includes a timestamp followed by a message, formatted as "MMM DD HH:MM:SS Message".
# 
# Example Log Entries:
#
#   - "Dec 15 19:45:16    ====  Settings CORRECT (max temp = 98C)": Indicates settings are correct as of the timestamp.
#   - "Dec 15 19:46:16    !!!!  Settings INCORRECT (max temp = 80C)": Signals incorrect settings needing re-application.
#
# The log also tracks time elapsed without needing to re-apply settings and system sleep/wake actions.
# This structured logging aids in diagnosing issues and understanding the script's operational history.
#
# Technical Background:
# ---------------------
# This script addresses a specific behavior observed in certain Lenovo laptops, 
# including models like the Lenovo P1 Gen. 1, where the default BIOS configuration 
# sets the CPU thermal throttling to activate at around 80°C. This setting is lower 
# than the optimal performance threshold, especially considering Intel's specification 
# of a 100°C maximum junction temperature for CPUs like the 8750H.
#
# The lower throttling temperature can lead to underutilization of the CPU's capabilities,
# particularly under heavy workloads, resulting in reduced performance. In Linux systems,
# like those running Ubuntu, the MSR (Model-Specific Register) controlling the temperature
# target defaults to a value that results in this lower throttling temperature. Unlike in 
# Windows, where certain services or drivers might manage these settings, Linux does not 
# typically have an inherent mechanism to adjust this behavior.
#
# Therefore, users often need to manually monitor and adjust the MSR value to allow the CPU 
# to operate at higher temperatures, closer to Intel's specified maximum. This ensures better 
# utilization of the CPU, especially for performance-intensive tasks. However, these adjustments 
# are challenging as the system might reset these values periodically, necessitating frequent 
# monitoring and re-application of the desired settings.
#
# Community-developed scripts and tools automate the process of monitoring and adjusting these 
# settings for users who require consistent and optimal performance from their Lenovo laptops. 
# This script is part of such solutions, aimed at providing a more efficient and automated way 
# to manage CPU thermal throttling settings for improved performance in Linux environments.
#
# Dependencies:
# -------------
# This script depends on the 'undervolt' tool, a Linux utility for undervolting Intel CPUs.
# 'Undervolt' allows applying fixed voltage offsets and altering the temperature target and power limits.
# It is crucial for setting the max CPU temperature, as BIOS in some laptops (like certain Lenovo models)
# overrides the temperature settings, necessitating repeated 'undervolt' calls to maintain desired limits.
# For installation and more information, visit: https://github.com/georgewhewell/undervolt
# 
# Basic Installation of the undervolt tool:
# 
#   1. Install via Pip: `pip install undervolt`
#      - Or, install from source: `pip install git+https://github.com/georgewhewell/undervolt.git`
#   2. Ensure the 'msr' module is enabled in the kernel for 'undervolt' to function properly.
#
# Systemd Unit for this Script:
# -----------------------------
# This systemd unit is configured to manage the execution of the undervolt script, taking in consideration the requirements of
# the 'undervolt' tool.
#
# Unit Description:
#   - The unit is set to start after system suspend, hibernation, or hybrid sleep, ensuring the undervolt settings are applied post these events.
# Service Configuration:
#   - Type: 'simple', the default service type.
#   - ExecStart: Points to the script's location, here '/etc/systemd/system/undervolt.sh'.
#   - Restart: Configured to 'on-failure', meaning the service will restart if it fails.
#   - RestartSec: Sets a 10-second delay before the service restarts after failure.
# Install Targets:
#   - WantedBy: The script is enabled for 'multi-user.target', and after suspend, hibernate, and hybrid-sleep events.
#
# .service file contents:
# ---------------------------------------------------------------------------------
#   [Unit]
#   Description=Undervolt CPU Management Service
#   After=suspend.target hibernate.target hybrid-sleep.target
# 
#   [Service]
#   Type=simple
#   ExecStart=/etc/systemd/system/undervolt.sh
#   Restart=on-failure
#   RestartSec=10
# 
#   [Install]
#   WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target
# ------------------------------------------------------------------------------------
#

# Set the desired maximum temperature and battery delta
MAX_TEMP=98
BAT_DELTA=-5

# Set the sleep time in minutes
SLEEP_TIME=1

# Set the log file location and its maximum size
LOG_FILE="/var/log/undervolt.log"
MAX_LOG_LINES=20000  # this should hold 72 hours

# make sure script is running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "$(date '+%b %d %H:%M:%S') This script must be run as root" | tee -a $LOG_FILE
    exit 1
fi

# Function to convert date string to Unix timestamp
convert_to_timestamp() {
    date -d "$1" +%s
}

# Function to apply undervolt settings
apply_undervolt_settings() {
    /usr/local/bin/undervolt --temp $1 --temp-bat $(($1 + $BAT_DELTA)) --core -100 --cache -100 --gpu -25 --uncore -40
}

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%b %d %H:%M:%S') $1" | tee -a $LOG_FILE
}

# Function to trim the log file
trim_log_file() {
    # Check if the number of lines in the log file is greater than MAX_LOG_LINES
    if [ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_LINES ]; then
        # Trim the log file to the last MAX_LOG_LINES lines
        tail -n $MAX_LOG_LINES "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# Function to calculate and log the time since the last correct settings
log_time_since_last_correct_setting() {
    local current_time=$(date +%s)
    local found_incorrect=false
    local correct_time
    
    # Check if log file exists
    if [ ! -f "$LOG_FILE" ]; then
      log_message "          (Waiting for log file to be created to calculate time elapsed without needing to re-apply settings)"
    else

       # Reading the log file in reverse
       while IFS= read -r line; do
           if [[ $line == *"===="* ]] && [ "$found_incorrect" = true ]; then
               local correct_time_str=$(echo "$line" | awk '{print $1" "$2" "$3}')
               local correct_time=$(convert_to_timestamp "$correct_time_str")
               break
           elif [[ $line == *"!!!!"* ]]; then
               found_incorrect=true
           fi
       done < <(tac "$LOG_FILE")

       # Calculate and display the time difference
       if [ -n "$correct_time" ]; then
           local time_diff=$((current_time - correct_time))
           log_message "          Time elapsed without needing to re-apply (HH:MM:SS): $(date -u -d @${time_diff} +'%H:%M:%S')"
       else
           log_message "          (Insufficient data in log to calculate time elapsed without needing to re-apply settings)"
       fi
    fi
}


# Infinite loop to keep checking and applying settings
while true; do
    
    log_message "          Waking up..."
    # Read current settings
    current_settings=$(/usr/local/bin/undervolt -r)

    # Extract the current temperature setting
    current_temp=$(echo "$current_settings" | grep "temperature target" | grep -oP '(?<=\()\d+')

    bat_temp_target=$(($MAX_TEMP + $BAT_DELTA))
    
    # Check if current settings match desired settings
    if [ "$current_temp" -ne "$MAX_TEMP" ] && [ "$current_temp" -ne "$bat_temp_target" ]; then
        log_message "    !!!!  Settings INCORRECT (max temp = ${current_temp}C)"
	    log_message "          Should be ${MAX_TEMP}C (or ${bat_temp_target}C on batt)"
        log_message "    >>>>  Re-applying"
        apply_undervolt_settings $MAX_TEMP $BAT_DELTA
	
	# Wake up sooner in order to check if the settings have held
	SLEEP_TIME=0.25
    else
        log_message "    ====  Settings CORRECT (max temp = ${current_temp}C)" 
	log_message "          No action required"
        SLEEP_TIME=1
    fi
    
    # Log the time since the last correct setting
    log_time_since_last_correct_setting
      
    # keep the size of the log file in check
    trim_log_file
    
    # Say goodnight
    log_message "          Going to sleep for $SLEEP_TIME minute(s)..."
    
    # Sleep for SLEEP_TIME minutes (converted to seconds)
    sleep $(($SLEEP_TIME * 60))

done

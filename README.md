# lenovo-linux-CPU-throttling
(Lenovo Linux CPU Throttling Management under Ubuntu)

## Description
This script, `undervolt.sh`, created by Nicolas Pepin in December 2023, is designed to periodically check and apply undervolt settings on Lenovo laptops, specifically for systems running Ubuntu. It addresses the issue of CPU thermal throttling being activated at around 80°C due to BIOS configurations, which is lower than the optimal performance threshold.

## License
This script is shared under the MIT License. [Full License Details](https://opensource.org/licenses/MIT).

## Disclaimer

The author of this script, Nicolas Pepin, provides it "as is" and disclaims any and all warranties, express or implied, including but not limited to the implied warranties of merchantability and fitness for a particular purpose. The user assumes the entire risk as to the quality and performance of the script. In no event will the author be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) arising in any way out of the use of this script, even if advised of the possibility of such damage.

## Usage
- Place the script in a suitable location (e.g., `/usr/local/bin/`) and make it executable with `chmod +x undervolt.sh`.
- The script is intended to be invoked by a systemd service.

## Technical Goals & Outcomes
- Addresses sub-optimal thermal management behavior in Lenovo Thinkpad laptops (and probably others).
- Helps maintain optimal CPU performance by managing temperature settings more effectively than default BIOS configurations.
- Combats unpredictable and undesirable BIOS resets of maximum temperature settings.

## Configurable Parameters
- `MAX_TEMP`: Desired maximum temperature for the CPU.
- `BAT_DELTA`: Temperature delta for the battery.
- `SLEEP_TIME`: Time interval in minutes between each settings check.
- `LOG_FILE`: Path to the log file for script output.
- `MAX_LOG_LINES`: Maximum number of lines to keep in the log file.

Note: default `SLEEP_TIME` is 1 minute in the script but can be adjusted based on user experience and testing. 

Script tested on a Lenovo P1 Gen. 1 where the longest observed interval between resets was approximately 2 hours, with the shortest being just a few minutes (thereby justifying a brief sleep interval). Note that the impact of frequent wake-ups on system resources is negligible, especially when weighed against the benefits of maintaining optimal CPU performance through effective temperature management.

Undervolting settings are somewhat conservative but have resulted in high system stability on a Lenovo P1.  Don't use these settings verbatim, start low and ramp up, taking time to first read community recommendations and best-practices.  I don't take responsibility for what could happen if you proceed too aggressively.

## Systemd Service Setup

The script is designed to work with a systemd service, which ensures it's executed under specific system conditions:
- The script is set to start after system suspend, hibernation, or hybrid sleep.
- `.service` file is provided to manage the script execution via systemd.
- **Service Type:** The service type is set to 'simple', which is the default and most straightforward service type.
- **ExecStart:** Points to the script's location, typically `/etc/systemd/system/undervolt.sh`.
- **Restart Policies:**
  - `Restart=on-failure`: The service will restart if the script fails.
  - `RestartSec=10`: A 10-second delay is set before the service restarts after failure.
- **Activation Triggers:**
  - `After=suspend.target hibernate.target hybrid-sleep.target`: The service starts after system suspend, hibernation, or hybrid sleep.
- **Installation Targets:**
  - `WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target`: Specifies the targets for which the service is enabled.

This code block provides the actual content of the systemd `.service` file necessary for managing the script. Copy and paste it into your own `.service` file as needed.

```ini
[Unit]
Description=Undervolt CPU Management Service
After=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=simple
ExecStart=/etc/systemd/system/undervolt.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target
```

These settings ensure the script runs consistently and reliably, particularly after specific system states like suspending or hibernating.

## Dependencies
The script depends on the 'undervolt' tool for Linux. [Undervolt Tool](https://github.com/georgewhewell/undervolt)
- Install via Pip: `pip install undervolt`
- Or from source: `pip install git+https://github.com/georgewhewell/undervolt.git`

## Log File Format Description

The script generates log entries with a structured format, facilitating easy monitoring and analysis:

- **Timestamp:** Each entry begins with a timestamp in the format `MMM DD HH:MM:SS` (e.g., `Dec 15 19:45:16`), indicating the date and time of the logged event.
- **Log Message:** Following the timestamp, the log message describes the event or action taken by the script. Examples include:
  - `==== Settings CORRECT (max temp = 98C)`: Indicates that the settings are correct as of the timestamp.
  - `!!!! Settings INCORRECT (max temp = 80C)`: Signals that the settings are incorrect, and re-application may be necessary.

```log
Dec 15 19:45:16 ==== Settings CORRECT (max temp = 98C)
Dec 15 19:45:16      No action required
Dec 15 19:45:16      Time elapsed without needing to re-apply 
                     (HH:MM:SS): 01:01:26
Dec 15 19:45:16      Going to sleep for 1 minute(s)...
Dec 15 19:46:16      Waking up...
Dec 15 19:46:16 !!!! Settings INCORRECT (max temp = 80C)
Dec 15 19:46:16      Should be 98C (or 93C on batt)
Dec 15 19:46:16 >>>> Re-applying
Dec 15 19:46:16      Going to sleep for 0.25 minute(s)...
```
The log file thus provides a chronological record of the script's operations, temperature settings checks, and any adjustments made.



## Technical Summary
This script is a solution to the BIOS-enforced CPU throttling at lower temperatures in certain Lenovo laptops. The script periodically checks and adjusts the CPU temperature settings to prevent throttling at the default 80°C, allowing the CPU to perform optimally up to a higher temperature. Frequent resetting by the BIOS is countered by the script's aggressive checking interval, ensuring consistent performance.

This script addresses a specific behavior observed in certain Lenovo laptops (and probably some from other manufacturers), including models like the Lenovo P1 Gen. 1, where the default BIOS configuration sets the CPU thermal throttling to activate at around 80°C. This setting is lower than the optimal performance threshold, especially considering Intel's specification of a 100°C maximum junction temperature for CPUs like the 8750H.

The lower throttling temperature can lead to underutilization of the CPU's capabilities, particularly under heavy workloads, resulting in reduced performance. In Linux systems, like those running Ubuntu, the MSR (Model-Specific Register) controlling the temperature target defaults to a value that results in this lower throttling temperature. Unlike in Windows, where certain services or drivers might manage these settings, Linux does not typically have an inherent mechanism to adjust this behavior.

Therefore, users often need to manually monitor and adjust the MSR value to allow the CPU to operate at higher temperatures, closer to Intel's specified maximum. This ensures better utilization of the CPU, especially for performance-intensive tasks. However, these adjustments are challenging as the system might reset these values periodically, necessitating frequent monitoring and re-application of the desired settings.

Community-developed scripts and tools automate the process of monitoring and adjusting these settings for users who require consistent and optimal performance from their Lenovo laptops. This script is part of such solutions, aimed at providing a more efficient and automated way to manage CPU thermal throttling settings for improved performance in Linux environments.

For more details on the technical aspects and community discussions, please refer to the Lenovo forums and Linux user groups.

---
Note: This README is part of the `lenovo-linux-CPU-throttling` GitHub repository.*
*

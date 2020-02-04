# This service is related to: https://github.com/NixOS/nix/issues/3294
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix.expire-pids;
in

{
  options = {
    nix.expire-pids.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''Automatically expire pids to avoid ulimit saturation.
        See this issue for related information:
        * https://github.com/NixOS/nix/issues/3294
      '';
    };

    nix.expire-pids.interval = mkOption {
      type = types.listOf types.attrs;
      default = map (m: { Minute = m; }) [ 0 15 30 45 ];
      description = "The time interval at which the pid expiration service will run.";
    };

    nix.expire-pids.targetProcess = mkOption {
      type = types.str;
      default = "[n]ix-daemon";
      description = ''The default target process name to evaluate expiring.
        Note: square-bracket char 0 of the process name to exclude grep in the eval list
      '';
    };

    nix.expire-pids.ppidExclusion = mkOption {
      type = types.int;
      default = 1;
      description = "Exclude any matched processes with this parent pid.";
    };

    nix.expire-pids.threshold = mkOption {
      type = types.int;
      default = (8 * 3600) + 1;
      description = "The amount of time in seconds to use as a pid kill threshold.";
    };

    nix.expire-pids.numberOfProcesses = mkOption {
      type = types.int;
      default = 10000;
      description = ''The number of processes allowed by a user on a mac.
        This value sets kern.maxproc and kern.maxprocperuid.
      '';
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.nix-expire-pids = {
      script = ''
        # Process to filter for
        PROCESS="${cfg.targetProcess}"

        # Exclude from consideration any matched processes with a particular parent pid
        PPID_EXCLUSION="${toString cfg.ppidExclusion}"

        # Kill threshold, in seconds, for a pid; currently set to 1 second longer than the nix.conf build timeout
        THRESHOLD="${toString cfg.threshold}"

        currentTimestamp=$(date +%s)
        # shellcheck disable=SC2009
        processList=$(ps -ef -O lstart | grep "$PROCESS" | grep -vE "([ ]+[0-9]+){2}[ ]+''${PPID_EXCLUSION}[ ]+" | sed -e 's/^[ \t]*//' | tr -s ' ' | cut -f 2,10-14 -d ' ')

        [[ -z "$processList" ]] && echo "No candidate pids found.  Exiting." && exit 0

        killCount="0"
        while IFS= read -r processInfo
        do
          pid=$(cut -f 1 -d ' ' <<< "$processInfo")
          startTimestamp=$(date -jf "%c" "$(cut -f 2-5 -d ' ' <<< "$processInfo")" +%s)
          duration="$((currentTimestamp - startTimestamp))"
          if [ "$duration" -gt "$THRESHOLD" ]; then
            kill -KILL "$pid"
            killCount=$((killCount + 1))
          fi
        done < <(printf '%s\n' "$processList")
        echo "$killCount timed out $PROCESS pids running longer than $THRESHOLD seconds killed."
        exit 0
      '';
      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = cfg.interval;
        SoftResourceLimits.NumberOfProcesses = cfg.numberOfProcesses;
        HardResourceLimits.NumberOfProcesses = cfg.numberOfProcesses;
      };
    };
  };
}

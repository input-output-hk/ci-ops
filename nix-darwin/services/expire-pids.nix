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

    nix.expire-pids.maxProc = mkOption {
      type = types.int;
      default = 10000;
      description = ''The number of processes allowed by a user on a mac.
        This value sets kern.maxproc and kern.maxprocperuid.
        Note: MacOS has some unusual limits on processes count
        Refs:
          https://apple.stackexchange.com/questions/373063/why-is-macos-limited-to-1064-processes
          https://apple.stackexchange.com/questions/264958/what-does-serverperfmode-1-actually-do-on-macos/
      '';
    };

    nix.expire-pids.maxFiles = mkOption {
      type = types.int;
      default = 524288;
      description = ''The number of open files allowed by a user on a mac.
        This value sets kern.maxfiles and kern.maxfilesperuid.
      '';
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons = {
      nix-expire-pids = {
        script = ''
          # shellcheck disable=SC2009

          # Process to filter for
          PROCESS="${cfg.targetProcess}"

          # Exclude from consideration any matched processes with a particular parent pid
          PPID_EXCLUSION="${toString cfg.ppidExclusion}"

          # Kill threshold, in seconds, for a pid; currently set to 1 second longer than the nix.conf build timeout
          THRESHOLD="${toString cfg.threshold}"

          currentTimestamp=$(date +%s)
          processList=$(ps -ef -O lstart | grep "$PROCESS" | grep -vE "([ ]+[0-9]+){2}[ ]+''${PPID_EXCLUSION}[ ]+" | sed -e 's/^[ \t]*//' | tr -s ' ' | cut -f 2,10-14 -d ' ')
          runningCount=$(ps aux | grep -c ^)
          rssRam=$(ps -caxm -orss= | awk '{ sum += $1 } END { print sum/1024 }')

          [[ -z "$processList" ]] && echo "$(date): No candidate pids found.  A total of $runningCount processes running with $rssRam MiB RAM used.  Exiting." && exit 0

          killCount="0"
          pidCount="0"
          while IFS= read -r processInfo
          do
            pid=$(cut -f 1 -d ' ' <<< "$processInfo")
            startTimestamp=$(date -jf "%c" "$(cut -f 2-5 -d ' ' <<< "$processInfo")" +%s)
            duration="$((currentTimestamp - startTimestamp))"
            if [ "$duration" -gt "$THRESHOLD" ]; then
              kill -KILL "$pid"
              killCount=$((killCount + 1))
            fi
            pidCount=$((pidCount + 1))
          done < <(printf '%s\n' "$processList")
          echo "$(date): Killed $killCount timed out $PROCESS pids running of $pidCount pids evaluated and a total of $runningCount processes running with $rssRam MiB RAM used."
          exit 0
        '';
        serviceConfig = {
          RunAtLoad = false;
          StartCalendarInterval = cfg.interval;
          StandardErrorPath = "/var/log/expire-pids.log";
          StandardOutPath = "/var/log/expire-pids.log";
        };
      };

      limit-maxproc = {
        command = "/bin/launchctl limit maxproc ${toString cfg.maxProc} ${toString cfg.maxProc}";
        serviceConfig.RunAtLoad = true;
      };

      limit-maxfiles = {
        command = "/bin/launchctl limit maxfiles ${toString cfg.maxFiles} ${toString cfg.maxFiles}";
        serviceConfig.RunAtLoad = true;
      };
    };
  };
}

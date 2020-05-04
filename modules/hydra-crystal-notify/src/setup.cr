LOG_LEVEL = ENV.fetch("LOG_LEVEL", "INFO")
LOG_FILE  = ENV.fetch("LOG_FILE", "/var/lib/hydra/notification-debug.log")
CFG_FILE  = ENV.fetch("CFG_FILE", "/var/lib/hydra/github-notify.conf")

LOG_LEVELS = {"FATAL"   => Logger::FATAL,
              "ERROR"   => Logger::ERROR,
              "WARN"    => Logger::WARN,
              "INFO"    => Logger::INFO,
              "DEBUG"   => Logger::DEBUG,
              "UNKNOWN" => Logger::UNKNOWN}

LISTEN_CHANNELS = {"step_started" => '\t',
                   "step_started" => '\t',
                   "step_finished" => '\t',
                   "build_started" => '\t',
                   "build_finished" => '\t',
                   "eval_started" => '\t',
                   "eval_failed" => '\t',
                   "eval_cached" => '\t',
                   "eval_added" => '\t'}

alias QUERY_BUILD_TYPE = {id: Int32,
                          finished: Int32,
                          timestamp: Int32,
                          project: String,
                          jobset: String,
                          job: String,
                          nixname: String,
                          drvpath: String,
                          system: String,
                          iscurrent: Int32 | Nil,
                          starttime: Int32 | Nil,
                          stoptime: Int32 | Nil,
                          iscachedbuild: Int32 | Nil,
                          buildstatus: Int32 | Nil,
                          size: Int64 | Nil,
                          closuresize: Int64 | Nil,
                          keep: Int32,
                          notificationpendingsince: Int32 | Nil}

QUERY_BUILD = {id: Int32,
               finished: Int32,
               timestamp: Int32,
               project: String,
               jobset: String,
               job: String,
               nixname: String,
               drvpath: String,
               system: String,
               iscurrent: Int32 | Nil,
               starttime: Int32 | Nil,
               stoptime: Int32 | Nil,
               iscachedbuild: Int32 | Nil,
               buildstatus: Int32 | Nil,
               size: Int64 | Nil,
               closuresize: Int64 | Nil,
               keep: Int32,
               notificationpendingsince: Int32 | Nil}

alias QUERY_EVALS_TYPE = {id: Int32,
                          project: String,
                          jobset: String,
                          timestamp: Int32,
                          checkouttime: Int32,
                          evaltime: Int32,
                          hasnewbuilds: Int32,
                          hash: String,
                          nrbuilds: Int32 | Nil,
                          nrsucceeded: Int32 | Nil,
                          flake: String | Nil}

QUERY_EVALS = {id: Int32,
               project: String,
               jobset: String,
               timestamp: Int32,
               checkouttime: Int32,
               evaltime: Int32,
               hasnewbuilds: Int32,
               hash: String,
               nrbuilds: Int32 | Nil,
               nrsucceeded: Int32 | Nil,
               flake: String | Nil}

alias QUERY_EVAL_INPUTS_TYPE = {eval: Int32,
                                name: String,
                                altnr: Int32,
                                type: String,
                                uri: String | Nil,
                                revision: String | Nil,
                                value: String | Nil,
                                dependency: Int32 | Nil,
                                path: String | Nil,
                                sha256hash: String | Nil}

QUERY_EVAL_INPUTS = {eval: Int32,
                     name: String,
                     altnr: Int32,
                     type: String,
                     uri: String | Nil,
                     revision: String | Nil,
                     value: String | Nil,
                     dependency: Int32 | Nil,
                     path: String | Nil,
                     sha256hash: String | Nil}

STDOUT.sync = true
LOG = Logger.new(STDOUT)
# LOG = Logger.new(File.open(LOG_FILE, "a"))

if LOG_LEVELS.has_key? LOG_LEVEL
  LOG.level = LOG_LEVELS[LOG_LEVEL]
else
  raise "Unknown log level: #{LOG_LEVEL}"
end

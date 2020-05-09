# Hydra Crystal Notifier
# Setup Config
#

LOG_LEVEL         = ENV.fetch("LOG_LEVEL", "INFO")
LOG_FILE          = ENV.fetch("LOG_FILE", "/var/lib/hydra/notification-debug.log")
CFG_FILE          = ENV.fetch("CFG_FILE", "/var/lib/hydra/github-notify.conf")
MOCK_MODE         = ENV.fetch("MOCK_MODE", "FALSE")
CURRENT_MODE      = ENV.fetch("CURRENT_MODE", "TRUE")
BASE_URI          = ENV.fetch("BASE_URI", "https://hydra.iohk.io")
DB_USER           = ENV.fetch("DB_USER", "")
DB_DATABASE       = ENV.fetch("DB_DATABASE", "hydra")
DB_HOST           = ENV.fetch("DB_HOST", "/run/postgresql")
NOTIFY_URL        = ENV.fetch("NOTIFY_URL", "DEFAULT")
API_PERIOD        = ENV.fetch("API_PERIOD", "3600").to_i
NOTIFIED_TTL      = ENV.fetch("NOTIFIED_TTL", "#{8 * 3600}").to_i
MAINT_CHECKS      = ENV.fetch("MAINT_CHECKS", "300").to_i
COMMIT_RATE_LIMIT = ENV.fetch("COMMIT_RATE_LIMIT", "10").to_i

URI_VAL           = %r([:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:.git)?$)
DAMPING_ASYMPTOTE = 1.1
DAMPING_CONSTANT  = API_PERIOD * Math.log(2) / Math.log(11)

LOG_LEVELS = {"FATAL"   => Logger::FATAL,
              "ERROR"   => Logger::ERROR,
              "WARN"    => Logger::WARN,
              "INFO"    => Logger::INFO,
              "DEBUG"   => Logger::DEBUG,
              "UNKNOWN" => Logger::UNKNOWN}

LISTEN_CHANNELS = {"step_started"   => '\t',
                   "step_started"   => '\t',
                   "step_finished"  => '\t',
                   "build_started"  => '\t',
                   "build_finished" => '\t',
                   "eval_started"   => '\t',
                   "eval_failed"    => '\t',
                   "eval_cached"    => '\t',
                   "eval_added"     => '\t'}

alias QUERY_BUILD_TYPE = {id: Int32, finished: Int32, timestamp: Int32, project: String, jobset: String, job: String, nixname: String, drvpath: String, system: String, iscurrent: Int32 | Nil, starttime: Int32 | Nil, stoptime: Int32 | Nil, iscachedbuild: Int32 | Nil, buildstatus: Int32 | Nil, size: Int64 | Nil, closuresize: Int64 | Nil, keep: Int32, notificationpendingsince: Int32 | Nil, jobset_id: Int32}

QUERY_BUILD = {id:                       Int32,
               finished:                 Int32,
               timestamp:                Int32,
               project:                  String,
               jobset:                   String,
               job:                      String,
               nixname:                  String,
               drvpath:                  String,
               system:                   String,
               iscurrent:                Int32 | Nil,
               starttime:                Int32 | Nil,
               stoptime:                 Int32 | Nil,
               iscachedbuild:            Int32 | Nil,
               buildstatus:              Int32 | Nil,
               size:                     Int64 | Nil,
               closuresize:              Int64 | Nil,
               keep:                     Int32,
               notificationpendingsince: Int32 | Nil,
               jobset_id:                Int32}

alias QUERY_EVALS_TYPE = {id: Int32, project: String, jobset: String, timestamp: Int32, checkouttime: Int32, evaltime: Int32, hasnewbuilds: Int32, hash: String, nrbuilds: Int32 | Nil, nrsucceeded: Int32 | Nil, flake: String | Nil}

QUERY_EVALS = {id:           Int32,
               project:      String,
               jobset:       String,
               timestamp:    Int32,
               checkouttime: Int32,
               evaltime:     Int32,
               hasnewbuilds: Int32,
               hash:         String,
               nrbuilds:     Int32 | Nil,
               nrsucceeded:  Int32 | Nil,
               flake:        String | Nil}

alias QUERY_EVAL_INPUTS_TYPE = {eval: Int32, name: String, altnr: Int32, type: String, uri: String | Nil, revision: String | Nil, value: String | Nil, dependency: Int32 | Nil, path: String | Nil, sha256hash: String | Nil}

QUERY_EVAL_INPUTS = {eval:       Int32,
                     name:       String,
                     altnr:      Int32,
                     type:       String,
                     uri:        String | Nil,
                     revision:   String | Nil,
                     value:      String | Nil,
                     dependency: Int32 | Nil,
                     path:       String | Nil,
                     sha256hash: String | Nil}

alias QUERY_AGGREGATE_STATUS_TYPE = {total: Int64, queued: Int64, finished: Int64, success: Int64, error: Int64, failed: Int64}

QUERY_AGGREGATE_STATUS = {total:    Int64,
                          queued:   Int64,
                          finished: Int64,
                          success:  Int64,
                          error:    Int64,
                          failed:   Int64}

STDOUT.sync = true
LOG = Logger.new(STDOUT)
# LOG = Logger.new(File.open(LOG_FILE, "a"))

if LOG_LEVELS.has_key? LOG_LEVEL
  LOG.level = LOG_LEVELS[LOG_LEVEL]
else
  raise "Unknown log level: #{LOG_LEVEL}"
end

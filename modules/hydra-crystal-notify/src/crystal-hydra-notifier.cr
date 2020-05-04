require "logger"
require "db"
require "pg"
require "json"
require "deep-merge"
require "./setup"
require "./config-parser"

class HydraNotifier

  @auth : Hash(Symbol, String)
  @notifyJobs : Array(Hash(String, String))
  @db : DB::Database
 
  def initialize
    # Obtain git auth, notify job specs and open db
    @auth, @notifyJobs = parseConfig(CFG_FILE)
    @db = DB.open("postgres:///")
 
    # Listen to and process notification payloads
    PG.connect_listen("postgres:///", LISTEN_CHANNELS.keys) do |n|
      case n.channel

      # Handle evals
      when /^eval/
        notifyEval(n)

      # Handle steps
      when /^step/
        notifyStep(n)

      # Handle builds
      when /^build/
        notifyBuild(n)

      else
        LOG.warn("#{n.channel} : #{n.payload} -- UNKNOWN LISTEN CHANNEL")
      end
    end
  end
 
  def notifyEval(n)
    LOG.debug("#{n.channel} : #{n.payload}}")
  end
 
  def notifyStep(n)
    LOG.debug("#{n.channel} : #{n.payload}")
  end
 
  def notifyBuild(n)
    flags = {:buildStarted => false,
             :buildFinished => false,
             :buildUnknown => false}

    # Flag the build type
    case n.channel
    when /^build_started$/
      flags[:buildStarted] = true
    when /^build_finished$/
      flags[:buildFinished] = true
    else
      flags[:buildUnknown] = true
      LOG.warn("#{n.channel} : #{n.payload} -- UNKNOWN BUILD CHANNEL")
    end

    p = n.payload.split(LISTEN_CHANNELS[n.channel])

    # Warn if started builds have deps
    if flags[:buildStarted] && p.size > 1
      LOG.warn("#{n.channel} : #{n.payload} -- UNEXPECTED STARTING BUILD WITH DEPS")
    end
   
    # Obtain the build table row for each build notification
    builds = [] of QUERY_BUILD_TYPE
    p.each do |b|
      if build = queryBuild(b)
        builds << build
      else
        LOG.error("#{n.channel} : #{n.payload} -- BUILD #{b} DOES NOT EXIST")
      end
    end

    # Start to implement the notify logic against the configuration
    LOG.debug("#{flags} : #{p}")
    LOG.debug("PROCESSING: #{builds}")

    builds.each do |build|
      # Obtain build evals
      unless evals = queryEvals(build[:id])
        LOG.error("#{n.channel} : #{n.payload} -- BUILD #{build[:id]} DOES NOT HAVE EVALS")
        next
      else
        evalsSize = evals.size
      end

      jobName = build[:project] + ':' + build[:jobset] + ':' + build[:job]
      LOG.debug("Build: #{build[:id]}, EvalSize: #{evalsSize}, JobName: #{jobName}")

      @notifyJobs.each do |conf|
        # Skip unmatched jobNames to job notify configs
        next unless jobName =~ /^#{conf["jobs"]}$/

        # Skip pending updates if the build is already finished
        next if flags[:buildStarted] && build[:finished] == 1;

        # Configure the context trailer
        case conf["excludeBuildFromContext"]
        when "0"
          contextTrailer = ":#{build[:id]}"
        when "1"
          contextTrailer = ""
        else
          LOG.error("#{n.channel} : #{n.payload} -- NOTIFY CONF DOES NOT HAVE PROPER EXCLUDE CONTEXT:\n#{conf}")
        end

        # Normalize job names so that PR and bors build statuses can be checked
        githubJobName = jobName.gsub(/-(pr-\d+|bors-(staging|trying))/, "")

        # TODO: Add optional conf context as an override
        extendedContext = "continuous-integration/hydra:" + jobName.to_s + contextTrailer.to_s
        shortContext = "ci/hydra:" + githubJobName.to_s + contextTrailer.to_s

        # Configure the context
        case conf["useShortContext"]
        when "0"
          context = extendedContext
        when "1"
          context = shortContext
        else
          LOG.error("#{n.channel} : #{n.payload} -- NOTIFY CONF DOES NOT HAVE PROPER SHORT CONTEXT:\n#{conf}")
        end

        inputs = conf["inputs"].split
        seen = Hash(String, Hash(String, Bool)).new
      
        evals.each do |eval|
          inputs.each do |input|
            LOG.info("Hash map: #{seen}") if seen.size > 0
            unless i = queryEvalInputs(eval[:id], input)
              LOG.debug("#{n.channel} : #{n.payload} -- MISSING EVAL INPUT FOR #{eval[:id]}, #{input}")
              next
            end
            uri = i["uri"]
            rev = i["revision"]
            key = uri.to_s + "-" + rev.to_s
            next if seen.dig?(input, key)
            seen.deep_merge!({ input => { key => true } })
            LOG.info("NOTIFYING FOR: #{n.channel} #{build[:id]} #{eval[:id]} #{key}")
          end
        end
      end
    end
  end
 
  def queryBuild(buildId)
    begin
      @db.query_one(<<-SQL, buildId, as: QUERY_BUILD)
        SELECT id,
               finished,
               timestamp,
               project,
               jobset,
               job,
               nixname,
               drvpath,
               system,
               iscurrent,
               starttime,
               stoptime,
               iscachedbuild,
               buildstatus,
               size,
               closuresize,
               keep,
               notificationpendingsince
        FROM builds WHERE id = $1 LIMIT 1
      SQL
    rescue ex : DB::NoResultsError
      LOG.error("queryBuild(#{buildId}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("queryBuild(#{buildId}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
  end
 
  def queryEvals(buildId)
    evals = [] of QUERY_EVALS_TYPE
    begin
      @db.query(<<-SQL, buildId) do |rs|
        SELECT id,
               project,
               jobset,
               timestamp,
               checkouttime,
               evaltime,
               hasnewbuilds,
               hash,
               nrbuilds,
               nrsucceeded,
               flake
        FROM jobsetevals WHERE id in (SELECT eval FROM jobsetevalmembers WHERE build = $1)
      SQL
        rs.each do
          evals << rs.read(**QUERY_EVALS)
        end
      end
    rescue ex : DB::NoResultsError
      LOG.error("queryEvals(#{buildId}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("queryEvals(#{buildId}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
    return evals
  end

  def queryEvalInputs(eval, input)
    begin
      @db.query_one(<<-SQL, eval, input, as: QUERY_EVAL_INPUTS)
        SELECT eval,
               name,
               altnr,
               type,
               uri,
               revision,
               value,
               dependency,
               path,
               sha256hash
        FROM jobsetevalinputs WHERE eval = $1 AND name = $2 AND altnr = '0' LIMIT 1
      SQL
    rescue ex : DB::NoResultsError
      LOG.debug("queryEvalInputs(#{eval},#{input}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("queryEvalInputs(#{eval},#{input}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
  end

  def finalize
    @db.close
  end
end

notifier = HydraNotifier.new

loop do
 sleep 1
end

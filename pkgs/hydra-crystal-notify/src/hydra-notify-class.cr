# Hydra Crystal Notifier
# HydraNotifier class: Postgres channel processing functions
#

class HydraNotifier
  getter evalNotified, buildNotified, maintTimestamp, dbListener
  setter evalNotified, buildNotified, maintTimestamp

  @auth : Hash(Symbol, String)
  @notifyJobs : Array(Hash(String, String))
  @dbListener : Fiber
  @db : DB::Database
  @buildNotified : Hash(String, Hash(String, String | Int64 | QUERY_AGGREGATE_STATUS_TYPE))
  @maintTimestamp : Int64

  def initialize
    # Obtain git auth, notify job specs and open db
    @auth, @notifyJobs = parseConfig(CFG_FILE)
    @db = DB.open(DB_CONN_STR)

    # Utilize a hash to track state of eval not recorded in postgres
    @evalNotified = Hash(String, Hash(String, String | Int64)).new

    # Utilize a hash to address a hydra notify race condition
    @buildNotified = Hash(String, Hash(String, String | Int64 | QUERY_AGGREGATE_STATUS_TYPE)).new

    @maintTimestamp = Time.utc.to_unix
    @mockMode = MOCK_MODE == "TRUE" ? true : false

    # Listen to and process notification payloads
    @dbListener = spawn(name: "dbListener") do
      PG.connect_listen(DB_CONN_STR, LISTEN_CHANNELS.keys) do |n|
        case n.channel
        # Handle evals
        when /^eval_pending/
          notifyEval(n)
        when /^eval_added/
          notifyEval(n)
        when /^eval_failed/
          notifyEval(n)
        when /^eval_started/
          debugNotification(n)
        when /^eval_cached/
          debugNotification(n)
          # Handle steps
        when /^step/
          debugNotification(n)
          # Handle started builds
        when /^build_started/
          notifyBuild(n)
          # Handle finished builds
        when /^build_finished/
          notifyBuild(n)
        else
          LOG.warn("#{n.channel} : #{n.payload} -- UNKNOWN LISTEN CHANNEL")
        end
      end
    end
  end

  def debugNotification(n)
    LOG.debug("#{n.channel} : #{n.payload}")
  end

  def notifyEval(n)
    flags = {:evalPending => false,
             :evalAdded   => false,
             :evalFailed  => false,
             :evalHashed  => false,
             :evalHistory => false}

    id = project = jobset = type = uri = rev = evalId = owner = repo = queryMsg = nil
    context = "ci/hydra-eval"
    timeEpochNow = Time.utc.to_unix
    timeRfc2822Now = Time.utc.to_rfc2822

    # Flag the build type
    case n.channel
    when /^eval_pending$/
      flags[:evalPending] = true
    when /^eval_added$/
      flags[:evalAdded] = true
    when /^eval_failed/
      flags[:evalFailed] = true
    end

    LOG.debug("#{n.channel} : #{n.payload}")
    p = n.payload.split(LISTEN_CHANNELS[n.channel])

    # Validate the raw eval notification
    if flags[:evalPending]
      if p.size != 6
        LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL_PENDING DOES NOT HAVE 6 FIELDS")
        return nil
      else
        id      = p[0]
        project = p[1]
        jobset  = p[2]
        type    = p[3]
        uri     = p[4]
        rev     = p[5]
        if (id !~ /^\d+\.\d+\.\d+$/ || type != "git" || uri == "NO_URI" || rev  == "NO_REV")
          LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL_PENDING FIELD VALIDATION ERROR")
          return nil
        else
          jobSet = "#{project}:#{jobset}"
          key = "#{uri}|#{rev}"
        end
      end
    elsif flags[:evalAdded]
      if p.size != 2
        LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL_ADDED DOES NOT HAVE 2 FIELDS")
        return nil
      else
        id = p[0]
        evalId  = p[1]
        LOG.debug("EVAL_ADDED: id: #{id}, evalId: #{evalId}")
        if (id !~ /^\d+\.\d+\.\d+$/ || evalId !~ /^\d+$/)
          LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL_ADDED FIELD VALIDATION ERROR")
          return nil
        end
      end
    elsif flags[:evalFailed]
      if p.size != 1
        LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL_FAILED DOES NOT HAVE 1 FIELD")
        return nil
      else
        id = p[0]
        if id !~ /^\d+\.\d+\.\d+$/
          LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL_FAILED FIELD VALIDATION ERROR")
          return nil
        end
      end
    end

    # Determine relevant evalNotified hash status and extract relevant info
    if flags[:evalPending]
      if @evalNotified.dig?(key.to_s)
        flags[:evalHashed] = true
      end
    elsif flags[:evalAdded]
      if key = @evalNotified.select { |k, v| v.has_value?(id) }.first_key?
        uri = key.split('|')[0]
        rev = key.split('|')[1]
        jobSet = @evalNotified[key]["jobSet"]
        project = jobSet.to_s.split(':')[0]
        jobset = jobSet.to_s.split(':')[1]
        flags[:evalHashed] = true
      end
      # eval_failed will return if hash status is not found
    elsif flags[:evalFailed]
      if key = @evalNotified.select { |k, v| v.has_value?(id) }.first_key?
        uri = key.split('|')[0]
        rev = key.split('|')[1]
        jobSet = @evalNotified[key]["jobSet"]
        project = jobSet.to_s.split(':')[0]
        jobset = jobSet.to_s.split(':')[1]
        flags[:evalHashed] = true
      else
        return nil
      end
    end

    # Set corresponding owner and repo info if available
    if (flags[:evalPending] ||
       (flags[:evalAdded] && flags[:evalHashed]) ||
       (flags[:evalFailed] && flags[:evalHashed]))
      unless m = URI_VAL.match(uri.to_s)
        LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL URI VALIDATION FAILED")
        return nil
      else
        owner = m["owner"]
        repo = m["repo"]
      end
    end

    evalSeen = Hash(String, Hash(String, Bool)).new

    # Determine relevant API and DB state history
    if !flags[:evalHashed]
      if flags[:evalPending] && jobset != ".jobsets"
        apiUrl = "https://api.github.com/repos/#{owner}/#{repo}/statuses/#{rev}"
        historyState, queryMsg = existingState(context, apiUrl)
        if historyState
          flags[:evalHistory] = true
        end
      elsif flags[:evalAdded]
        LOG.debug("EVAL_ADDED: DB STATE QUERY")
        # Obtain eval_added jobSet info
        unless i = queryEval(evalId)
          LOG.debug("#{n.channel} : #{n.payload} -- MISSING EVAL FOR #{evalId}")
          return nil
        else
          jobSet = "#{i["project"]}:#{i["jobset"]}"
          LOG.debug("EVAL_ADDED: DB QUERY OBTAINED -- jobSet: #{jobSet}")
          # Obtain eval_added key info
          jobsetInput = i["jobset"].gsub(/-(pr-\d+|bors-(staging|trying))/, "")
          unless j = queryEvalInputs(evalId, jobsetInput)
            LOG.debug("#{n.channel} : #{n.payload} -- MISSING EVAL INPUT FOR #{evalId}, #{jobsetInput}")
            return nil
          else
            uri = j["uri"]
            rev = j["revision"]
            key = "#{uri}|#{rev}"
            LOG.debug("EVAL_ADDED: DB QUERY OBTAINED -- uri: #{uri}, rev: #{rev}")
            unless m = URI_VAL.match(uri.to_s)
              LOG.error("#{n.channel}: #{n.payload}, Size: #{p.size} -- EVAL URI VALIDATION FAILED")
              return nil
            else
              owner = m["owner"]
              repo = m["repo"]
              LOG.debug("EVAL_ADDED: DB QUERY OBTAINED -- owner: #{owner}, repo: #{repo}")
            end
          end
        end
      end
    end

    @notifyJobs.each do |conf|

      # confName defined as project:jobset:job
      confName = conf["jobs"]

      # confJob defined as job from confName
      confJob = confName.gsub(/^[^:]+:[^:]+:/, "")

      # confJobSet defined as project:jobset from confName
      confJobSet = confName.gsub(/:[^:]+$/, "")

      inputs = conf["inputs"].split
      inputs.each do |input|

        # Skip unmatched jobSets to jobSet notify configs
        unless jobSet =~ /^#{confJobSet}$/
          LOG.debug("evalJobset: #{jobSet} doesn't match confJobSet: #{confJobSet} -- SKIPPING")
          next
        else
          LOG.debug("evalJobset: #{jobSet} matches confJobSet: #{confJobSet}")
        end

        # Skip if the current jobSet and key has already been processed
        next if evalSeen.dig?(jobSet.to_s, key.to_s)
        evalSeen.deep_merge!({jobSet.to_s => {key.to_s => true}})

        # Determine notify state and description
        if flags[:evalPending]
          # Pending eval cannot update again if a state already exists
          if flags[:evalHashed] || flags[:evalHistory]
            LOG.debug("#{n.channel} : #{n.payload} -- DISCARDING DUE TO HASHED OR HISTORY")
            existingState = @evalNotified.has_key?(key) ? @evalNotified[key]["state"] : historyState
            @evalNotified.deep_merge!({key.to_s => {"at" => timeEpochNow,
                                                    "state" => "#{existingState}",
                                                    "id" => "#{id}",
                                                    "jobSet" => "#{jobSet}"
            }})
            return nil
          else
            state = "pending"
            target_url = "#{BASE_URI}/jobset/#{project}/#{jobset}#tabs-evaluations"
          end
        elsif flags[:evalAdded]
          # Success eval can update only if not already success
          if ((flags[:evalHashed] && @evalNotified[key] && @evalNotified[key]["state"] == "success") ||
              (flags[:evalHistory] && historyState == "success"))
            @evalNotified.deep_merge!({key.to_s => {"at" => timeEpochNow,
                                                    "state" => "success",
                                                    "id" => "#{id}",
                                                    "jobSet" => "#{jobSet}"
            }})
            return nil
          else
            state = "success"
            target_url = "#{BASE_URI}/eval/#{evalId}"
          end
        elsif flags[:evalFailed]
          # Failed eval can update only if not already error
          if flags[:evalHashed] && @evalNotified[key] && @evalNotified[key]["state"] == "error"
            @evalNotified.deep_merge!({key.to_s => {"at" => timeEpochNow,
                                                    "state" => "error",
                                                    "id" => "#{id}",
                                                    "jobSet" => "#{jobSet}"
            }})
            return nil
          else
            state = "error"
            target_url = "#{BASE_URI}/jobset/#{project}/#{jobset}#tabs-errors"
          end
        else
          # Failure eval can update only if not already failure
          if ((flags[:evalHashed] && @evalNotified[key] && @evalNotified[key]["state"] == "failure") ||
              (flags[:evalHistory] && historyState == "failure"))
            @evalNotified.deep_merge!({key.to_s => {"at" => timeEpochNow,
                                                    "state" => "failure",
                                                    "id" => "#{id}",
                                                    "jobSet" => "#{jobSet}"
            }})
            return nil
          else
            state = "failure"
            target_url = "#{BASE_URI}/jobset/#{project}/#{jobset}#failure-unknown"
            LOG.error("#{n.channel}: #{n.payload} -- EVAL NOTIFY UNKONWN STATE")
          end
        end

        # Configure the description
        description = "#{state} since #{timeRfc2822Now}"
        if description.size > 140
          LOG.warn("#{n.channel} : #{id} #{jobSet} -- SLICING DESCRIPTION AT 140 CHARS")
          description = description[0, 140]
        end

        # TODO: check gsub parameterization to avoid non-laziness raise
        # Deploy parameterized URL
        if NOTIFY_URL == "DEFAULT"
          url = "https://api.github.com/repos/#{owner}/#{repo}/statuses/#{rev}"
        else
          url = NOTIFY_URL
        end

        LOG.info("------------------------------------------")
        LOG.info("evalJobSet: #{jobSet}")
        LOG.info(queryMsg) if queryMsg
        LOG.info("#{flags}")
        LOG.debug("config: #{conf}")
        LOG.debug("input: #{input}")
        LOG.debug("evalSeen: #{evalSeen}")

        # Finalize
        body = {"state"       => "#{state}",
                "target_url"  => "#{target_url}",
                "description" => "#{description}",
                "context"     => "#{context}",
               }.to_json

        successMsgPrefix = "NOTIFIED: #{n.channel} #{id} #{url}"
        exceptMsgPrefix = "statusNotify: #{n.channel} #{id}\nURL: #{url}"
        rateMsg = "RATE_LIMITED: #{n.channel} #{id} #{url}\n#{body}"
        mockMsg = "MOCK NOTIFIED: #{n.channel} #{id} #{url}\n#{body}"

        # Submit the notification, with mock and rateLimit info
        statusNotify(successMsgPrefix,
                        exceptMsgPrefix,
                        rateMsg,
                        mockMsg,
                        url,
                        body,
                        mock: @mockMode,
                        rateLimit: false)
        @evalNotified.deep_merge!({key.to_s => {"at" => timeEpochNow,
                                                "state" => "#{state}",
                                                "id" => "#{id}",
                                                "jobSet" => "#{jobSet}"
        }})
      end
    end
  end

  def notifyBuild(n)
    flags = {:buildStarted         => false,
             :buildFinished        => false,
             :buildTarget          => false,
             :buildTargetAggregate => false,
             :buildConstituent     => false,
             :rateLimit            => false}

    # Flag the build type
    case n.channel
    when /^build_started$/
      flags[:buildStarted] = true
    when /^build_finished$/
      flags[:buildFinished] = true
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

    LOG.debug("PROCESSING BUILD(S): #{n.channel} #{p}\n#{builds}")

    builds.each do |build|
      # Only consider builds which are current
      if CURRENT_MODE == "TRUE" && !build[:iscurrent] == 1
        LOG.debug("#{n.channel} : #{n.payload} -- BUILD #{build[:id]} IS NOT CURRENT")
        next
      end

      # Skip pending updates if the build is already finished
      next if flags[:buildStarted] && build[:finished] == 1
      # Obtain build evals
      unless evals = queryEvals(build[:id])
        LOG.error("#{n.channel} : #{n.payload} -- BUILD #{build[:id]} DOES NOT HAVE EVALS")
        next
      else
        evalsSize = evals.size
      end

      jobSet = "#{build[:project]}:#{build[:jobset]}"
      jobName = "#{jobSet}:#{build[:job]}"
      LOG.debug("#{n.channel}: #{build[:id]}, EvalSize: #{evalsSize}, JobName: #{jobName}")

      @notifyJobs.each do |conf|
        # confName defined as project:jobset:job
        confName = conf["jobs"]

        # confJob defined as job from confName
        confJob = confName.gsub(/^[^:]+:[^:]+:/, "")

        # confJobSet defined as project:jobset from confName
        confJobSet = confName.gsub(/:[^:]+$/, "")

        # Skip unmatched jobSets to jobSet notify configs
        unless jobSet =~ /^#{confJobSet}$/
          LOG.debug("buildJobset: #{jobSet} doesn't match confJobSet: #{confJobSet} -- SKIPPING")
          next
        else
          LOG.debug("buildJobset: #{jobSet} matches confJobSet: #{confJobSet}")
        end

        # Determine if this build is a conf target
        if jobName =~ /^#{confName}$/
          flags[:buildTarget] = true
        else
          flags[:buildTarget] = false
        end

        inputs = conf["inputs"].split
        buildSeen = Hash(String, Hash(String, Bool)).new

        evals.each do |eval|
          inputs.each do |input|
            # Verify the hashmap when multiple evals per build are found
            LOG.debug("buildHash map #{n.channel} #{build[:id]} #{eval[:id]} #{input}: #{buildSeen}") if buildSeen.size > 0

            # Skip notifying on evals which have missing inputs
            unless i = queryEvalInputs(eval[:id], input)
              LOG.debug("#{n.channel} : #{n.payload} -- MISSING EVAL INPUT FOR #{eval[:id]}, #{input}")
              next
            end

            uri = i["uri"]
            rev = i["revision"]
            key = "#{uri}-#{rev}"
            next if buildSeen.dig?(input, key)
            buildSeen.deep_merge!({input => {key => true}})

            # Skip notifying on builds with invalid reporting URIs
            unless m = URI_VAL.match(uri.to_s)
              LOG.error("#{n.channel} : #{n.payload} -- EVAL URI VALIDATION FAILED FOR #{eval[:id]}, #{input}")
              next
            end

            # Determine if the conf target is an aggregate
            if aggregateTarget = aggregateBuild(eval[:id], confJob)
              flags[:buildTargetAggregate] = true
              LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- confJob \"#{confJob}\" is an aggregate #{aggregateTarget}")
            else
              flags[:buildTargetAggregate] = false
              LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- confJob \"#{confJob}\" is NOT an aggregate")
            end

            # Skip notifying if this build is not the conf target and target is not an aggregate
            if !flags[:buildTargetAggregate] && !flags[:buildTarget]
              LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- NOT the confJob and confJob \"#{confJob}\" is NOT an aggregate")
              next
            end

            # Determine if this build is a constituent of the conf target; if not, skip notifying
            if flags[:buildTargetAggregate] && !flags[:buildTarget]
              if constituentBuild(build[:id], aggregateTarget)
                flags[:buildConstituent] = true
                if build[:id] == aggregateTarget
                  LOG.warn("#{n.channel} : #{build[:id]} #{eval[:id]} -- AGGREGATE IS A CONSTITUENT OF ITSELF FOR \"#{confJob}\" aggregate #{aggregateTarget}")
                end
                LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- is a constituent of confJob \"#{confJob}\" aggregate #{aggregateTarget}")
              else
                flags[:buildConstituent] = false
                LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- is NOT a constituent of confJob \"#{confJob}\" aggregate #{aggregateTarget}")
                next
              end
            end

            # Obtain aggregate stats if appropriate
            if flags[:buildTargetAggregate]
              if aggregateMetrics = aggregateStatus(aggregateTarget)
                LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- aggregate #{aggregateTarget} metrics: #{aggregateMetrics}")
                aggregateDescription = aggregateMetrics.to_s
              else
                LOG.error("#{n.channel} : #{build[:id]} #{eval[:id]} -- FAILURE checking aggregateStatus(#{aggregateTarget})")
                aggregateDescription = "{ METRICS_ERROR }"
              end
            end

            # Determine notify state
            if flags[:buildTargetAggregate]
              if flags[:buildTarget]
                # The aggregate job determines or re-determines, in the case of rebuild, the state
                if flags[:buildStarted]
                  state = "pending"
                else
                  state = queryState(aggregateTarget)
                end
              else
                # A constituent started/finished build can't update the aggregate state
                if @buildNotified.has_key?(key)
                  state = @buildNotified[key]["state"]
                else
                  # When no hash state exists, check the aggregate state to ensure we didn't start during a race condition
                  LOG.debug("#{n.channel} : #{build[:id]} #{eval[:id]} -- CONSTITUENT TO AGGREGATE STATE DB LOOKUP PERFORMED")
                  state = queryState(aggregateTarget)
                end
              end
            else
              # A non-aggregate target directly determines it's state
              if flags[:buildStarted]
                state = "pending"
              else
                state = toGithubState(build)
              end
            end

            # Configure the notification url and description
            if flags[:buildTargetAggregate]
              target_url = "#{BASE_URI}/build/#{aggregateTarget}"
              description = "#{aggregateDescription}"
            else
              target_url = "#{BASE_URI}/build/#{build[:id]}"
              description = "#{state}"
            end

            if description.size > 140
              LOG.warn("#{n.channel} : #{build[:id]} #{eval[:id]} -- SLICING DESCRIPTION AT 140 CHARS")
              description = description[0, 140]
            end

            # Deploy parameterized URL
            if NOTIFY_URL == "DEFAULT"
              url = "https://api.github.com/repos/#{m["owner"]}/#{m["repo"]}/statuses/#{rev}"
            else
              url = NOTIFY_URL
            end

            # Make final notify context mods
            if flags[:buildTargetAggregate]
              context = "ci/hydra-build:#{confJob}"
            else
              context = "ci/hydra-build:#{build[:job]}"
            end

            # Determine rate limiting; start by ensuring the flag is false
            flags[:rateLimit] = false

            # Add a log event header for easier viewing
            LOG.info("------------------------------------------")

            # Only consider a limit if the build target is an aggregate
            if flags[:buildTargetAggregate]
              # Only consider a limit if state already pre-exists
              if @buildNotified.has_key?(key)
                # Apply a limit if previous state notification is the same
                if @buildNotified[key]["state"] == state && @buildNotified[key]["aggregateMetrics"].to_s == aggregateDescription
                  LOG.info("ENABLING SAME PUSH RATE LIMIT")
                  flags[:rateLimit] = true
                else
                  # Only consider a time based limit for constituents since they can be large in number
                  # TODO: Address edge case where flags[:buildConstituent] is unexpectedly true
                  if !flags[:buildTarget]
                    sinceLastNotified = Time.utc.to_unix - @buildNotified[key]["at"].as(Int64)
                    if sinceLastNotified < COMMIT_RATE_LIMIT
                      # Only consider a limit if queued > 0 or queued == 0 and total > finished
                      if aggregateMetrics && aggregateMetrics[:queued] > 0
                        LOG.info("ENABLING PER COMMIT RATE LIMIT (queued > 0)")
                        flags[:rateLimit] = true
                      elsif aggregateMetrics && (aggregateMetrics[:queued] == 0) && (aggregateMetrics[:total] > aggregateMetrics[:finished])
                        LOG.info("ENABLING PER COMMIT RATE LIMIT (queued == 0 && total > finished)")
                        flags[:rateLimit] = true
                      end
                    end
                  end
                end
              end
            end

            LOG.info("buildJobName: #{jobName}")
            LOG.info("#{flags}")

            body = {"state"       => "#{state}",
                    "target_url"  => "#{target_url}",
                    "description" => "#{description}",
                    "context"     => "#{context}",
                   }.to_json

            successMsgPrefix = "NOTIFIED: #{n.channel} #{build[:id]} #{eval[:id]} #{url}"
            exceptMsgPrefix = "statusNotify: #{n.channel} #{build[:id]} #{eval[:id]}\nURL: #{url}"
            rateMsg = "RATE_LIMITED: #{n.channel} #{build[:id]} #{eval[:id]} #{url}\n#{body}"
            mockMsg = "MOCK NOTIFIED: #{n.channel} #{build[:id]} #{eval[:id]} #{url}\n#{body}"

            # Submit the notification, with mock and rateLimit info
            if statusNotify(successMsgPrefix,
                            exceptMsgPrefix,
                            rateMsg,
                            mockMsg,
                            url,
                            body,
                            mock: @mockMode,
                            rateLimit: flags[:rateLimit])
              # State keys are only needed for aggregate targets
              if !flags[:rateLimit] && flags[:buildTargetAggregate]
                @buildNotified.deep_merge!({key => {"at" => Time.utc.to_unix,
                                               "state" => "#{state}",
                                               "aggregateMetrics" => aggregateMetrics ? aggregateMetrics : "{ METRICS ERROR }"
                }})
              end
            end
          end
        end
      end
    end
  end

  def existingState(context, url)
    begin
      r = Crest.get(
        url,
        headers: {
          "Content-Type"  => "application/json",
          "Accept"        => "application/vnd.github.v3+json",
          "Authorization" => "#{@auth[:type]} #{@auth[:secret]}"
        }
      )
      LOG.debug("existingState:\n#{r.http_client_res.pretty_inspect}")

      existing = Array(ExistingState).from_json(r.body)
      existing.reject! { |a| a.context != context || !a.updatedAt || !a.state }
      existing.sort! { |a, b| b.updatedAt.as(Time) <=> a.updatedAt.as(Time) }
      existingState = existing.size > 0 ? existing.first.state : nil

      limit = r.headers["X-RateLimit-Limit"].to_s.to_i
      limitRemaining = r.headers["X-RateLimit-Remaining"].to_s.to_i
      limitReset = r.headers["X-RateLimit-Reset"].to_s.to_i
      diff = limitReset - Time.utc.to_unix
      delay = (limitRemaining > 0 ? diff / limitRemaining : diff) * damping(diff)

      msg = "QUERY API STATE: #{existingState ? existingState : "nil"} #{url} #{limitRemaining} #{diff} #{delay.format(decimal_places: 1)}"
      sleep delay
    rescue ex : Crest::RequestFailed
      msg = "EXCEPTION: \"#{ex}\"\nRESPONSE: #{ex.response}"
      existingState = nil
      LOG.error(msg)
    rescue ex
      msg = "EXCEPTION: \"#{ex}\""
      existingState = nil
      LOG.error("EXCEPTION: \"#{ex}\"")
    end
    return existingState, msg
  end

  class ExistingState
    JSON.mapping(
      context:   {type: String?, key: "context"},
      updatedAt: {type: Time?, key: "updated_at"},
      state:     {type: String?, key: "state"}
    )
  end

  def statusNotify(successMsgPrefix,
                   exceptMsgPrefix,
                   rateMsg,
                   mockMsg,
                   url,
                   body,
                   mock : Bool = false,
                   rateLimit : Bool = false)
    if !mock && !rateLimit
      begin
        r = Crest.post(
          url,
          headers: {
            "Content-Type"  => "application/json",
            "Accept"        => "application/vnd.github.v3+json",
            "Authorization" => "#{@auth[:type]} #{@auth[:secret]}"
          },
          form: body
        )
        LOG.debug("statusNotify:\n#{r.http_client_res.pretty_inspect}")
        limit = r.headers["X-RateLimit-Limit"].to_s.to_i
        limitRemaining = r.headers["X-RateLimit-Remaining"].to_s.to_i
        limitReset = r.headers["X-RateLimit-Reset"].to_s.to_i
        diff = limitReset - Time.utc.to_unix
        delay = (limitRemaining > 0 ? diff / limitRemaining : diff) * damping(diff)
        LOG.info("#{successMsgPrefix} #{limitRemaining} #{diff} #{delay.format(decimal_places: 1)}\n#{body}")
        sleep delay
      rescue ex : Crest::RequestFailed
        LOG.error("#{exceptMsgPrefix}\nEXCEPTION: \"#{ex}\"\nRESPONSE: #{ex.response}\nBODY: #{body}")
        return nil
      rescue ex
        LOG.error("#{exceptMsgPrefix}\nEXCEPTION: \"#{ex}\"")
        return nil
      end
    elsif rateLimit
      LOG.info("#{rateMsg}")
    else
      LOG.info("#{mockMsg}")
    end
    return true
  end

  def damping(timeRemaining)
    # A function to continuously dampen the time average API call calculation early in the API period

    # If the upstream API parameters have changed and now don't make sense, do not damp
    if (timeRemaining < 0) || (timeRemaining > API_PERIOD)
      return 1
    end

    # Exponential damping/attentuation function with (100%, 0%) attenuation at (API_PERIOD, 0) timeRemaining, respectively
    dampFactor = (DAMPING_ASYMPTOTE * (1 - Math.exp2(-1 * (API_PERIOD - timeRemaining) / DAMPING_CONSTANT)))
    if !dampFactor.is_a?(Number) || dampFactor < 0 || dampFactor > 1
      dampFactor = 1
    end
    LOG.debug("DampFactor: #{dampFactor}")
    return dampFactor
  end

  def finalize
    @db.close
  end
end

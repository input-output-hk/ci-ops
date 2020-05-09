# Hydra Crystal Notifier
# HydraNotifier class: Postgres channel processing functions
#

class HydraNotifier
  getter notified, maintTimestamp
  setter notified, maintTimestamp

  @auth : Hash(Symbol, String)
  @notifyJobs : Array(Hash(String, String))
  @db : DB::Database
  @notified : Hash(String, Hash(String, String | Int64 | QUERY_AGGREGATE_STATUS_TYPE))
  @maintTimestamp : Int64

  def initialize
    # Obtain git auth, notify job specs and open db
    @auth, @notifyJobs = parseConfig(CFG_FILE)
    @db = DB.open("postgres://#{DB_USER}/#{DB_DATABASE}?host=#{DB_HOST}")

    # Utilize a hash to address a hydra notify race condition
    @notified = Hash(String, Hash(String, String | Int64 | QUERY_AGGREGATE_STATUS_TYPE)).new

    @maintTimestamp = Time.utc.to_unix
    @mockMode = MOCK_MODE == "TRUE" ? true : false

    # Listen to and process notification payloads
    PG.connect_listen("postgres://#{DB_USER}/#{DB_DATABASE}?host=#{DB_HOST}", LISTEN_CHANNELS.keys) do |n|
      case n.channel
      # Handle evals
      when /^eval/
        notifyEval(n)
        # Handle steps
      when /^step/
        notifyStep(n)
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

  def notifyEval(n)
    LOG.debug("#{n.channel} : #{n.payload}}")
  end

  def notifyStep(n)
    LOG.debug("#{n.channel} : #{n.payload}")
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
          LOG.debug("Jobset: #{jobSet} doesn't match confJobSet: #{confJobSet} -- SKIPPING")
          next
        else
          LOG.debug("Jobset: #{jobSet} matches confJobSet: #{confJobSet}")
        end

        # Determine if this build is a conf target
        if jobName =~ /^#{confName}$/
          flags[:buildTarget] = true
        else
          flags[:buildTarget] = false
        end

        inputs = conf["inputs"].split
        seen = Hash(String, Hash(String, Bool)).new

        evals.each do |eval|
          inputs.each do |input|
            # Verify the hashmap when multiple evals per build are found
            LOG.info("Hash map #{n.channel} #{build[:id]} #{eval[:id]} #{input}: #{seen}") if seen.size > 0

            # Skip notifying on evals which have missing inputs
            unless i = queryEvalInputs(eval[:id], input)
              LOG.debug("#{n.channel} : #{n.payload} -- MISSING EVAL INPUT FOR #{eval[:id]}, #{input}")
              next
            end

            uri = i["uri"]
            rev = i["revision"]
            key = "#{uri}-#{rev}"
            next if seen.dig?(input, key)
            seen.deep_merge!({input => {key => true}})

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
                if @notified.has_key?(key)
                  state = @notified[key]["state"]
                else
                  # When no hash state exists, check the aggregate state to ensure we didn't start during a race condition
                  LOG.info("#{n.channel} : #{build[:id]} #{eval[:id]} -- CONSTITUENT TO AGGREGATE STATE DB LOOKUP PERFORMED")
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

            # Live github status submission url
            # url = "https://api.github.com/repos/#{m["owner"]}/#{m["repo"]}/statuses/#{rev}"

            # Test submissions on a non-github test server
            # url = "http://<HOST>:<PORT>/api.github.com/repos/#{m["owner"]}/#{m["repo"]}/statuses/#{rev}"

            # Test submissions on github on a throw-away branch with a test commit
            # url = "https://api.github.com/repos/<OWNER>/<REPO>/statuses/<COMMIT>"

            # Make final notify context mods
            if flags[:buildTargetAggregate]
              context = "ci/hydra-build:#{confJob}"
            else
              context = "ci/hydra-build:#{build[:job]}"
            end

            # Determine rate limiting; start by ensuring the flag is false
            flags[:rateLimit] = false

            # Only consider a limit if the build target is an aggregate
            if flags[:buildTargetAggregate]
              # Only consider a limit if state already pre-exists
              if @notified.has_key?(key)
                # Apply a limit if previous state notification is the same
                if @notified[key]["state"] == state && @notified[key]["aggregateMetrics"].to_s == aggregateDescription
                  LOG.info("ENABLING SAME PUSH RATE LIMIT")
                  flags[:rateLimit] = true
                else
                  # Only consider a time based limit for constituents since they can be large in number
                  # TODO: Address edge case where flags[:buildConstituent] is unexpectedly true
                  if !flags[:buildTarget]
                    sinceLastNotified = Time.utc.to_unix - @notified[key]["at"].as(Int64)
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

            LOG.info("jobName: #{jobName}")
            LOG.info("#{flags}")
            # Submit the notification, with mock and rateLimit info
            if statusNotify(n.channel,
                 build[:id],
                 eval[:id],
                 url,
                 {
                   "state"       => "#{state}",
                   "target_url"  => "#{target_url}",
                   "description" => "#{description}",
                   "context"     => "#{context}",
                 }.to_json, mock: @mockMode, rateLimit: flags[:rateLimit])
              # State keys are only needed for aggregate targets
              if !flags[:rateLimit] && flags[:buildTargetAggregate]
                @notified.deep_merge!({key => {"at" => Time.utc.to_unix,
                                               "state" => "#{state}",
                                               "aggregateMetrics" => aggregateMetrics ? aggregateMetrics : "{ METRICS ERROR }",
                }})
              end
            end
          end
        end
      end
    end
  end

  def statusNotify(channel, buildId, evalId, url, body, mock : Bool = false, rateLimit : Bool = false)
    if !mock && !rateLimit
      begin
        r = Crest.post(
          url,
          headers: {
            "Content-Type"  => "application/json",
            "Accept"        => "application/vnd.github.v3+json",
            "Authorization" => "#{@auth[:type]} #{@auth[:secret]}",
          },
          form: body
        )
        LOG.debug("statusNotify:\n#{r.http_client_res.pretty_inspect}")
        limit = r.headers["X-RateLimit-Limit"].to_s.to_i
        limitRemaining = r.headers["X-RateLimit-Remaining"].to_s.to_i
        limitReset = r.headers["X-RateLimit-Reset"].to_s.to_i
        diff = limitReset - Time.utc.to_unix
        delay = (limitRemaining > 0 ? diff / limitRemaining : diff) * damping(diff)
        LOG.info("NOTIFIED: #{channel} #{buildId} #{evalId} #{url} #{limitRemaining} #{diff} #{delay.format(decimal_places: 1)}\n#{body}\n")
        sleep delay
      rescue ex : Crest::RequestFailed
        LOG.error("statusNotify(#{buildId},#{evalId}) #{channel}\nURL: #{url}\nEXCEPTION: \"#{ex}\"\nRESPONSE: #{ex.response}\nBODY: #{body}")
        return nil
      end
    elsif rateLimit
      LOG.info("RATE_LIMITED: #{channel} #{buildId} #{evalId} #{url}\n#{body}\n")
    else
      LOG.info("MOCK NOTIFIED: #{channel} #{buildId} #{evalId} #{url}\n#{body}\n")
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

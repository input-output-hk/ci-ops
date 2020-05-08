# Hydra Crystal Notifier
# HydraNotifier class: DB related functions
#

class HydraNotifier
  def queryState(buildId)
    if b = queryBuild(buildId)
      return toGithubState(b)
    else
      LOG.error("queryState(#{buildId}) -- EXCEPTION: BUILD #{buildId} DOES NOT EXIST")
      return "error"
    end
  end

  def toGithubState(b)
    if b[:finished] == 0
      return "pending"
    else
      case b[:buildstatus]
      when 0
        return "success"
      when .in? [3, 4, 8, 10, 11]
        return "error"
      else
        return "failure"
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
               notificationpendingsince,
               jobset_id
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

  def queryEvalInputs(evalId, input)
    begin
      @db.query_one(<<-SQL, evalId, input, as: QUERY_EVAL_INPUTS)
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
      LOG.debug("queryEvalInputs(#{evalId},#{input}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("queryEvalInputs(#{evalId},#{input}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
  end

  def aggregateBuild(evalId, job)
    begin
      @db.scalar(<<-SQL, evalId, job)
        WITH evalBuilds (builds) AS (SELECT build FROM jobsetevalmembers WHERE eval = $1),
        targetJob (build) AS (SELECT id FROM builds WHERE id in (SELECT builds FROM evalBuilds) and job = $2),
        aggregateJob (build) as (SELECT aggregate FROM aggregateconstituents WHERE aggregate in (SELECT build FROM targetJob))
        SELECT DISTINCT build FROM aggregateJob
      SQL
    rescue ex : DB::NoResultsError
      LOG.debug("aggregateBuild(#{evalId},#{job}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("aggregateBuild(#{evalId},#{job}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
  end

  def constituentBuild(buildId, aggregateBuild)
    begin
      @db.scalar(<<-SQL, buildId, aggregateBuild)
        SELECT constituent FROM aggregateconstituents where constituent = $1 AND aggregate = $2
      SQL
    rescue ex : DB::NoResultsError
      LOG.debug("constituentBuild(#{buildId},#{aggregateBuild}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("constituentBuild(#{buildId},#{aggregateBuild}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
  end

  def aggregateStatus(aggregateBuild)
    begin
      @db.query_one(<<-SQL, aggregateBuild, as: QUERY_AGGREGATE_STATUS)
        WITH r AS (SELECT id, finished, buildstatus FROM builds WHERE id IN (SELECT constituent FROM aggregateconstituents WHERE aggregate = $1))
        SELECT
        (SELECT count(*) FROM r) AS total,
        (SELECT count(*) FROM r WHERE finished = 0) AS queued,
        (SELECT count(*) FROM r WHERE finished = 1) AS finished,
        (SELECT count(*) FROM r WHERE buildstatus = 0) AS success,
        (SELECT count(*) FROM r WHERE buildstatus IN (3, 4, 8, 10, 11)) AS error,
        (SELECT count(*) FROM r WHERE buildstatus NOT IN (0, 3, 4, 8, 10, 11)) AS failed
      SQL
    rescue ex : DB::NoResultsError
      LOG.debug("aggregateStatus(#{aggregateBuild}) -- EXCEPTION: \"#{ex.message}\"")
      return nil
    rescue ex
      LOG.error("aggregateStatus(#{aggregateBuild}) -- EXCEPTION: \"#{ex}\"\n#{ex.inspect_with_backtrace}")
      return nil
    end
  end
end

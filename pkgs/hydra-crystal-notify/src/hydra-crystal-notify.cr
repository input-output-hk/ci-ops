# Hydra Crystal Notifier
# Entry Point
#

require "log"
require "db"
require "pg"
require "json"
require "deep-merge"
require "crest"
require "./setup"
require "./config-parser"
require "./hydra-notify-class"
require "./hydra-notify-class-db"

def maintenance(notify)
  evalHash = notify.evalNotified
  evalSize = evalHash.size
  buildHash = notify.buildNotified
  buildSize = buildHash.size

  # Expire hashes older than NOTIFIED_TTL and provide a maintenance update
  ts = Time.utc.to_unix

  evalHash.delete_if { |k, v| (ts - v["at"].as(Int64)) > NOTIFIED_TTL }
  evalOldest = evalHash.size > 0 ? evalHash.min_of { |k, v| v["at"].as(Int64) } : ts
  evalNextPurge = NOTIFIED_TTL - (ts - evalOldest)

  buildHash.delete_if { |k, v| (ts - v["at"].as(Int64)) > NOTIFIED_TTL }
  buildOldest = buildHash.size > 0 ? buildHash.min_of { |k, v| v["at"].as(Int64) } : ts
  buildNextPurge = NOTIFIED_TTL - (ts - buildOldest)

  Log.info { "MAINTENANCE: { memKeySize, nowPurged, nextPurge }: " \
             "evalHash { #{evalSize}, #{evalSize - evalHash.size}, #{evalNextPurge} }; " \
             "buildHash { #{buildSize}, #{buildSize - buildHash.size}, #{buildNextPurge} }" }
end

notify = HydraNotifier.new
loop do
  raise "DB_LISTENER EXCEPTION" if notify.dbListener.dead?
  if Time.utc.to_unix - notify.maintTimestamp > MAINT_CHECKS
    maintenance(notify)
    notify.maintTimestamp = Time.utc.to_unix
  end
  sleep 1
end

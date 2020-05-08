# Hydra Crystal Notifier
# Entry Point
#

require "logger"
require "db"
require "pg"
require "json"
require "deep-merge"
require "crest"
require "./setup"
require "./config-parser"
require "./hydra-notifier-class"
require "./hydra-notifier-class-db"

def maintenance(notifier)
  h = notifier.notified
  size = h.size

  # Expire hashes older than NOTIFIED_TTL and provide a maintenance update
  ts = Time.utc.to_unix
  h.delete_if { |k, v| (ts - v["at"].as(Int64)) > NOTIFIED_TTL }
  oldest = h.size > 0 ? h.min_of { |k, v| v["at"].as(Int64) } : ts
  nextPurge = NOTIFIED_TTL - (ts - oldest)
  LOG.info("MAINTENANCE: { memKeySize, nowPurged, nextPurge }: { #{size}, #{size - h.size}, #{nextPurge} }")
end

notifier = HydraNotifier.new
loop do
  if Time.utc.to_unix - notifier.maintTimestamp > MAINT_CHECKS
    maintenance(notifier)
    notifier.maintTimestamp = Time.utc.to_unix
  end
  sleep 1
end

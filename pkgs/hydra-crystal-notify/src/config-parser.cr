# Hydra Crystal Notifier
# Config parsing related functions
#

def readFile(file)
  if (File.exists?(file) && !File.empty?(file))
    return File.read(file).strip
  else
    return ""
  end
end

def parseConfig(cfgFile)
  auth = Hash(Symbol, String).new

  tagStats = {:total       => 0,
              :authAdded   => 0,
              :authSkipped => 0,
              :jobAdded    => 0,
              :jobSkipped  => 0,
              :mismatched  => 0,
              :unknown     => 0,
  }

  # Tag regex format
  tagVal = /\<(?<stag>[^\>]+)\>\n(?<body>[^\<]+)\n\<\/(?<etag>[^\>]+)\>?/

  # Auth regex format
  authVal = /\s*[\w-]+\s*=\s*[\w-]+\s[0-9a-f]+\s*$/

  # Optional notify job conf keys and regex format
  notifyOptVal = {"context" => /^[\w-:]+$/}

  # Expected notify job conf keys and regex format
  notifyVal = {"jobs"                    => /^[^:]+:[^:]+:[^:]+$/,
               "inputs"                  => /^[\w-]+$/,
               "excludeBuildFromContext" => /^[01]$/,
               "useShortContext"         => /^[01]$/}

  notifyJobs = [] of Hash(String, String)

  # Read the file, removing comments and blank lines
  config = ""
  readFile(cfgFile).each_line do |l|
    unless l.lstrip =~ /^\s*$|^#/
      config += "\n" + l.lstrip
    end
  end

  # Scan for all open and close tags with content
  config.scan(tagVal) do |m|
    tagStats[:total] += 1
    md = {
      "stag": m["stag"],
      "body": m["body"],
      "etag": m["etag"],
    }.to_json

    # Raise on mismatched tags
    if m["stag"] != m["etag"]
      tagStats[:mismatched] += 1
      msg = "Found an unmatched config tag in file #{CFG_FILE} of:\n#{md}"
      Log.error { msg }
    end

    case m["stag"]
    # Process auths; use only the first valid auth found
    when "github_authorization"
      # Test if the auth passes validation
      if !(m["body"] =~ authVal)
        tagStats[:authSkipped] += 1
        Log.warn { "SKIPPING_AUTH: auth validation failed in file #{CFG_FILE} of:\n#{md}\n#{{"authVal", authVal}}" }

        # Test if more than one auth has been found
      elsif auth.has_key?(:secret)
        tagStats[:authSkipped] += 1
        Log.warn { "Only the first authorization found in file #{CFG_FILE} will be used" }

        # Add a successfully parsed auth
      else
        tagStats[:authAdded] += 1
        auth[:name] = m["body"].split('=')[0].strip
        auth[:type] = m["body"].split('=')[1].strip.split[0]
        auth[:secret] = m["body"].split('=')[1].strip.split[1]
        Log.debug { "Authorization token found in file #{CFG_FILE} of: \n#{auth}" }
      end
      # Process status config blocks
    when "githubstatus"
      keys = [] of String
      values = [] of String

      # Extract keys and values from the body of the tag
      m["body"].split('\n').each do |record|
        a = record.split('=').map(&.strip).to_a
        keys << a[0]
        values << a[1]
      end

      # TODO: Test for and add optional elements

      # Test that the number of expected keys are present
      if keys.uniq.size != notifyVal.size
        tagStats[:jobSkipped] += 1
        Log.warn { "SKIPPING_NOTIFY_JOB: expected #{notifyVal.size} unique keys, but found #{keys.uniq.size} in file #{CFG_FILE} of:\n#{md}" }

        # Test that the expected key names are present
      elsif keys.reduce(false) { |acc, i| acc || !notifyVal.has_key?(i) }
        tagStats[:jobSkipped] += 1
        Log.warn { "SKIPPING_NOTIFY_JOB: expected keys of #{notifyVal.keys} were not all found in file #{CFG_FILE} of:\n#{md}" }

        # Test validation regex for each key value
      elsif Hash.zip(keys, values).reduce(false) { |acc, (k, v)| acc || !(v =~ notifyVal[k]) }
        tagStats[:jobSkipped] += 1
        Log.warn { "SKIPPING_NOTIFY_JOB: at least one value validation failed in file #{CFG_FILE} of:\n#{md}\n#{notifyVal}" }

        # Add a successfully parsed notify job
      else
        tagStats[:jobAdded] += 1
        notifyJobs << Hash.zip(keys, values)
      end
    else
      tagStats[:unknown] += 1
      Log.info { "Unknown config tag in file #{CFG_FILE} of:\n#{md}" }
    end
  end

  # Raise if no authorization was found
  unless auth.has_key?(:secret)
    msg = "No authorization was found in file #{CFG_FILE}"
    Log.error { msg }
    raise msg
  end

  # Summarize the parsed config
  Log.info { "Config parse of #{CFG_FILE} successful:\n#{tagStats}" }

  # Return vals
  return auth, notifyJobs
end

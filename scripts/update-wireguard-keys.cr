#!/usr/bin/env nix-shell
#!nix-shell -p wireguard crystal -i crystal

keydir = "secrets/wireguard"

needed = `nix eval --raw '((import ./scripts/nodes.nix).allStrings)'`.split(" ")
existing = Dir["#{keydir}/*.ip"].map{|f| File.basename(f, ".ip") }

ips = needed.each.with_index.map{|(_, i)|
  i += 1
  "10.90.#{i / 256}.#{i % 256}"
}.to_a

used_ips = existing.map { |ex| File.read("#{keydir}/#{ex}.ip").strip }
ips -= used_ips

(needed - existing).each do |node|
  ip = ips.shift
  pp!({ node => ip})
  `wg genkey | tee "#{keydir}/#{node}.private" | wg pubkey > "#{keydir}/#{node}.public"`
  File.write("#{keydir}/#{node}.ip", ip)
end

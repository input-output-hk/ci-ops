libvirtd: static/graylog-creds.nix
	exec ./scripts/create-libvirtd.sh
.PHONY: libvirtd

aws: static/graylog-creds.nix
	exec ./scripts/create-aws.sh
.PHONY: aws

static:
	exec ./scripts/static.sh

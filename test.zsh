#!/bin/zsh
set -eu
source "${0:A:h}/company-direct"
required=(example.com '*.example.com' devops.example.com '*.devops.example.com')
existing=$'localhost\n*.local\ncustom.example\nexample.com'
merged=$(merge_rules "$existing")
[[ "$(merge_rules '')" == $'example.com\n*.example.com\ndevops.example.com\n*.devops.example.com' ]]
has_rules "$merged"
[[ "$merged" == "$existing"$'\n*.example.com\ndevops.example.com\n*.devops.example.com' ]]
[[ "$(merge_rules "$merged")" == "$merged" ]]
! has_rules $'localhost\nexample.com'
print $'Enabled: Yes\nServer: 127.0.0.1\nPort: 10080' | is_panda_proxy
! print $'Enabled: No\nServer: 127.0.0.1\nPort: 10080' | is_panda_proxy
! print $'Enabled: Yes\nServer: 10.1.2.3\nPort: 10080' | is_panda_proxy
! print $'Enabled: Yes\nServer: 127.0.0.1\nPort: 7890' | is_panda_proxy
print 'PASS: preserves custom exceptions, adds missing domains, idempotent, ignores disabled/foreign proxies.'
active_panda_proxy $'HTTPEnable : 1\nHTTPProxy : 127.0.0.1\nHTTPPort : 10080'
! active_panda_proxy $'HTTPEnable : 0\nHTTPProxy : 127.0.0.1\nHTTPPort : 10080'
! active_panda_proxy $'HTTPEnable : 1\nHTTPProxy : 127.0.0.1\nHTTPPort : 7890'
print 'PASS: active system proxy must match PandaFan configuration.'
fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT
cat > "$fixture" <<'EOF'
version=1
host=localhost
port=12345
interval=30
watch=0
domain=example.com
domain=*.example.com
EOF
load_config "$fixture"
[[ "$proxy_host" == localhost && "$proxy_port" == 12345 && "$check_interval" == 30 && "$watch_changes" == 0 ]]
[[ "${(j:,:)required}" == 'example.com,*.example.com' ]]
print $'Enabled: Yes\nServer: localhost\nPort: 12345' | is_panda_proxy
! print $'Enabled: Yes\nServer: 127.0.0.1\nPort: 10080' | is_panda_proxy
print 'domain=$(touch /tmp/company-direct-must-not-execute)' >> "$fixture"
! load_config "$fixture"
print 'PASS: configurable matching and data-only rejection of shell content.'

print $'version=1\nhost=127.0.0.1\nport=10080\ninterval=10\nwatch=1' > "$fixture"
load_config "$fixture"
[[ ${#required} == 0 ]]
# Empty configuration must return before touching network or process APIs.
reconcile check
print "PASS: empty first-run configuration is a no-op."

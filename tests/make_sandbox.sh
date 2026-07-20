#!/usr/bin/env bash
# Creates a throwaway sandbox repo for supervised ralph plugin smoke tests.
set -euo pipefail
DIR="${1:-/tmp/ralph-sandbox}"
rm -rf "$DIR"
mkdir -p "$DIR/specs"
cd "$DIR"
git init -q -b main

cat > greeting.sh <<'EOF'
#!/usr/bin/env bash
# Prints a greeting. Tasks in specs/sandbox.json extend this file.
echo "hello"
EOF
chmod +x greeting.sh

cat > verify.sh <<'EOF'
#!/usr/bin/env bash
# Verification: greeting.sh must support default and --shout modes as tasks complete.
set -euo pipefail
[[ "$(./greeting.sh)" == "hello" ]] || { echo "FAIL: default greeting"; exit 1; }
if grep -q 'shout' greeting.sh 2>/dev/null; then
    [[ "$(./greeting.sh --shout)" == "HELLO" ]] || { echo "FAIL: shout mode"; exit 1; }
fi
echo "verify OK"
EOF
chmod +x verify.sh

cat > specs/sandbox.json <<'EOF'
{
  "project": "Sandbox greeting",
  "context": {
    "currentState": "greeting.sh prints hello",
    "targetState": "greeting.sh supports --shout and --name flags",
    "constraints": ["bash only", "no new files except tests"],
    "verificationCommands": ["./verify.sh"]
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "Add --shout flag",
      "description": "greeting.sh --shout prints HELLO (uppercase).",
      "acceptanceCriteria": ["./greeting.sh --shout outputs HELLO", "./greeting.sh still outputs hello"],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    },
    {
      "id": "T-002",
      "title": "Add --name flag",
      "description": "greeting.sh --name X prints hello X. Combined with --shout prints HELLO X.",
      "acceptanceCriteria": ["./greeting.sh --name Sam outputs 'hello Sam'"],
      "dependsOn": ["T-001"],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    }
  ]
}
EOF

git add -A && git commit -qm "init: sandbox project with 2-task spec"
echo "$DIR"

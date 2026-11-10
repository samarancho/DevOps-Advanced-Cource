#!/usr/bin/env bash
# ВМ для GitLab Runner. Docker и gitlab-runner ставим на занятии 09 вручную.
set -euo pipefail

cat > /etc/motd <<'EOF'

  DevOps продвинутый курс — ВМ gitlab-runner
  Здесь на занятии 09 устанавливаются Docker и GitLab Runner.

EOF
echo ">>> [runner] готово"

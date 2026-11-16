# Fresh user environment for end-to-end testing of forloop-skills.
#
# Deliberately does NOT preinstall the ForLoop CLI or the skill: the E2E run
# starts from a clean machine and does what a real user would do.
FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     git jq curl ca-certificates procps \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tester

USER tester
WORKDIR /home/tester

# User-local npm prefix (same pattern as a typical dev machine; no sudo).
RUN mkdir -p /home/tester/.npm-global /home/tester/project \
  && npm config set prefix /home/tester/.npm-global
ENV PATH="/home/tester/.npm-global/bin:${PATH}"

COPY --chown=tester:tester e2e.sh /opt/e2e/e2e.sh
RUN chmod +x /opt/e2e/e2e.sh

CMD ["bash"]

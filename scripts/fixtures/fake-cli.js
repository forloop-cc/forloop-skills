#!/usr/bin/env node
// Minimal stand-in for the forloop CLI bundle. verify.sh only greps strings:
// registered command keys look like  "<key>": createSomethingCommand(),
// alias registrations look like  "<key>": someIdentifierCmd,
// flags look like  "--flag".
// Keep this in sync with the patterns verify.sh greps for.
var commands = {
  "auth login": createCmd(),
  "auth status": createCmd(),
  "space-sprint get": createCmd(),
  "space-sprint list": createCmd(),
  "space-sprint sub-sprint list": createCmd(),
  "story create": createCmd(),
  "story get": createCmd(),
  "sync aivy-folder": createCmd(),
  "sync aivy-doc-get": createCmd(),
  "sync s3-to-local": createCmd(),
  "sync local-to-s3": createCmd(),
  "file upload": createCmd(),
  "file list": createCmd(),
  "file download": createCmd(),
  "agent developer-space-sprint": createCmd(),
  "agent developer-status": createCmd(),
  "agent history": createCmd(),
  "org list": createCmd(),
  "user profile": createCmd(),
};
// Alias registrations reuse another command implementation (no parentheses).
var aliases = {
  "agent status": agentDeveloperStatusCmd,
  "space-sprint show": sprintGetCmd,
};
// Flags used by the fixtures below.
var flags = ["--output", "--non-interactive", "--sprint", "--id", "--path", "--folder", "--story-id", "--limit", "--message", "--confirm", "--title"];

function createCmd() { return {}; }
function agentDeveloperStatusCmd() { return {}; }
function sprintGetCmd() { return {}; }
if (process.argv.includes("--version")) { console.log("forloop 0.0.0-fake"); }

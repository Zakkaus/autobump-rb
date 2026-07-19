# frozen_string_literal: true
require 'shellwords'
module Autobump
  # Resolve a bump issue (nvchecker) to (pkg, newver) from its "[nvchecker] cat/pkg can
  # be bump to X" title.
  class Issue
    def self.resolve(cfg, issue)
      # shellescape both interpolations; the only user-derived value here is the issue
      # token, and cli tightens it to bare digits before we ever get here.
      title = `gh issue view #{issue.to_s.shellescape} --repo #{cfg.upstream_repo.shellescape} --json title --jq .title 2>/dev/null`.strip
      raise "cannot read issue ##{issue}" if title.empty?
      pkg = title[%r{^\[nvchecker\] ([a-z0-9-]+/[A-Za-z0-9_+-]+) can be bump to }, 1]
      # version class includes '+' (build metadata, e.g. 1.0+r1) to match the pkg class
      ver = title[/ can be bump to ([A-Za-z0-9._+-]+)$/, 1]
      raise "cannot parse issue title: #{title}" unless pkg && ver
      [pkg, ver]
    end
  end
end

# frozen_string_literal: true
require 'fileutils'
module Autobump
  # Stage 4: fetch old artifacts, create the new ebuild, fetch + manifest.
  # A fetch/mirror failure is transient -> Abort (exit 2) so the sweep retries,
  # not Escalate.
  class Distfiles
    def initialize(ctx) = (@c = ctx)
    def run
      c = @c; cfg = c.cfg
      Dir.chdir(c.pkgdir) do
        old = File.basename(c.old_ebuild); neweb = File.basename(c.new_ebuild)
        _, ok = c.sh('ebuild', old, 'fetch', sudo: true, timeout: cfg.op_timeout)
        unless ok
          # OLD distfile only feeds the tree/surface diff. An upstream that keeps only its
          # latest release (+ RESTRICT=mirror) 404s on the old one -- don't defer the whole
          # bump for that. Flag it: the diff stage skips, and the new fetch (the manifest
          # below) + the emerge build gate + a PR flagged "no diff" for human review still
          # vouch for the new version.
          Log.log 'OLD distfile unavailable (upstream keeps only latest?); tree/surface diff skipped, relying on the build gate + PR review'
          c.old_distfile_missing = true
        end
        # bash's cp is unchecked: on failure the new ebuild is absent and the next
        # manifest fails -> Abort. Swallow SystemCallError so it does not surface as
        # an uncaught exit 1 that skips cleanup and orphans the branch.
        begin
          FileUtils.cp(old, neweb)
        rescue SystemCallError => e
          raise Abort, "could not create new ebuild: #{e.message}"
        end
        out, ok = c.sh('ebuild', neweb, 'manifest', sudo: true, timeout: cfg.op_timeout)
        c.evidence.write('fetch.log', out)
        unless ok
          puts out.lines.last(5).join
          raise Abort, "fetch/manifest for #{c.newver} failed (missing upstream file or slow mirror)"
        end
        system(*[cfg.sudo, 'chown', "#{`id -un`.strip}:#{`id -gn`.strip}", 'Manifest'].reject { |x| x.nil? || x.empty? })
      end
      Log.ok 'distfiles fetched, Manifest regenerated'
    end
  end
end

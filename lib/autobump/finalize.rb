# frozen_string_literal: true
require 'shellwords'
module Autobump
  # Stage 7: finalize + QA + commit. Drop the old ebuild, regen the Manifest, gate on
  # the pkgcheck findings the bump INTRODUCED (baseline subtracted), commit with the bot
  # identity, then a net pkgcheck with URL recheck. git/pkgdev calls use array form (no
  # shell), so paths need no quoting.
  class Finalize
    def initialize(ctx) = (@c = ctx)

    # baseline (preflight) and after (here) MUST use the identical cwd + pipeline so
    # the later `comm -13` compares like with like: both run in $REPO with the same
    # `sed | sort -u`, so only findings the bump introduced survive the subtraction.
    def self.pkgcheck_scan(repo, pkg)
      Dir.chdir(repo) do
        `pkgcheck scan #{pkg.shellescape} 2>/dev/null | sed -E 's/version [^:]+: //' | sort -u`
      end
    end

    def run
      c = @c; cfg = c.cfg; repo = cfg.repo; nul = File::NULL
      # bash removes the smoke accept_keywords file at stage-7 top unconditionally
      # (632); mirror that so a successful bump does not leak one file per run.
      system(*[cfg.sudo, 'rm', '-f', "/etc/portage/package.accept_keywords/autobump-#{c.pn}"]
               .reject { |x| x.nil? || x.empty? }, err: nul)
      system('git', '-C', repo, 'rm', '-q', c.old_ebuild)
      # drop the removed version's DIST entries (distfiles all local, no refetch).
      # capture the output so a failure carries the reason (the judge/sweep sees why).
      mout = Dir.chdir(c.pkgdir) { IO.popen(['pkgdev', 'manifest'], err: %i[child out], &:read) }
      raise Abort, "manifest regen after drop failed: #{mout.strip.lines.last(6).join.strip}" unless $?.success?
      system('git', '-C', repo, 'add', c.pkgdir)
      c.evidence.write('pkgcheck-after.txt', Finalize.pkgcheck_scan(repo, c.pkg))
      base = c.evidence.path('pkgcheck-baseline.txt'); after = c.evidence.path('pkgcheck-after.txt')
      new = `comm -13 #{base.shellescape} #{after.shellescape}`
      c.evidence.write('pkgcheck-new.txt', new)
      unless new.strip.empty?
        puts new
        raise Escalate.new('pkgcheck findings introduced by the bump', c.evidence.dir)
      end
      env = {}
      if cfg.bot_email && !cfg.bot_email.empty?
        name = cfg.bot_name || 'gentoo-zh autobump'
        env = { 'GIT_AUTHOR_NAME' => name, 'GIT_AUTHOR_EMAIL' => cfg.bot_email,
                'GIT_COMMITTER_NAME' => name, 'GIT_COMMITTER_EMAIL' => cfg.bot_email }
      end
      committed = Dir.chdir(repo) { system(env, 'pkgdev', 'commit', '--scan', 'false', '--signoff') }
      raise Abort, 'pkgdev commit failed' unless committed
      c.armed = false # commit is made; an interrupt now must NOT discard it
      Log.ok "committed: #{`git -C #{repo.shellescape} log -1 --format=%s`.strip}"
      dead_url_recheck
    end

    private

    def dead_url_recheck
      c = @c; repo = c.cfg.repo
      net = Dir.chdir(repo) { `pkgcheck scan --commits --net 2>&1`.scrub }
      c.evidence.write('pkgcheck-net.txt', net)
      flagged = net.lines.select { |l| l =~ /DeadUrl|RedirectedUrl/ && l.include?(c.pn) }
      return if flagged.empty?
      # re-verify only the URLs in the PN-context window (bash: `grep -A1 "$PN"`), not
      # the whole scan, so an unrelated DeadUrl elsewhere can't force a false escalate.
      lines = net.lines
      window = +''
      lines.each_index { |i| window << lines[i] << (lines[i + 1] || '') if lines[i].include?(c.pn) }
      urls = window.scan(%r{https://[^ \r\n]+}).uniq
      # array-form curl: a URL with '&' (query strings) must not be split by the shell
      recheck = urls.map do |u|
        code = IO.popen(['curl', '-sL', '--max-time', '20', '-o', '/dev/null', '-w', '%{http_code}', u], &:read).strip
        code = '000' if code.empty? # curl couldn't connect at all -> network-inconclusive marker
        "#{u} -> #{code}"
      end
      c.evidence.write('url-recheck.txt', recheck.join("\n") + "\n")
      bad = recheck.reject { |l| l.end_with?(' -> 200') }
      return Log.log('pkgcheck URL findings were transient (all URLs 200 on recheck)') if bad.empty?
      puts bad.join("\n")
      # a 000/timeout/5xx is network-inconclusive, not a confirmed dead URL: defer (retry next
      # sweep) rather than permanently escalate a bump that already built + committed clean, on
      # a mirror/CDN blip. Only a stable 4xx is a real DeadUrl -> escalate.
      raise Abort, 'URL recheck inconclusive (network/5xx); deferring' if bad.all? { |l| l =~ %r{ -> (000|5[0-9][0-9])\z} }
      raise Escalate.new('URL findings persist after recheck', c.evidence.dir)
    end
  end
end

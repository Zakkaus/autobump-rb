#!/usr/bin/env ruby
# frozen_string_literal: true
# Test the heavy-dependency pre-check parser (BuildTest.heavy_in_plan): given an
# `emerge --pretend` plan, it must flag HEAVY packages that would build from source, ignore
# binpkg lines and the bump target itself. Hermetic -- no portage. Run: ruby test/heavy_dep.rb
require_relative '../lib/autobump'

$fail = 0
def check(name, got, want)
  if got.sort == want.sort
    puts "ok   #{name}"
  else
    $fail += 1
    puts "FAIL #{name}\n       got  #{got.inspect}\n       want #{want.inspect}"
  end
end

H = Autobump::BuildTest

# qtwebengine + rust build from source -> flagged; webkit-gtk is a binpkg -> ignored;
# the target (net-misc/reqable) builds from source but is the bump itself -> ignored.
plan = <<~PLAN
  [ebuild  N     ] dev-qt/qtwebengine-6.9.0::gentoo  USE="widgets"
  [binary  N     ] net-libs/webkit-gtk-2.46.0::gentoo
  [ebuild  N     ] dev-libs/small-lib-1.0::gentoo
  [ebuild  N     ] net-misc/reqable-2.0::gentoo-zh
  [ebuild  U     ] dev-lang/rust-1.83::gentoo
PLAN
check 'source-built heavy deps flagged, binpkg + target ignored',
      H.heavy_in_plan(plan, 'reqable', '2.0'), ['dev-qt/qtwebengine', 'dev-lang/rust']

# everything from binpkg -> nothing to flag
allbin = <<~PLAN
  [binary  N     ] dev-qt/qtwebengine-6.9.0::gentoo
  [binary  N     ] net-libs/webkit-gtk-2.46.0::gentoo
  [ebuild  N     ] www-apps/folo-bin-1.2::gentoo-zh
PLAN
check 'all deps from binpkg -> empty', H.heavy_in_plan(allbin, 'folo-bin', '1.2'), []

# a heavy target being bumped is not flagged as its own dependency
selfheavy = <<~PLAN
  [ebuild  U     ] dev-qt/qtwebengine-6.9.1::gentoo
PLAN
check 'heavy TARGET itself not flagged', H.heavy_in_plan(selfheavy, 'qtwebengine', '6.9.1'), []

# empty plan (pretend failed) -> empty, no false defer
check 'empty plan -> empty', H.heavy_in_plan('', 'x', '1'), []

puts '----'
puts "heavy_dep: #{$fail.zero? ? 'all passed' : "#{$fail} failed"}"
exit($fail.zero? ? 0 : 1)

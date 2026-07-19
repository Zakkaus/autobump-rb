# frozen_string_literal: true
require 'tmpdir'
module Autobump
  # The evidence pack: a temp dir the engine fills with the facts a judge
  # (cheap LLM or human) reads to decide an escalation.
  class Evidence
    attr_reader :dir
    def initialize(pn)
      @dir = Dir.mktmpdir("autobump-#{pn}-")
    end
    def write(name, content) = File.write(File.join(@dir, name), content)
    def path(name) = File.join(@dir, name)
  end
end

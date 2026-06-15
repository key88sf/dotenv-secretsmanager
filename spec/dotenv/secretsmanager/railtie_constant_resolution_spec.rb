# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "shellwords"

# Regression test for constant-resolution shadowing.
#
# The railtie is defined inside `module Dotenv`. The dotenv-rails gem defines a
# `Dotenv::Rails` module, so a bare `Rails` constant inside the railtie resolves
# to `Dotenv::Rails` instead of the top-level `Rails`, and `Rails::Railtie`
# becomes the nonexistent `Dotenv::Rails::Railtie`.
#
# This loads the railtie in a fresh subprocess that mimics a real Rails boot:
# a top-level `Rails::Railtie` plus a `Dotenv::Rails` module (as dotenv-rails
# defines it, with no `Railtie` under it). A subprocess is used so the load
# happens against pristine constants, immune to other specs that stub Rails.
RSpec.describe "Railtie loads under a real dotenv-rails" do
  it "subclasses the top-level Rails::Railtie, not Dotenv::Rails::Railtie" do
    lib = File.expand_path("../../../lib", __dir__)
    script = <<~RUBY
      # Top-level Rails::Railtie, as real Rails provides it.
      module Rails
        class Railtie
          def self.config
            @config ||= Object.new.tap do |o|
              def o.before_configuration(&blk); end
            end
          end
        end
      end

      # Dotenv::Rails, as the dotenv-rails gem provides it (note: no Railtie).
      module Dotenv
        module Rails; end
      end

      $LOAD_PATH.unshift(#{lib.inspect})
      require "dotenv/secretsmanager/railtie"

      unless Dotenv::SecretsManager::Railtie.superclass.equal?(Rails::Railtie)
        abort "subclassed the wrong Railtie"
      end
      print "OK"
    RUBY

    output = `#{RbConfig.ruby.shellescape} -e #{script.shellescape} 2>&1`
    expect($?.success?).to be(true), "subprocess failed: #{output}"
    expect(output).to eq("OK")
  end
end

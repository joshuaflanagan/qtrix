require 'spec_helper'
require 'stringio'
require 'qtrix/cli'

shared_context "cli commands" do
  let(:stdout_stream) {StringIO.new}
  let(:stderr_stream) {StringIO.new}

  def stdout
    stdout_stream.rewind
    stdout_stream.read
  end

  def stderr
    stderr_stream.rewind
    stderr_stream.read
  end
end

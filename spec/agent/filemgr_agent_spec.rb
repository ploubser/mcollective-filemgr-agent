#!/usr/bin/env rspec

require 'spec_helper'
require File.join(File.dirname(__FILE__), "../../", "agent", "filemgr.rb")

module MCollective
  module Agent
    describe Filemgr do
      before do
        agent_file = File.join([File.dirname(__FILE__), "../../", "agent", "filemgr.rb"])
        @agent = MCollective::Test::LocalAgentTest.new("filemgr", :agent_file => agent_file).plugin
      end

      describe "#touch" do
        it "should touch the file when a name is supplied" do
          FileUtils.expects(:touch).with("/tmp/foo")
          @agent.call(:touch, :file => "/tmp/foo")
        end

        it "should touch the file specified in config" do
          pluginconf = mock
          pluginconf.stubs(:pluginconf).returns({"filemgr.touch_file" => "/tmp/foo2"})
          @agent.stubs(:config).returns(pluginconf)

          FileUtils.expects(:touch).with("/tmp/foo2")
          @agent.call(:touch, :file => nil)
        end

        it "should touch the default file if its neither supplied or in conf" do
          FileUtils.expects(:touch).with("/var/run/mcollective.plugin.filemgr.touch")
          @agent.call(:touch, :file => nil)
        end

        it "should reply with a failure message if the file cannot be touched" do
          FileUtils.expects(:touch).raises("error")
          result = @agent.call(:touch, :file => nil)
          result.should be_aborted_error
        end
      end

      describe "remove" do
        it "should not try to remove a file that isn't present" do
          File.expects(:exists?).with("/tmp/foo").returns(false)
          result = @agent.call(:remove, :file => "/tmp/foo")
          result.should be_aborted_error
        end

        it "should fail if it can't remove the file" do
          File.expects(:exists?).with("/tmp/foo").returns(true)
          FileUtils.expects(:rm).raises("error")
          result = @agent.call(:remove, :file => "/tmp/foo")
          result.should be_aborted_error
        end

        it "should remove a file" do
          File.expects(:exists?).with("/tmp/foo").returns(true)
          FileUtils.expects(:rm)
          result = @agent.call(:remove, :file => "/tmp/foo")
          result.should be_successful
        end
      end

      describe "list" do
        it "should fail if it cannot read the directory" do
          File.stubs(:exists?).with("/tmp/rspec").returns(false)
          result = @agent.call(:list, :dir => "/tmp/rspec")
          result.should be_aborted_error
        end

        it "should fail if the target isn't a directory" do
          File.stubs(:exists?).with("/tmp/rspec").returns(true)
          File.stubs(:directory?).with("/tmp/rspec").returns(false)
          result = @agent.call(:list, :dir => "/tmp/rspec")
          result.should be_aborted_error
        end

        it "should return the list of files in the directory as an array" do
          File.stubs(:exists?).with("/tmp/rspec").returns(true)
          File.stubs(:directory?).with("/tmp/rspec").returns(true)
          Dir.stubs(:glob).with("/tmp/rspec/*").returns(["/tmp/rspec/file.1", "/tmp/rspec/file.2"])
          result = @agent.call(:list, :dir => "/tmp/rspec")
          result.should be_successful
          result.should have_data_items(:files => ["/tmp/rspec/file.1", "/tmp/rspec/file.2"])
        end

        it "should return a array of hashes containing detailed file information if 'details' is set" do
          stats1 = {:name => "file.1", :output => "present", :mode => "600"}
          stats2 = {:name => "file.2", :output => "present", :mode => "700"}
          File.stubs(:exists?).with("/tmp/rspec").returns(true)
          File.stubs(:directory?).with("/tmp/rspec").returns(true)
          Dir.stubs(:glob).with("/tmp/rspec/*").returns(["/tmp/rspec/file.1", "/tmp/rspec/file.2"])
          @agent.expects(:status).with("/tmp/rspec/file.1").returns(stats1)
          @agent.expects(:status).with("/tmp/rspec/file.2").returns(stats2)
          result = @agent.call(:list, {:dir => "/tmp/rspec", :details => true})
          result.should be_successful
          result.should have_data_items(:files => [{"/tmp/rspec/file.1" => stats1}, {"/tmp/rspec/file.2" => stats2}])
        end
      end

      describe "status" do
        it "should fail if the file isn't present" do
          File.expects(:exists?).with("/tmp/foo").returns(false)
          result = @agent.call(:status, :file => "/tmp/foo")
          result.should be_aborted_error
        end

        it "should return the default values if the file if present but cannot be read" do
          File.expects(:exists?).with("/tmp/foo").returns(true)
          File.expects(:readable?).with("/tmp/foo").returns(false)

          result = @agent.call(:status, :file => "/tmp/foo")
          result.should be_successful
          result.should have_data_items(:output => "you do not have permission to read this file",
                                        :name => "/tmp/foo",
                                        :type => "unknown",
                                        :mode => "0000",
                                        :present => 1,
                                        :size => 0,
                                        :mtime => 0,
                                        :ctime => 0,
                                        :atime => 0,
                                        :mtime_seconds => 0,
                                        :ctime_seconds => 0,
                                        :atime_seconds => 0,
                                        :md5 => 0,
                                        :uid => 0,
                                        :gid => 0)
        end

        it "should return the file status" do
          stat = mock

          File.expects(:exists?).with("/tmp/foo").returns(true)
          File.expects(:readable?).with("/tmp/foo").returns(true)
          File.expects(:symlink?).returns(false)
          File.expects(:stat).with("/tmp/foo").returns(stat)
          File.stubs(:read).returns("")
          stat.expects(:size).returns(123)
          stat.expects(:mtime).returns(123).twice
          stat.expects(:ctime).returns(123).twice
          stat.expects(:atime).returns(123).twice
          stat.expects(:uid).returns(500)
          stat.expects(:gid).returns(500)
          stat.expects(:mode).returns(511)
          stat.stubs(:file?).returns(true)
          Digest::MD5.expects(:hexdigest).returns("AB12")
          stat.stubs(:directory?).returns(false)
          stat.stubs(:symlink?).returns(false)
          stat.stubs(:socket?).returns(false)
          stat.stubs(:chardev?).returns(false)
          stat.stubs(:blockdev?).returns(false)

          result = @agent.call(:status, :file => "/tmp/foo")
          result.should be_successful
          result.should have_data_items(:output => "present",
                                        :present => 1,
                                        :size => 123,
                                        :mtime => 123,
                                        :ctime => 123,
                                        :atime => 123,
                                        :uid => 500,
                                        :gid => 500,
                                        :mtime_seconds => 123,
                                        :ctime_seconds => 123,
                                        :atime_seconds => 123,
                                        :mode => "777",
                                        :md5 => "AB12",
                                        :type => "file")
        end
      end
    end
  end
end

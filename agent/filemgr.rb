require 'fileutils'
require 'digest/md5'

module MCollective
  module Agent
    # A basic file management agent, you can touch, remove or inspec files.
    #
    # A common use case for this plugin is to test your mcollective setup
    # as such if you just call the touch/info/remove actions with no arguments
    # it will default to the file /var/run/mcollective.plugin.filemgr.touch
    # or whatever is specified in the plugin.filemgr.touch_file setting
    class Filemgr<RPC::Agent
      action "touch" do
        touch
      end

      # Basic file removal action
      action "remove" do
        remove
      end

      # List the contents of a directory
      action "list" do
        list
      end

      # Basic status of a file
      action "status" do
        stats = status(request[:file])

        stats.keys.each do |k|
          reply[k] = stats[k]
        end
      end

      def list
        reply.fail!("Could not read directory. Directory does not exist.") unless File.exists?(request[:dir])
        reply.fail!("Could not read directory. '%s' is not a directory" % request[:dir]) unless File.directory?(request[:dir])

        files = Dir.glob(File.join(request[:dir], "*"))

        unless request[:details]
          reply[:files] = files
        else
          reply[:files] = []
          files.each do |f|
            reply[:files] << {f => status(f)}
          end
        end
      end

      def get_filename(file)
        file || config.pluginconf["filemgr.touch_file"] || "/var/run/mcollective.plugin.filemgr.touch"
      end

      def status(file)
        file = get_filename(file)
        stats = {}
        stats[:name] = file
        stats[:output] = "not present"
        stats[:type] = "unknown"
        stats[:mode] = "0000"
        stats[:present] = 0
        stats[:size] = 0
        stats[:mtime] = 0
        stats[:ctime] = 0
        stats[:atime] = 0
        stats[:mtime_seconds] = 0
        stats[:ctime_seconds] = 0
        stats[:atime_seconds] = 0
        stats[:md5] = 0
        stats[:uid] = 0
        stats[:gid] = 0


        if File.exists?(file)
          Log.debug("Asked for status of '#{file}' - it is present")
          stats[:output] = "present"
          stats[:present] = 1

          unless File.readable?(file)
            stats[:output] = "you do not have permission to read this file"
            return stats
          end

          if File.symlink?(file)
            stat = File.lstat(file)
          else
            stat = File.stat(file)
          end

          [:size, :mtime, :ctime, :atime, :uid, :gid].each do |item|
            stats[item] = stat.send(item)
          end

          [:mtime, :ctime, :atime].each do |item|
            stats["#{item}_seconds".to_sym] = stat.send(item).to_i
          end

          stats[:mode] = "%o" % [stat.mode]
          stats[:md5] = Digest::MD5.hexdigest(File.read(file)) if stat.file?

          stats[:type] = "directory" if stat.directory?
          stats[:type] = "file" if stat.file?
          stats[:type] = "symlink" if stat.symlink?
          stats[:type] = "socket" if stat.socket?
          stats[:type] = "chardev" if stat.chardev?
          stats[:type] = "blockdev" if stat.blockdev?
        else
          Log.debug("Asked for status of '#{file}' - it is not present")
          reply.fail! "#{file} does not exist"
        end

        stats
      end

      def remove
        file = get_filename(request[:file])

        unless File.exists?(file)
          Log.debug("Asked to remove file '#{file}', but it does not exist")
          reply.fail! "Could not remove file '#{file}' - it is not present"
        else
          begin
            FileUtils.rm(file)
            Log.debug("Removed file '#{file}'")
            reply.statusmsg = "OK"
          rescue Exception => e
            Log.warn("Could not remove file '#{file}': #{e.class}: #{e}")
            reply.fail! "Could not remove file '#{file}': #{e.class}: #{e}"
          end
        end
      end

      def touch
        file = get_filename(request[:file])

        begin
          FileUtils.touch(file)
          Log.debug("Touched file '#{file}'")
        rescue Exception => e
          Log.warn("Could not touch file '#{file}': #{e.class}: #{e}")
          reply.fail! "Could not touch file '#{file}': #{e.class}: #{e}"
        end
      end
    end
  end
end


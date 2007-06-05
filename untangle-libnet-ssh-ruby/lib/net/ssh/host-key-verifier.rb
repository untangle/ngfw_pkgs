require 'net/ssh/errors'

module Net
  module SSH

    class HostKeyVerifier
      def verify(arguments)
        # first, find any matches on hostname+port
        matches = keys.select do |item|
            host = item[:host] || arguments[:peer][:host]
            ip   = item[:ip]   || arguments[:peer][:ip]
            port = item[:port] || arguments[:peer][:port]

            host == arguments[:peer][:host] &&
            ip   == arguments[:peer][:ip]   &&
            port == arguments[:peer][:port]
          end

        # we've never seen this host before, so just automatically add the key.
        # not the most secure option (since the first hit might be the one that
        # is hacked), but since almost nobody actually compares the key
        # fingerprint, this is a reasonable compromise between usability and
        # security.
        if matches.empty?
          add_key(arguments)
          return true
        end

        # If we found any matches, check to see that the key type and
        # blob also match.
        found = matches.any? do |item|
            item[:type] == arguments[:key].ssh_type &&
            item[:key]  == arguments[:key_blob]
          end

        # If a match was found, return true. Otherwise, raise an exception
        # indicating that the key was not recognized.
        found || process_cache_miss(arguments)
      end

      private

        def process_cache_miss(args)
          exception = HostKeyMismatch.new("fingerprint #{args[:fingerprint]} does not match for #{args[:peer][:host]}")
          exception.data = args
          exception.callback = Proc.new { add_key(args) }
          raise exception
        end

        def home_directory
          ENV['HOME'] ||
            (ENV['HOMEPATH'] && "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}") ||
            "/"
        end

        def user_key_file
          @user_key_file ||= "#{home_directory}/.ssh/known_hosts"
        end

        def add_key(args)
          keys << { :host => args[:peer][:host], :port => args[:peer][:port], :ip => args[:peer][:ip], :type => args[:key].ssh_type, :key => args[:key_blob] }

          key_directory = File.dirname(user_key_file)
          Dir.mkdir(key_directory, 0700) if !File.exists?(key_directory)

          File.open(user_key_file, "a") do |f|
            host = args[:peer][:host]
            host = "[#{host}]:#{args[:peer][:port]}" if host && args[:peer][:port] != 22

            ip = args[:peer][:ip]
            ip = nil if ip == "127.0.0.1" || ip == "::1"

            host = [host, ip].compact.join(",")
            f.puts "%s %s %s" % [host, args[:key].ssh_type, [args[:key_blob]].pack("m*").gsub(/\s/, "")]
          end
        end

        def keys
          @keys ||= begin
            list = []
            list.concat(load_keys_from(user_key_file)) if File.exist?(user_key_file)
            list
          end
        end

        def load_keys_from(path)
          File.readlines(path).map do |line|
            host, type, key = line.chomp.split
            host, address = host.split(/,/)

            if address.nil? && host =~ /^\d+\.\d+\.\d+\.\d+$/
              host, address = address, host
            end

            if host
              host, port = host.split(/:/, 2)
              host = host.gsub(/[\[\]]/, "")
            end

            key = key.unpack("m*").first
            
            { :host => host, :ip => address, :port => port, :type => type, :key => key }
          end
        end
    end

  end
end
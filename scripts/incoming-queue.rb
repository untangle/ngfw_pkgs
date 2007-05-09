#! /usr/bin/ruby

require 'net/smtp'

DEFAULT_DISTRIBUTION = "mustang"
DEFAULT_MAIL_RECIPIENTS = [ "rbscott@untangle.com", "seb@untangle.com" ]

REP = "/var/www/untangle"
INCOMING = "#{REP}/incoming"
PROCESSED = "#{REP}/processed"

def email(recipients, subject, body)
  recipientsString = recipients.join(',')
  recipients.each { |r|
    r.gsub!(/.*?<(.*)>/, '\1')
  }
  myMessage = <<EOM
From: Incoming Queue Daemon <seb@untangle.com>
To: #{recipientsString}
Subject: #{subject}

#{body}
EOM

  Net::SMTP.start('localhost', 25, 'localhost.localdomain') { |smtp|
    smtp.send_message(myMessage,"seb@untangle.com",*recipients)
  }
end

class DebianUpload

  attr_reader :files, :distribution, :uploader, :version

  def initialize(file)
    @file = file
    @files = [ @file ]
  end

  def to_s
    s = "#{@file}\n"
    s += "  distribution = #{@distribution}\n"
    s += "  maintainer = #{@maintainer}\n"
    s += "  uploader = #{@uploader}\n"
    s += "  version = #{@version}\n"
    s += "  files =\n"
    @files.each { |file| 
      s += "    #{file}\n"
    }
    return s
  end

  def addToRepository
    begin
      if @uploader =~ /root/
        output = "#{@file} was built by root, not processing"
        puts output
        email(@emailRecipientsFailure,
              "Upload of #{@name} failed",
              output)
        return
      end

      output = `command 2>&1`
      if $? != 0
        output = "Something went wrong when adding #{@file}, leaving it in incoming/\n\n" + output
        email(@emailRecipientsFailure + [@uploader, @maintainer],
              "Upload of #{@name} failed",
              output)
        return
      end

      @files.each { |file|
        File.rename(file, "#{PROCESSED}/#{File.basename(file)}")
      }

      email(@emailRecipientsSuccess, "Upload of #{@name} succeeded",
            @files.inject("") { |result, e|
              result += e.gsub(/#{INCOMING}\//, "") + "\n"
            })
    rescue Exception => e
      email(@emailRecipientsFailure,
            "Upload of #{@name} failed",
            e.message + "\n" + e.backtrace.join("\n"))
    end
  end
end

class PackageUpload < DebianUpload
  def initialize(file)
    super(file)
    @name = file.sub(/_.*/, "")
    @distribution = DEFAULT_DISTRIBUTION
    @command = "reprepro -Vb #{REP} includedeb #{@distribution} #{@file}"
    @emailRecipientsSuccess = DEFAULT_MAIL_RECIPIENTS
    @emailRecipientsFailure = DEFAULT_MAIL_RECIPIENTS
  end
end

class ChangeFileUpload < DebianUpload
  def initialize(file)
    super(file)
    filesSection = false
    File.open(file).each { |line|
      line.strip!
      case line
      when /^Binary: / then
        @name = line.sub(/^Binary: /, "")
      when /^Distribution: / then
        @distribution = line.sub(/^Distribution: /, "")
      when /^Maintainer: / then
        @maintainer = line.sub(/^Maintainer: /, "")
      when /^Changed-By: / then
        @uploader = line.sub(/^Changed-By: /, "")
      when /^Version: / then
        @version = line.sub(/^Version: /, "")
      when/^Files:/ then
        filesSection = true
        next
      when /^-----BEGIN PGP SIGNATURE-----/
        break # stop processing
      end
      
      if filesSection
        @files << line.sub(/.* /,"#{INCOMING}/")
      end
    }
    @command = "reprepro -Vb #{REP} include #{@distribution} #{@file}"
    @emailRecipientsSuccess = [ @uploader, @maintainer ].uniq
    @emailRecipientsFailure = @emailRecipientsSuccess + DEFAULT_MAIL_RECIPIENTS
  end
end

Dir["#{INCOMING}/*.changes"].each { |file|
  cfu = ChangeFileUpload.new(file)
  puts cfu
  cfu.addToRepository
}

Dir["#{INCOMING}/*.deb"].each { |file|
  pu = PackageUpload.new(file)
  puts pu
  pu.addToRepository
}

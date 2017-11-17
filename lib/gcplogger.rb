### for example
# logger = GCPLogger.logger "test"
# ...
# logger.labels[:act_id] = act_id
# logger.labels.delete :act_id


module GCPLogger
  puts "NOTE: GCPLogger was not meant to support multiple instantiating"
  # TODO: move this warning print to the method that created logger

  require "logger"

  ruby_logger = Logger.new STDOUT
  ruby_logger.formatter = lambda do |severity, datetime, progname, msg|
    "#{severity.to_s[0]} #{datetime.strftime "%y%m%d %H%M%S"} : #{msg}\n"
  end
  ruby_logger.level = Logger.const_get ENV["LOGLEVEL"] if ENV["LOGLEVEL"]

  require "google/cloud/logging"

  Google::Cloud::Logging::Logger.class_eval do
    %i{ debug info warn error fatal unknown }.each do |level|
      old = instance_method level
      define_method level do |message, entry_labels = {}, &block|
        ruby_logger.send level, message
        logger_labels = @labels if @labels
        @labels = (@labels || {}).merge entry_labels
        timeout = 0
        begin
          old.bind(self).(message, &block)
        rescue Google::Cloud::DeadlineExceededError, Google::Cloud::UnauthenticatedError => e
          ruby_logger.error "'#{e}' of #{message.inspect}"
          ruby_logger.info "sleep #{timeout += 1}"
          sleep timeout
          retry
        ensure
          @labels = logger_labels
        end
      end
    end
  end

  fail "env var missing -- LOGGING_KEYFILE" unless ENV["LOGGING_KEYFILE"]
  @@Logging = Google::Cloud::Logging.new project: JSON.load(File.read ENV["LOGGING_KEYFILE"])["project_id"]
  def self.logger name
    t = 0
    machine = if begin
      Google::Cloud.env.compute_engine?
    rescue Errno::EHOSTDOWN
      puts "failed to compose labels while instantiating a logger (Errno::EHOSTDOWN) -- retrying in #{t += 1} seconds"
      sleep t
      retry
    end
      [ "gce_instance", {
        "instance_id" => `curl http://metadata.google.internal/computeMetadata/v1/instance/id -H "Metadata-Flavor: Google"`,
        "zone" => `curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google"`.split("/").last,
      } ]
    else
      "global"
    end
    (
      Google::Cloud::Logging::Logger.new @@Logging, name, @@Logging.resource(*machine), {}   # if we omit labels would be Nil and so failing on #[]=
    ).tap{ |logger| logger.level = :WARN }
  end

end unless defined? GCPLogger # preventing multiple Google::Cloud::Logging::Logger.class_eval

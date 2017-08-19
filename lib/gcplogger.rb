### for example
# logger = GCPLogger.logger "test"
# ...
# logger.labels[:act_id] = act_id
# logger.labels.delete :act_id


module GCPLogger
  puts "WARNING: GCPLogger was not meant to support multiple instantiating"
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
        rescue Google::Cloud::DeadlineExceededError => e
          ruby_logger.error e
          ruby_logger.info "sleep #{timeout += 1}"
          sleep timeout
          retry
        ensure
          @labels = logger_labels
        end
      end
    end
  end

  @@Logging = Google::Cloud::Logging.new project: JSON.load(File.read ENV["GOOGLE_APPLICATION_CREDENTIALS"])["project_id"]
  def self.logger name
    (
      Google::Cloud::Logging::Logger.new @@Logging, name, @@Logging.resource( *if Google::Cloud.env.compute_engine?
        [ "gce_instance", {
          "instance_id" => `curl http://metadata.google.internal/computeMetadata/v1/instance/id -H "Metadata-Flavor: Google"`,
          "zone" => `curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google"`.split("/").last,
        } ]
      else
        "global"
      end ), {}   # if we omit labels would be Nil and so failing on #[]=
    ).tap{ |logger| logger.level = :WARN }
  end

end unless defined? GCPLogger # preventing multiple Google::Cloud::Logging::Logger.class_eval

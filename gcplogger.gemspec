Gem::Specification.new do |spec|
  spec.name = "gcplogger"
  spec.summary = "wrapper for Google Cloud Logging"
  spec.author = "Victor Maslov aka Nakilon"
  spec.email = "nakilon@gmail.com"
  spec.version = "0.1.1.0"
  spec.require_path = "lib"

  spec.add_runtime_dependency "public_suffix", "~>2.0"
  spec.add_runtime_dependency "google-cloud-logging", "~>1.4.0"
end

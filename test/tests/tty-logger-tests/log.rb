require 'tty-logger'

class CustomLogger < TTY::Logger
  # Customizing the initialization to set a different log format
  def initialize()
    super()
    @format = "[%{level}] %{message}"
  end

  # Overriding the log method to add custom formatting
  def log(level, message)
    formatted_message = @format % { level: level.upcase, message: message }
    super(level, formatted_message)
  end

  # Additional custom methods can be added here
  def log_error(message)
    error(message)  # Using the existing error method
  end

  def log_info(message)
    info(message)   # Using the existing info method
  end
end

# Using the custom logger
logger = CustomLogger.new()
logger.debug("This is a debug message.")
logger.info("This is an info message.")
logger.error("This is an error message.")

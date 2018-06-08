module ValidationTools
  SCRIPT_TAG_REGEX = /(\<|\&lt;)script.*(\>|\&gt;).*(\<|\&lt;)\/script(\>|\&gt;)/
  UNSAFE_URL_CHARACTERS = /[\;\/\?\:\@\=\&\'\"\<\>\#\%\{\}\|\\\^\~\[\]\`]/
  ALPHANUMERIC_AND_DASH = /[a-zA-Z0-9\-]/
  ALPHANUMERIC_AND_DASH_WITH_SPACE = /[a-zA-Z0-9\-\s]/
end
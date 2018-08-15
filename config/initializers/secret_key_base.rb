module Rails
  class Application < Engine
    def secret_key_base
      ENV['SECRET_KEY_BASE']
    end
  end
end
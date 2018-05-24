json.extract! admin_configuration, :id, :config_type, :value_type, :value, :created_at, :updated_at
json.url admin_configuration_url(admin_configuration, format: :json)

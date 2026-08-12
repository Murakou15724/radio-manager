class SettingsController < ApplicationController
  def index
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    @db_config = config.except(:password)
  end
end

class SettingsController < ApplicationController
  def index
    @db_config = ActiveRecord::Base.connection_db_config.configuration_hash
  end
end

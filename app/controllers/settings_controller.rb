class SettingsController < ApplicationController

  def index
    @settings = Setting.first
    @new_settings = Setting.new
  end

  def create
    settings = Setting.create(settings_params)
    if settings.save
      redirect_to root_url
    else
      redirect_to settings_path, notice: "There was an error"
    end
  end

  def update
    settings = Setting.find(params[:id])
    if settings.update(settings_params)
      redirect_to root_url, notice: "Success"
    else
      redirect_to settings_path, notice: "There was an error"
    end
  end

  private

  def settings_params
    params.require(:setting).permit(:channel_type, :name, :bot_id, :bot_name, :web_url)
  end

end

class StandupsController < ApplicationController

  def index
    @date = Date.parse(params[:date]) rescue Date.today
    @date_string = @date.strftime("%A")
    @standups = Standup.where(created_at: @date.beginning_of_week.at_midnight..@date.end_of_week.at_midnight)
  end

end

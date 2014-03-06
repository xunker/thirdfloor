class UserLocationsController < ApplicationController
  respond_to :html, :js, :json, :text

  skip_before_filter :verify_authenticity_token

  def index # GET collection
    user_locations = User.where(track_location: true).map do |user|
      [ user, user.user_locations.last ]
    end

    respond_with(user_locations: user_locations) do |format|
      format.html { render locals: { user_locations: user_locations } }
    end
  end

  def create # POST collection
    params.require(:station)
    params.require(:user_id)
    station = get_station(params[:station])
    user = User.find(params[:user_id])
    station.communicated!
    respond_with UserLocation.create!( station_id: station.id, user_id: user.id)
  end

private

  def get_station(station_params)
    # this is not secure at all, can you figure out why?
    Station.where( station_params ).first!
  end

end
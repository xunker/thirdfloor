class DataPointsController < ApplicationController

  respond_to :html, :json

  skip_before_filter :verify_authenticity_token, only: [ :create, :named_route_create ]

  # before_filter :login_required, only: [ :index, :show ]

  def index # GET/HEAD collection
    if request.head?
      respond_with_collection_head
    else
      respond_with_collection_index
    end
  end

  def create # POST collection
    data = (params[:data] || {}) # allow a station to send no data
    
    respond_with(DataPoint.create!(
      name: params[:name],
      station_id: current_station.id,
      data: data
    ))
  end

  # allows data points to be creates from anything that posts data
  def named_route_create
    respond_with(DataPoint.create!(
      name: params[:name],
      station_id: Station.local_station.id,
      data: params.merge(remote_ip: request.remote_ip)
    ))
  end

  def show
    point = DataPoint.find(params[:id])
    respond_with(point, serializer: DataPointSerializer, root: false) do |format|
      format.html { render locals: { point:point } }
    end
  end

protected

  def data_points
    DataPoint.where(id_condition).
      where(name_condition).
      where(days_condition).
      where(hstore_key_presence_condition)
  end

  def cached_data_points
    cache_expiration = if params[:cache_time].present?
      params[:cache_time].to_i.seconds
    else
      5.minutes
    end

    Rails.cache.fetch(data_points.limit(limit_condition).to_sql, expires_in: cache_expiration) do
      data_points.limit(limit_condition).to_a
    end
  end

  def respond_with_collection_index
    respond_with(
      cached_data_points,
      each_serializer: DataPointSerializer
    ) do |format|
      format.html do
        render locals: {
          data_points: data_points.paginate(:page => params[:page])
        }
      end
    end
  end

  def respond_with_collection_head
    params[:limit] = 1 # so caching works
    point = cached_data_points.first
    h = {
      "x-last-data-point-id" => point.id,
      "x-last-data-point-created-at" => point.created_at.to_i,
      "x-last-data-point-name" => point.name
    }

    h.each { |k,v| headers[k] = v.to_s }

    respond_to do |fmt|
      fmt.html { render text: h.inspect }
      fmt.json { render json: true }
    end
  end

private

  def limit_condition
    if (l = params[:limit].to_i) > 0
      l
    else
      nil
    end
  end

  def name_condition
    {}.tap do |h|
      if (name = params[:name]).present?
        h[:name] = name
      end
    end
  end

  def days_condition
    [].tap do |a|
      if (days = params[:days]).present?
        a << "created_at >= now() - interval '? days'"
        a << days.to_i
      end
    end
  end

  def id_condition
    {}.tap do |h|
      if params[:id]
        h[:id] = params[:id]
      end
    end
  end

  def hstore_key_presence_condition
    if params[:has_key].present?
      params[:has_key].split(',').map do |k|
        "defined(data, '#{k}')"
      end.join(' AND ')
    end
  end

  def data_point_params
    params.require(:name).permit(:data)
  end
end
